#ifndef AppVersion
  #error AppVersion must be supplied by the release workflow.
#endif

#define AppName "Lunora"
#define AppExeName "lunora.exe"

[Setup]
AppId={{D0A9E57C-7E7D-4D71-9E1B-8F4A2C91B6D3}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Lunora
AppPublisherURL=https://github.com/IbisClamoris/Lunora
AppSupportURL=https://github.com/IbisClamoris/Lunora/issues
AppUpdatesURL=https://github.com/IbisClamoris/Lunora/releases
DefaultDirName={localappdata}\Programs\Lunora
DefaultGroupName=Lunora
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build\installer
OutputBaseFilename=Lunora-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoDescription=Lunora Setup
VersionInfoProductName=Lunora
VersionInfoCompany=Lunora
VersionInfoCopyright=Copyright (C) Lunora
VersionInfoVersion={#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=115
WizardImageFile=..\assets\branding\wizard_image.bmp
WizardSmallImageFile=..\assets\branding\wizard_small.bmp
WizardImageBackColor=clNavy
WizardSmallImageBackColor=clNavy
UsePreviousAppDir=yes
UsePreviousGroup=yes
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
Uninstallable=yes
UninstallDisplayName=Lunora

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
russian.WelcomeTitle=Добро пожаловать в Lunora
russian.WelcomeText=Ваше личное пространство для книг, планов, заметок и идей.%n%nУстановим приложение и бережно сохраним ваши данные.
russian.FinishedTitle=Установка Lunora завершена
russian.FinishedText=Приложение готово к работе. Запустите Lunora и продолжайте с того места, где остановились.
russian.DesktopShortcut=Создать ярлык на рабочем столе
russian.ShortcutGroup=Дополнительные ярлыки:
russian.LaunchApp=Запустить Lunora
english.WelcomeTitle=Welcome to Lunora
english.WelcomeText=Your personal space for books, plans, notes and ideas.%n%nLet's install the app and keep your data safe.
english.FinishedTitle=Lunora setup is complete
english.FinishedText=Lunora is ready. Launch the app and pick up where you left off.
english.DesktopShortcut=Create a desktop shortcut
english.ShortcutGroup=Additional shortcuts:
english.LaunchApp=Launch Lunora

[Messages]
WelcomeLabel1={cm:WelcomeTitle}
WelcomeLabel2={cm:WelcomeText}
FinishedHeadingLabel={cm:FinishedTitle}
FinishedLabel={cm:FinishedText}

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; GroupDescription: "{cm:ShortcutGroup}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Lunora"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Lunora"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchApp}"; Flags: postinstall nowait skipifsilent
