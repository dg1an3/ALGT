unit uClarionLoop;

{$mode objfpc}{$H+}

// Clarion-style ACCEPT loop primitive for Lazarus / FreePascal.
//
// Translates Clarion's central WINDOW event-handling idiom
//
//     ACCEPT
//       CASE EVENT()
//       OF EVENT:Accepted
//         CASE FIELD()
//         OF ?BtnOK
//            ...
//         END
//       OF EVENT:CloseWindow
//         BREAK
//       END
//     END
//
// into idiomatic Object Pascal. Pattern:
//
//     FLoop := TAcceptLoop.Create;
//     FLoop.OnEvent := @HandleEvent;       // your CASE EVENT() OF ...
//     FLoop.OpenTraceFile('demo.evt');     // optional .evt-style log
//     FLoop.Run;                            // blocks until Break_
//
// The form's button OnClick handlers post events:
//
//     procedure TForm.btnOKClick(Sender: TObject);
//     begin
//       FLoop.Post(EV_ACCEPTED, FLD_BTN_OK);
//     end;
//
// The trace file format mirrors clarion_projects/form-cli/*.evt so the
// planned Prolog DCG can read either source.

interface

uses
  Classes, SysUtils, Forms, DateUtils;

const
  // Event kinds — analogous to Clarion's EVENT:* constants.
  EV_NONE          =  0;
  EV_OPEN_WINDOW   =  1;   // EVENT:OpenWindow
  EV_CLOSE_WINDOW  =  2;   // EVENT:CloseWindow
  EV_ACCEPTED      =  3;   // EVENT:Accepted (button press, default action)
  EV_REJECTED      =  4;   // EVENT:Rejected (cancel)
  EV_SELECTED      =  5;   // EVENT:Selected (focus enter)
  EV_NEW_SELECTION =  6;   // EVENT:NewSelection (focus change)
  EV_TIMER         =  7;
  EV_ALERT_KEY     =  8;
  EV_USER          = 100;  // user-defined event range starts here

