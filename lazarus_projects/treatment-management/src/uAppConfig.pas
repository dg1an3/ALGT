unit uAppConfig;

{$mode objfpc}{$H+}

// Application-wide configuration loaded from treatment_mgmt.ini at startup.
// Period-correct: TIniFile + global record, exposed as a unit-level singleton.

interface

uses
  Classes, SysUtils, IniFiles;

type
  TDbConfig = record
    Host:     string;
    Port:     Integer;
    Database: string;
    User:     string;
    Password: string;
    Params:   string;
  end;

  TAppSettings = record
    Db:       TDbConfig;
    Operator: string;
    PageSize: Integer;
    IniPath:  string;
  end;

var
  AppCfg: TAppSettings;

procedure LoadAppConfig;
function  ResolveIniPath: string;

implementation

function ResolveIniPath: string;
var
  ExeDir, AppDataDir, HomeDir: string;
begin
  ExeDir := ExtractFilePath(ParamStr(0));
  Result := ExeDir + 'treatment_mgmt.ini';
  if FileExists(Result) then Exit;

  {$IFDEF MSWINDOWS}
  AppDataDir := GetEnvironmentVariable('APPDATA');
  if AppDataDir <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(AppDataDir) +
              'TreatmentMgmt' + PathDelim + 'treatment_mgmt.ini';
    if FileExists(Result) then Exit;
  end;
  {$ENDIF}

  {$IFDEF UNIX}
  HomeDir := GetEnvironmentVariable('HOME');
  if HomeDir <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(HomeDir) + '.treatment_mgmt.ini';
    if FileExists(Result) then Exit;
  end;
  {$ENDIF}

  // Fall back to EXE-dir path even if missing — caller will see error.
  Result := ExeDir + 'treatment_mgmt.ini';
end;

procedure LoadAppConfig;
var
  Ini: TIniFile;
begin
  AppCfg.IniPath := ResolveIniPath;
  if not FileExists(AppCfg.IniPath) then
    raise Exception.CreateFmt(
      'Configuration file not found: %s' + LineEnding +
      'Copy config/treatment_mgmt.ini.sample to this location and edit it.',
      [AppCfg.IniPath]);

  Ini := TIniFile.Create(AppCfg.IniPath);
  try
    AppCfg.Db.Host     := Ini.ReadString ('Database', 'Host',     'localhost');
    AppCfg.Db.Port     := Ini.ReadInteger('Database', 'Port',     5432);
    AppCfg.Db.Database := Ini.ReadString ('Database', 'Database', 'treatment_mgmt');
    AppCfg.Db.User     := Ini.ReadString ('Database', 'User',     'tm_app');
    AppCfg.Db.Password := Ini.ReadString ('Database', 'Password', '');
    AppCfg.Db.Params   := Ini.ReadString ('Database', 'Params',   '');

    AppCfg.Operator    := Ini.ReadString ('Application', 'Operator', '');
    AppCfg.PageSize    := Ini.ReadInteger('Application', 'PageSize', 200);
  finally
    Ini.Free;
  end;

  if AppCfg.Operator = '' then
    AppCfg.Operator := GetEnvironmentVariable({$IFDEF MSWINDOWS}'USERNAME'{$ELSE}'USER'{$ENDIF});
end;

end.
