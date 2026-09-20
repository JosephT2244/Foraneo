param([string]$InnoCompiler = '')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputDirectory = Join-Path $projectRoot 'artifacts'
$releaseDirectory = Join-Path $projectRoot 'foraneo_flutter\build\windows\x64\runner\Release'
$apkSource = Join-Path $projectRoot 'foraneo_flutter\build\app\outputs\flutter-apk\app-release.apk'
if (!(Test-Path -LiteralPath $apkSource) -or !(Test-Path -LiteralPath (Join-Path $releaseDirectory 'foraneo.exe'))) {
    throw 'Primero ejecuta flutter build apk --release y flutter build windows --release.'
}
if (!$InnoCompiler) {
    $candidates = @((Join-Path $projectRoot '.tools\inno\ISCC.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'))
    $InnoCompiler = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (!$InnoCompiler -or !(Test-Path -LiteralPath $InnoCompiler -PathType Leaf)) {
    throw 'No se encontró Inno Setup. No se modificó ningún instalable anterior; instala Inno Setup o proporciona -InnoCompiler.'
}
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$outputDirectory = [IO.Path]::GetFullPath($outputDirectory)
if ((Get-Item -LiteralPath $outputDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'La carpeta artifacts no puede ser un enlace o junction para empaquetar de forma segura.'
}
function Assert-ArtifactChild([string]$TargetPath) {
    $resolvedTarget = [IO.Path]::GetFullPath($TargetPath)
    $allowedPrefix = $outputDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (!$resolvedTarget.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "La ruta de empaquetado sale de artifacts: $resolvedTarget"
    }
    if ((Test-Path -LiteralPath $resolvedTarget) -and ((Get-Item -LiteralPath $resolvedTarget).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "No se moverá un enlace o junction: $resolvedTarget"
    }
}

# App-local Microsoft runtime distribution: the portable app needs no runtime installer.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'No se encontró vswhere para localizar las DLL redistribuibles de Visual Studio.' }
$vsInstall = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$runtimeRoot = Join-Path $vsInstall 'VC\Redist\MSVC'
$runtimeVersion = Get-ChildItem -LiteralPath $runtimeRoot -Directory | Where-Object Name -Match '^\d+\.' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$runtimeVersion) { throw 'No se encontró una versión redistribuible de Visual C++.' }
$runtimeDirectory = Join-Path $runtimeVersion.FullName 'x64\Microsoft.VC143.CRT'
if (!(Test-Path -LiteralPath $runtimeDirectory)) { throw 'Faltan DLL de Visual C++ x64 para incluir en el paquete portable.' }
Get-ChildItem -LiteralPath $runtimeDirectory -Filter '*.dll' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $releaseDirectory -Force
}

$stageDirectory = Join-Path $outputDirectory ('.staging-' + [Guid]::NewGuid().ToString('N'))
Assert-ArtifactChild $stageDirectory
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$portableDirectory = Join-Path $stageDirectory 'Foraneo-Windows'
New-Item -ItemType Directory -Path $portableDirectory | Out-Null
Get-ChildItem -LiteralPath $releaseDirectory | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $portableDirectory -Recurse -Force
}
Copy-Item -LiteralPath $apkSource -Destination (Join-Path $stageDirectory 'foraneo.apk')
Compress-Archive -Path (Join-Path $portableDirectory '*') -DestinationPath (Join-Path $stageDirectory 'foraneo-windows-portable.zip')

& $InnoCompiler "/O$stageDirectory" (Join-Path $PSScriptRoot 'foraneo-installer.iss')
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath (Join-Path $stageDirectory 'foraneo.exe') -PathType Leaf)) {
    throw "Falló la creación del instalador Windows. Los instalables anteriores siguen intactos; la preparación se conserva en $stageDirectory"
}
$artifactNames = @('foraneo.apk', 'foraneo.exe', 'foraneo-windows-portable.zip')
$artifactFiles = $artifactNames | ForEach-Object { Get-Item -LiteralPath (Join-Path $stageDirectory $_) }
$checksums = $artifactFiles | ForEach-Object { $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256; "$($hash.Hash.ToLowerInvariant())  $($_.Name)" }
[IO.File]::WriteAllLines((Join-Path $stageDirectory 'SHA256SUMS.txt'), $checksums, [Text.UTF8Encoding]::new($false))

# Promote only a complete staged bundle. Previous outputs remain recoverable;
# never merge a new portable tree into an old tree or recursively delete one.
$allNames = @('Foraneo-Windows') + $artifactNames + @('SHA256SUMS.txt')
$backupDirectory = Join-Path $outputDirectory ('.previous-' + [Guid]::NewGuid().ToString('N'))
Assert-ArtifactChild $backupDirectory
foreach ($name in $allNames) {
    Assert-ArtifactChild (Join-Path $outputDirectory $name)
    Assert-ArtifactChild (Join-Path $stageDirectory $name)
}
New-Item -ItemType Directory -Path $backupDirectory | Out-Null
try {
    foreach ($name in $allNames) {
        $previousPath = Join-Path $outputDirectory $name
        if (Test-Path -LiteralPath $previousPath) {
            Move-Item -LiteralPath $previousPath -Destination (Join-Path $backupDirectory $name)
        }
    }
    foreach ($name in $allNames) {
        Move-Item -LiteralPath (Join-Path $stageDirectory $name) -Destination (Join-Path $outputDirectory $name)
    }
} catch {
    throw "No se pudo completar la promoción del paquete. No se borró ningún archivo: revisa $stageDirectory y $backupDirectory. $($_.Exception.Message)"
}
Write-Output "Los paquetes anteriores, si existían, se conservaron en $backupDirectory"
$artifactNames | ForEach-Object { Get-Item -LiteralPath (Join-Path $outputDirectory $_) } | Select-Object Name, Length
