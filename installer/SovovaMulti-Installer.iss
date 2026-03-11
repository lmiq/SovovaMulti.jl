; SovovaMulti Windows Installer
; Requires Inno Setup 6+: https://jrsoftware.org/isinfo.php
;
; Build:  Open this file in the Inno Setup Compiler and click Build > Compile.
; Output: installer\Output\SovovaMulti-Installer.exe

#define AppName      "SovovaMulti"
; AppVersion can be overridden from the command line: ISCC /DAppVersion=1.2.3 ...
#ifndef AppVersion
  #define AppVersion "1.0.16"
#endif
#define AppPublisher "lmiq"
#define AppURL       "https://github.com/lmiq/SovovaMulti.jl"
#define JuliaMinMajor 1
#define JuliaMinMinor 12

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
; No program files are installed — Julia and Pkg.Apps handle everything.
; We still need a DefaultDirName; use a harmless temp location.
DefaultDirName={tmp}\{#AppName}-setup
DisableDirPage=yes
DisableProgramGroupPage=yes
; Run as current user so Julia installs to %LOCALAPPDATA% (its default)
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename={#AppName}-Installer
WizardStyle=modern
; Nothing to uninstall
Uninstallable=no
CreateUninstallRegKey=no
SolidCompression=yes
Compression=lzma2

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.CheckingJulia=Checking for Julia {#JuliaMinMajor}.{#JuliaMinMinor}+...
english.InstallingJulia=Installing Julia via winget (this may take a few minutes)...
english.InstallingPackage=Installing {#AppName} — downloading packages, please wait...
english.WingetMissing=winget (Windows Package Manager) was not found.%n%nPlease install Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ manually from https://julialang.org/downloads/ and then re-run this installer.
english.NeedJuliaInfo=Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ was not found and will be installed automatically via winget.%n%nClick OK to continue.
english.JuliaNotFoundAfterInstall=Could not locate julia.exe after installation.%n%nPlease restart the installer or install Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ manually from https://julialang.org/downloads/ and re-run.
english.JuliaTooOld=An older version of Julia was found, but {#AppName} requires Julia {#JuliaMinMajor}.{#JuliaMinMinor}+.%n%nPlease upgrade Julia from https://julialang.org/downloads/ and then re-run this installer.

[Code]
var
  GJuliaExe:   String;  // resolved path to julia.exe
  GNeedJulia:  Boolean; // True when Julia must be installed
  GScriptPath: String;  // temp .jl file passed to julia

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Run a command via cmd.exe, capture first line of stdout into Output.
// Returns True when something was captured.
function RunAndCapture(ExePath, Params: String; var Output: String): Boolean;
var
  TmpFile, CmdArgs: String;
  Lines: TArrayOfString;
  RC: Integer;
begin
  Result := False;
  Output := '';
  TmpFile  := ExpandConstant('{tmp}\sovova_capture.txt');
  CmdArgs  := '/C ""' + ExePath + '" ' + Params + ' > "' + TmpFile + '" 2>&1"';
  Exec(ExpandConstant('{cmd}'), CmdArgs, '', SW_HIDE, ewWaitUntilTerminated, RC);
  if LoadStringsFromFile(TmpFile, Lines) and (GetArrayLength(Lines) > 0) then begin
    Output := Trim(Lines[0]);
    Result := Output <> '';
  end;
end;

// Parse "julia version X.Y.Z" and return True if >= JuliaMinMajor.JuliaMinMinor.
function JuliaVersionOK(VerStr: String): Boolean;
var
  Rest: String;
  Major, Minor, DotPos: Integer;
begin
  Result := False;
  Rest := Trim(VerStr);
  if Pos('julia version ', LowerCase(Rest)) = 1 then
    Delete(Rest, 1, Length('julia version '));
  DotPos := Pos('.', Rest);
  if DotPos = 0 then Exit;
  Major := StrToIntDef(Copy(Rest, 1, DotPos - 1), 0);
  Delete(Rest, 1, DotPos);
  DotPos := Pos('.', Rest);
  if DotPos > 0 then
    Minor := StrToIntDef(Copy(Rest, 1, DotPos - 1), 0)
  else
    Minor := StrToIntDef(Trim(Rest), 0);
  Result := (Major > {#JuliaMinMajor}) or
            ((Major = {#JuliaMinMajor}) and (Minor >= {#JuliaMinMinor}));
end;

// Scan %LOCALAPPDATA%\Programs\Julia* and return the last (highest) julia.exe found.
function FindJuliaInLocalPrograms: String;
var
  FindRec: TFindRec;
  BaseDir, Candidate: String;
begin
  Result := '';
  BaseDir := ExpandConstant('{localappdata}\Programs');
  if FindFirst(BaseDir + '\Julia*', FindRec) then begin
    try
      repeat
        if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then begin
          Candidate := BaseDir + '\' + FindRec.Name + '\bin\julia.exe';
          if FileExists(Candidate) then
            Result := Candidate; // last match wins when entries are sorted by name/version
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

// Attempt to locate a julia.exe that satisfies the minimum version.
// Sets GJuliaExe and returns True on success.
function DetectJulia: Boolean;
var
  Output, Candidate: String;
begin
  Result := False;
  GJuliaExe := '';

  // 1. Try julia from PATH
  if RunAndCapture('julia', '--version', Output) then
    if JuliaVersionOK(Output) then begin
      GJuliaExe := 'julia';
      Result := True;
      Exit;
    end;

  // 2. Try %LOCALAPPDATA%\Programs\Julia*
  Candidate := FindJuliaInLocalPrograms;
  if Candidate <> '' then begin
    if RunAndCapture(Candidate, '--version', Output) then
      if JuliaVersionOK(Output) then begin
        GJuliaExe := Candidate;
        Result := True;
        Exit;
      end;
  end;
end;

// Return True if any julia.exe is reachable, regardless of version.
function DetectAnyJulia: Boolean;
var
  Output: String;
begin
  Result := False;
  if RunAndCapture('julia', '--version', Output) then begin
    Result := True;
    Exit;
  end;
  Result := FindJuliaInLocalPrograms <> '';
end;

// Return the full path to winget.exe, trying the known AppX location before PATH.
function WingetExePath: String;
var
  WingetLocal: String;
begin
  WingetLocal := ExpandConstant('{localappdata}\Microsoft\WindowsApps\winget.exe');
  if FileExists(WingetLocal) then
    Result := WingetLocal
  else
    Result := 'winget';
end;

function WingetAvailable: Boolean;
var
  Output: String;
begin
  Result := RunAndCapture(WingetExePath, '--version', Output);
end;

// Write the Julia install script to a temp file (avoids shell quoting hell).
procedure CreateInstallScript;
var
  Lines: TArrayOfString;
begin
  GScriptPath := ExpandConstant('{tmp}\sovova_install.jl');
  SetArrayLength(Lines, 2);
  Lines[0] := 'import Pkg';
  Lines[1] := 'Pkg.Apps.add("SovovaMulti")';
  SaveStringsToFile(GScriptPath, Lines, False);
end;

// ---------------------------------------------------------------------------
// Inno Setup event functions
// ---------------------------------------------------------------------------

function InitializeSetup: Boolean;
begin
  Result := True;
  GNeedJulia := not DetectJulia;
  CreateInstallScript;

  if GNeedJulia then begin
    if DetectAnyJulia then begin
      // Julia is present but too old — ask the user to upgrade manually.
      MsgBox(CustomMessage('JuliaTooOld'), mbError, MB_OK);
      Result := False;
      Exit;
    end;
    if not WingetAvailable then begin
      MsgBox(CustomMessage('WingetMissing'), mbError, MB_OK);
      Result := False;
      Exit;
    end;
    MsgBox(CustomMessage('NeedJuliaInfo'), mbInformation, MB_OK);
  end;
end;

// Called by BeforeInstall on the Pkg.Apps.add step, after winget has finished.
procedure RefreshJuliaExe;
begin
  if GJuliaExe <> '' then Exit; // already found
  if not DetectJulia then begin
    // Last-resort scan — winget may have installed without updating PATH yet
    GJuliaExe := FindJuliaInLocalPrograms;
    if GJuliaExe = '' then begin
      MsgBox(CustomMessage('JuliaNotFoundAfterInstall'), mbError, MB_OK);
      // Installer will still attempt 'julia' from PATH as a fallback
      GJuliaExe := 'julia';
    end;
  end;
end;

function ShouldInstallJulia: Boolean;
begin
  Result := GNeedJulia;
end;

function GetJuliaExe(Param: String): String;
begin
  Result := GJuliaExe;
  if Result = '' then
    Result := 'julia';
end;

function GetScriptPath(Param: String): String;
begin
  Result := GScriptPath;
end;

function GetWingetExePath(Param: String): String;
begin
  Result := WingetExePath;
end;

// ---------------------------------------------------------------------------
// Run steps (executed in order during the install phase)
// ---------------------------------------------------------------------------

[Run]
; Step 1: Install Julia via winget (skipped when Julia >= 1.12 already present)
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -NonInteractive -Command ""& '{code:GetWingetExePath}' install --id Julialang.Julia --silent --accept-package-agreements --accept-source-agreements"""; StatusMsg: {cm:InstallingJulia}; Check: ShouldInstallJulia; Flags: runhidden waituntilterminated

; Step 2: Install the SovovaMulti package (runs a temp .jl script to avoid quoting issues)
Filename: "{code:GetJuliaExe}"; Parameters: """{code:GetScriptPath}"""; StatusMsg: {cm:InstallingPackage}; BeforeInstall: RefreshJuliaExe; Flags: runhidden waituntilterminated
