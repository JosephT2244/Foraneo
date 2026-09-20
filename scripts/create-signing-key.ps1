param([string]$JavaDirectory = 'C:\Program Files\Android\Android Studio\jbr')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$androidDirectory = Join-Path $projectRoot 'foraneo_flutter\android'
$keyPath = Join-Path $androidDirectory 'foraneo-release.jks'
$propertiesPath = Join-Path $androidDirectory 'key.properties'
if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Ya existe una llave o configuración de firma. Se conserva sin modificar; no regeneres la firma de una app instalada.'
}
$randomBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$env:FORANEO_SIGNING_PASS = [Convert]::ToBase64String($randomBytes)
try {
    & (Join-Path $JavaDirectory 'bin\keytool.exe') -genkeypair -v -keystore $keyPath -storetype JKS -alias foraneo -keyalg RSA -keysize 3072 -validity 10000 -storepass:env FORANEO_SIGNING_PASS -keypass:env FORANEO_SIGNING_PASS -dname 'CN=Joseph Ubaldo Trejo Hernandez, OU=Foraneo, O=Foraneo, C=MX'
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar la llave de firma.' }
    $properties = "storePassword=$env:FORANEO_SIGNING_PASS`nkeyPassword=$env:FORANEO_SIGNING_PASS`nkeyAlias=foraneo`nstoreFile=foraneo-release.jks`n"
    [IO.File]::WriteAllText($propertiesPath, $properties, [Text.UTF8Encoding]::new($false))
    Write-Output 'Llave de publicación creada y excluida de Git. Conserva una copia privada de android/foraneo-release.jks y android/key.properties.'
} finally {
    Remove-Item Env:\FORANEO_SIGNING_PASS -ErrorAction SilentlyContinue
}
