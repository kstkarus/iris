#define AppVersion GetEnv("IRIS_VERSION")
#if AppVersion == ""
  #error IRIS_VERSION must be set before compiling the installer
#endif

#define ReleaseDir AddBackslash(SourcePath) + "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B603F154-436B-49BB-8B8F-5D42F5D6A4B1}
AppName=iris
AppVersion={#AppVersion}
AppVerName=iris {#AppVersion}
AppPublisher=com.kstkarus
DefaultDirName={autopf}\Iris
DefaultGroupName=Iris
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=no
RestartApplications=no
SetupLogging=yes
OutputDir={#AddBackslash(SourcePath)}..\..\dist
OutputBaseFilename=iris-{#AppVersion}-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#AddBackslash(SourcePath)}..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\iris.exe
VersionInfoCompany=com.kstkarus
VersionInfoProductName=iris
VersionInfoProductVersion={#AppVersion}
VersionInfoVersion={#AppVersion}

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Iris"; Filename: "{app}\iris.exe"

[Registry]
Root: HKCU; Subkey: "Software\com.kstkarus\iris\Installer"; ValueType: string; ValueName: "InstallLocation"; ValueData: "{app}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\iris.exe"; Description: "Launch Iris"; Flags: postinstall nowait skipifsilent; Check: OfferInitialLaunch

[Code]
const
  RunningMutexName = 'Local\com.kstkarus.iris.running';
  InstallingMutexName = 'Local\com.kstkarus.iris.installing';
  SynchronizeAccess = $00100000;
  WaitObject0 = $00000000;
  WaitAbandoned0 = $00000080;
  WaitTimeout = $00000102;
  WaitFailed = $FFFFFFFF;
  ErrorFileNotFound = 2;
  ErrorInvalidParameter = 87;
  ProcessWaitMilliseconds = 60000;
  PollMilliseconds = 250;

var
  InAppUpdate: Boolean;
  UpdateProcessId: DWORD;
  UpdateProcessHandle: THandle;
  InstallingMutex: THandle;
  OwnsInstallingMutex: Boolean;

function CreateMutex(lpMutexAttributes: LongInt; bInitialOwner: BOOL; lpName: String): THandle;
  external 'CreateMutexW@kernel32.dll stdcall';
function OpenMutex(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: String): THandle;
  external 'OpenMutexW@kernel32.dll stdcall';
function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function ReleaseMutex(hMutex: THandle): BOOL;
  external 'ReleaseMutex@kernel32.dll stdcall';
function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';
function GetLastError: DWORD;
  external 'GetLastError@kernel32.dll stdcall';
procedure Sleep(dwMilliseconds: DWORD);
  external 'Sleep@kernel32.dll stdcall';

function SamePath(const LeftPath, RightPath: String): Boolean;
begin
  Result := CompareText(
    RemoveBackslashUnlessRoot(ExpandFileName(LeftPath)),
    RemoveBackslashUnlessRoot(ExpandFileName(RightPath))) = 0;
end;

function CheckRunningMarker(var IsRunning: Boolean; var ErrorMessage: String): Boolean;
var
  Handle: THandle;
  ErrorCode: DWORD;
begin
  Handle := OpenMutex(SynchronizeAccess, False, RunningMutexName);
  if Handle <> 0 then begin
    CloseHandle(Handle);
    IsRunning := True;
    ErrorMessage := '';
    Result := True;
  end else begin
    ErrorCode := GetLastError;
    IsRunning := False;
    if ErrorCode = ErrorFileNotFound then begin
      ErrorMessage := '';
      Result := True;
    end else begin
      ErrorMessage := 'Windows could not check whether Iris is running. Close Iris and try again.';
      Result := False;
    end;
  end;
end;

function AcquireInstallingMutex(var ErrorMessage: String): Boolean;
var
  WaitResult: DWORD;
begin
  if OwnsInstallingMutex then begin
    ErrorMessage := '';
    Result := True;
    Exit;
  end;

  InstallingMutex := CreateMutex(0, False, InstallingMutexName);
  if InstallingMutex = 0 then begin
    ErrorMessage := 'Windows could not prepare the Iris update. Try again.';
    Result := False;
    Exit;
  end;

  WaitResult := WaitForSingleObject(InstallingMutex, 5000);
  if (WaitResult = WaitObject0) or (WaitResult = WaitAbandoned0) then begin
    OwnsInstallingMutex := True;
    ErrorMessage := '';
    Result := True;
  end else begin
    CloseHandle(InstallingMutex);
    InstallingMutex := 0;
    ErrorMessage := 'Another Iris install or launch is in progress. Try again in a moment.';
    Result := False;
  end;
end;

function IsLegacyIrisRunning(var QueryFailed: Boolean): Boolean;
var
  Locator: Variant;
  Services: Variant;
  Processes: Variant;
begin
  QueryFailed := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('.', 'root\CIMV2');
    Processes := Services.ExecQuery(
      'SELECT ProcessId FROM Win32_Process WHERE Name = ''iris.exe''');
    Result := Processes.Count > 0;
  except
    QueryFailed := True;
    Result := False;
    Log('Could not check for a legacy Iris process: ' + GetExceptionMessage);
  end;
end;

function WaitForUpdateProcesses(var ErrorMessage: String): Boolean;
var
  IsRunning: Boolean;
  MarkerError: String;
  WaitResult: DWORD;
  Elapsed: DWORD;
begin
  if UpdateProcessHandle = 0 then begin
    UpdateProcessHandle := OpenProcess(SynchronizeAccess, False, UpdateProcessId);
    if (UpdateProcessHandle = 0) and (GetLastError <> ErrorInvalidParameter) then begin
      ErrorMessage := 'The Iris process could not be checked. Close Iris and retry the update.';
      Result := False;
      Exit;
    end;
  end;

  Elapsed := 0;
  while Elapsed < ProcessWaitMilliseconds do begin
    if not CheckRunningMarker(IsRunning, MarkerError) then begin
      ErrorMessage := MarkerError;
      Result := False;
      Exit;
    end;
    if not IsRunning then begin
      ErrorMessage := '';
      Result := True;
      Exit;
    end;

    if UpdateProcessHandle <> 0 then begin
      WaitResult := WaitForSingleObject(UpdateProcessHandle, PollMilliseconds);
      if WaitResult = WaitObject0 then begin
        CloseHandle(UpdateProcessHandle);
        UpdateProcessHandle := 0;
      end else if WaitResult <> WaitTimeout then begin
        ErrorMessage := 'The Iris process could not be checked. Close Iris and retry the update.';
        Result := False;
        Exit;
      end;
    end else begin
      Sleep(PollMilliseconds);
    end;
    Elapsed := Elapsed + PollMilliseconds;
  end;

  ErrorMessage := 'Iris is still running. Close every Iris window and try the update again.';
  Result := False;
end;

procedure ReleaseInstallingMutex;
begin
  if OwnsInstallingMutex then begin
    ReleaseMutex(InstallingMutex);
    OwnsInstallingMutex := False;
  end;
  if InstallingMutex <> 0 then begin
    CloseHandle(InstallingMutex);
    InstallingMutex := 0;
  end;
end;

function InitializeSetup: Boolean;
var
  UpdatePidText: String;
  UpdateDirectory: String;
  InstalledDirectory: String;
  ErrorMessage: String;
begin
  UpdateProcessHandle := 0;
  InstallingMutex := 0;
  OwnsInstallingMutex := False;
  UpdateProcessId := 0;
  UpdatePidText := ExpandConstant('{param:UPDATEPID|}');
  InAppUpdate := UpdatePidText <> '';

  if InAppUpdate and not WizardSilent then begin
    MsgBox('The in-app update command is invalid. Run this installer from Iris.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if WizardSilent then begin
    if (not InAppUpdate) or (StrToInt64Def(UpdatePidText, 0) <= 0) or
       (StrToInt64Def(UpdatePidText, 0) > $FFFFFFFF) then begin
      MsgBox('Silent installation is only available for an installed Iris update. Run the setup wizard for a first installation.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    UpdateProcessId := DWORD(StrToInt64Def(UpdatePidText, 0));
    if not RegQueryStringValue(HKCU, 'Software\com.kstkarus\iris\Installer',
       'InstallLocation', InstalledDirectory) then begin
      MsgBox('Install Iris once with the setup wizard before using in-app updates.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    UpdateDirectory := ExpandConstant('{param:DIR|}');
    if (UpdateDirectory = '') or not SamePath(UpdateDirectory, InstalledDirectory) then begin
      MsgBox('The update location does not match this Iris installation. Run Iris and try again.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    if not AcquireInstallingMutex(ErrorMessage) then begin
      MsgBox(ErrorMessage, mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

function OfferInitialLaunch: Boolean;
begin
  Result := not InAppUpdate;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ErrorMessage: String;
  InstalledDirectory: String;
  IsRunning: Boolean;
  QueryFailed: Boolean;
begin
  if not AcquireInstallingMutex(ErrorMessage) then begin
    Result := ErrorMessage;
    Exit;
  end;

  if InAppUpdate then begin
    if not WaitForUpdateProcesses(ErrorMessage) then begin
      Result := ErrorMessage;
      Exit;
    end;
    Result := '';
    Exit;
  end;

  if RegQueryStringValue(HKCU, 'Software\com.kstkarus\iris\Installer',
     'InstallLocation', InstalledDirectory) and
     not SamePath(WizardDirValue, InstalledDirectory) then begin
    Result := 'Choose the existing Iris install folder to update this installation.';
    Exit;
  end;

  if not CheckRunningMarker(IsRunning, ErrorMessage) then begin
    Result := ErrorMessage;
    Exit;
  end;
  if IsRunning then begin
    Result := 'Close Iris and try again.';
    Exit;
  end;

  if IsLegacyIrisRunning(QueryFailed) then begin
    Result := 'A portable Iris copy is running. Close Iris and try again.';
    Exit;
  end;
  if QueryFailed then begin
    Result := 'Windows could not check whether a portable Iris copy is running. Close Iris and try again.';
    Exit;
  end;

  Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    ReleaseInstallingMutex;
    if InAppUpdate then begin
      if not ExecAsOriginalUser(ExpandConstant('{app}\iris.exe'), '',
         ExpandConstant('{app}'), SW_SHOWNORMAL, ewNoWait, ResultCode) then
        MsgBox('Iris was updated but could not be started. Open Iris from the Start menu.', mbError, MB_OK);
    end;
  end;
end;

procedure DeinitializeSetup;
begin
  ReleaseInstallingMutex;
  if UpdateProcessHandle <> 0 then
    CloseHandle(UpdateProcessHandle);
end;
