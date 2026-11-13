#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Lunora"
#define AppExeName "lunora.exe"

[Setup]
AppId={{D0A9E57C-7E7D-4D71-9E1B-8F4A2C91B6D3}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Lunora
DefaultDirName={localappdata}\Programs\Lunora
DefaultGroupName=Lunora
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build\installer
OutputBaseFilename=Lunora-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
Uninstallable=yes

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные ярлыки:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Lunora"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Lunora"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Запустить Lunora"; Flags: postinstall nowait skipifsilent
