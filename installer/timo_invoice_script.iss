; =========================================================
; Timo Invoice - Professional Installer (Flutter Windows)
; =========================================================

#define MyAppName "Timo Invoice"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "TK Smart Solutions"
#define MyAppExeName "timo_enginerring.exe"

[Setup]
AppId={{1392AB37-03A8-4F73-8161-6D0CD1F88E27}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

; ===== MODERN INSTALL LOCATION (STANDARD) =====
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

; ===== UI / MODERN LOOK =====
WizardStyle=modern
DisableProgramGroupPage=no
AllowNoIcons=yes

; ===== OUTPUT =====
OutputDir=D:\source_codes\timo_enginerring\installer
OutputBaseFilename=timo_setup

; ===== ICON =====
SetupIconFile=D:\source_codes\timo_enginerring\assets\timo_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; ===== SYSTEM SUPPORT =====
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

SolidCompression=yes
Compression=lzma2

; ===== OPTIONAL CLEAN UI =====
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create Desktop Shortcut"; GroupDescription: "Additional Icons"; Flags: unchecked

[Files]
; Main Flutter build (clean & professional approach)
Source: "D:\source_codes\timo_enginerring\build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; \
Flags: ignoreversion recursesubdirs createallsubdirs

; Ensure icon is inside install folder
Source: "D:\source_codes\timo_enginerring\assets\timo_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu
Name: "{autoprograms}\{#MyAppName}"; \
Filename: "{app}\{#MyAppExeName}"; \
IconFilename: "{app}\timo_icon.ico"

; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; \
Filename: "{app}\{#MyAppExeName}"; \
Tasks: desktopicon; \
IconFilename: "{app}\timo_icon.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; \
Description: "Launch {#MyAppName}"; \
Flags: nowait postinstall skipifsilent