type
  TClarionEvent = record
    Kind:    Integer;     // EV_*
    FieldId: Integer;     // ?Control id
    IntArg:  Integer;     // optional payload
    StrArg:  string;
  end;

  TAcceptEventHandler = procedure(const Ev: TClarionEvent) of object;

  TAcceptLoop = class
  private
    // Plain dynamic array used as a FIFO. O(N) pop is fine for UI event
    // volumes; trades worst-case efficiency for code clarity.
    FQueue:       array of TClarionEvent;
    FAccepting:   Boolean;
    FCycleFlag:   Boolean;
    FOnEvent:     TAcceptEventHandler;
    FTrace:       TextFile;
    FTraceOpen:   Boolean;
    FStartTime:   TDateTime;
    FTickInterval: Integer;
    function PopEvent(out Ev: TClarionEvent): Boolean;
    procedure PushEvent(const Ev: TClarionEvent);
    procedure WriteTrace(const Ev: TClarionEvent);
    function EventName(K: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Post(AKind, AFieldId: Integer); overload;
    procedure Post(AKind, AFieldId, AIntArg: Integer); overload;
    procedure Post(AKind, AFieldId: Integer; const AStrArg: string); overload;

    procedure Break_;
    procedure Cycle;
    procedure Run;

    procedure OpenTraceFile(const FileName: string);
    procedure CloseTraceFile;

    property OnEvent: TAcceptEventHandler read FOnEvent write FOnEvent;
    property Accepting: Boolean read FAccepting;
    // Idle delay between message-pump cycles. 5 ms by default; set 0 for
    // fastest possible polling, higher for lower CPU.
    property TickInterval: Integer read FTickInterval write FTickInterval;
  end;

implementation

constructor TAcceptLoop.Create;
begin
  inherited;
  SetLength(FQueue, 0);
  FAccepting    := False;
  FCycleFlag    := False;
  FTraceOpen    := False;
  FTickInterval := 5;
end;

destructor TAcceptLoop.Destroy;
begin
  CloseTraceFile;
  inherited;
end;

procedure TAcceptLoop.PushEvent(const Ev: TClarionEvent);
var
  Idx: Integer;
begin
  Idx := Length(FQueue);
  SetLength(FQueue, Idx + 1);
  FQueue[Idx] := Ev;
end;

procedure TAcceptLoop.Post(AKind, AFieldId: Integer);
var
  Ev: TClarionEvent;
begin
  Ev.Kind    := AKind;
  Ev.FieldId := AFieldId;
  Ev.IntArg  := 0;
  Ev.StrArg  := '';
  PushEvent(Ev);
end;

procedure TAcceptLoop.Post(AKind, AFieldId, AIntArg: Integer);
var
  Ev: TClarionEvent;
begin
  Ev.Kind    := AKind;
  Ev.FieldId := AFieldId;
  Ev.IntArg  := AIntArg;
  Ev.StrArg  := '';
  PushEvent(Ev);
end;

procedure TAcceptLoop.Post(AKind, AFieldId: Integer; const AStrArg: string);
var
  Ev: TClarionEvent;
begin
  Ev.Kind    := AKind;
  Ev.FieldId := AFieldId;
  Ev.IntArg  := 0;
  Ev.StrArg  := AStrArg;
  PushEvent(Ev);
end;

function TAcceptLoop.PopEvent(out Ev: TClarionEvent): Boolean;
var
  i: Integer;
begin
  Result := Length(FQueue) > 0;
  if not Result then Exit;
  Ev := FQueue[0];
  for i := 1 to High(FQueue) do
    FQueue[i - 1] := FQueue[i];
  SetLength(FQueue, Length(FQueue) - 1);
end;

procedure TAcceptLoop.Break_;
begin
  FAccepting := False;
end;

procedure TAcceptLoop.Cycle;
begin
  FCycleFlag := True;
end;

procedure TAcceptLoop.Run;
var
  Ev: TClarionEvent;
begin
  FAccepting := True;
  FStartTime := Now;
  Post(EV_OPEN_WINDOW, 0);
  while FAccepting and not Application.Terminated do
  begin
    Application.ProcessMessages;
    while PopEvent(Ev) do
    begin
      WriteTrace(Ev);
      FCycleFlag := False;
      if Assigned(FOnEvent) then
        FOnEvent(Ev);
      if not FAccepting then Break;
      if FCycleFlag then Continue;
    end;
    if FAccepting and (FTickInterval > 0) then
      Sleep(FTickInterval);
  end;
  // Synthesize a closing event for the trace if user used Break_.
  Ev.Kind := EV_CLOSE_WINDOW;
  Ev.FieldId := 0;
  Ev.IntArg := 0;
  Ev.StrArg := '';
  WriteTrace(Ev);
end;

procedure TAcceptLoop.OpenTraceFile(const FileName: string);
begin
  CloseTraceFile;
  AssignFile(FTrace, FileName);
  Rewrite(FTrace);
  FTraceOpen := True;
  WriteLn(FTrace, '# uClarionLoop trace; format: <ms> <EVENT> <FIELD> [int] [str]');
end;

procedure TAcceptLoop.CloseTraceFile;
begin
  if FTraceOpen then
  begin
    CloseFile(FTrace);
    FTraceOpen := False;
  end;
end;

function TAcceptLoop.EventName(K: Integer): string;
begin
  case K of
    EV_NONE:          Result := 'EV_NONE';
    EV_OPEN_WINDOW:   Result := 'EV_OPEN_WINDOW';
    EV_CLOSE_WINDOW:  Result := 'EV_CLOSE_WINDOW';
    EV_ACCEPTED:      Result := 'EV_ACCEPTED';
    EV_REJECTED:      Result := 'EV_REJECTED';
    EV_SELECTED:      Result := 'EV_SELECTED';
    EV_NEW_SELECTION: Result := 'EV_NEW_SELECTION';
    EV_TIMER:         Result := 'EV_TIMER';
    EV_ALERT_KEY:     Result := 'EV_ALERT_KEY';
  else
    if K >= EV_USER then
      Result := Format('EV_USER+%d', [K - EV_USER])
    else
      Result := Format('EV_%d', [K]);
  end;
end;

procedure TAcceptLoop.WriteTrace(const Ev: TClarionEvent);
var
  MsElapsed: Int64;
begin
  if not FTraceOpen then Exit;
  MsElapsed := MilliSecondsBetween(Now, FStartTime);
  WriteLn(FTrace, Format('%6d %-18s %4d %d %s',
    [MsElapsed, EventName(Ev.Kind), Ev.FieldId, Ev.IntArg, Ev.StrArg]));
  Flush(FTrace);
end;

end.
