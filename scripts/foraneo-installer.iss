#define AppVersion "2.0.0"
#define ReleaseDir "..\foraneo_flutter\build\windows\x64\runner\Release"
[Setup]
AppId={{D2A8A2B4-E0F1-49FD-8176-3A3A87C590CE}
AppName=Foráneo
AppVersion={#AppVersion}
AppPublisher=Joseph Ubaldo Trejo Hernandez
AppPublisherURL=https://josepht2244.github.io/Foraneo/
DefaultDirName={localappdata}\Programs\Foraneo
DefaultGroupName=Foráneo
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\artifacts
OutputBaseFilename=foraneo
SetupIconFile=..\foraneo_flutter\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\foraneo.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked
[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Foráneo"; Filename: "{app}\foraneo.exe"
Name: "{autodesktop}\Foráneo"; Filename: "{app}\foraneo.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\foraneo.exe"; Description: "Abrir Foráneo"; Flags: nowait postinstall skipifsilent
