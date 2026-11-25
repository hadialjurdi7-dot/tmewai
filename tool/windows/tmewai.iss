; Inno Setup 6 script for Tmewai (Windows x64).
;
; Why Inno Setup and not MSIX: MSIX requires the *package* to be signed with a
; certificate the machine already trusts. A self-signed MSIX is worse than an
; unsigned installer, because the user has to install a root certificate by
; hand before Windows will even open the file. An Authenticode-signed Inno
; installer is a single .exe that runs, installs per-user without admin rights,
; and inherits the reputation of the signing certificate. Switch to MSIX only
; once we own an EV certificate *and* want the Store.
;
; Build (from tool/windows):
;   ISCC.exe tmewai.iss /DMyAppVersion=0.3.4
; Signing is passed on the ISCC command line so no secret ever lives here:
;   ISCC.exe tmewai.iss /DMyAppVersion=0.3.4 "/Ssigntool=signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $f"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Tmewai"
#define MyAppPublisher "Tmewai"
#define MyAppExeName "tmewai.exe"
#define ReleaseDir SourcePath + "\..\..\build\windows\x64\runner\Release"

[Setup]
; A stable AppId keeps upgrades in place instead of installing side by side.
AppId={{8B18DDB2-FBEB-449A-8745-1693F9CB6E71}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
; Per-user install: no UAC prompt, no admin rights, no service.
DefaultDirName={localappdata}\Programs\tmewai
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#SourcePath}\..\..\dist
OutputBaseFilename=tmewai-{#MyAppVersion}-setup
SetupIconFile={#SourcePath}\..\..\assets\branding\tmewai.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Set SignTool=signtool only when a certificate was passed with /S; otherwise
; ISCC fails with "Sign Tool is not configured".
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole portable folder: exe, DLLs, data\flutter_assets. ignoreversion keeps
; the stamped VERSIONINFO that release.ps1 just wrote.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
