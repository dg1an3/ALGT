unit uAcceptDemoForm;

{$mode objfpc}{$H+}

// Demonstrator form for uClarionLoop. Shows the Clarion-style ACCEPT
// pattern in pure Lazarus:
//
//   * Buttons / edits forward to the loop via Post(EV_xxx, FLD_xxx).
//   * HandleEvent is the central CASE EVENT() OF dispatcher.
//   * The form is shown non-modally; the parent calls RunAcceptLoop
//     which blocks until Loop.Break_ and then returns.
//   * Every event is logged to a .evt file in the user's temp directory
//     so it can be diffed against form-cli's .evt traces.
//
// To convert an existing form (e.g. uPatientForm) to this style, replace
// each callback body with a single Loop.Post(...) and put the actual
// logic in HandleEvent's CASE statements.

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Buttons, ComCtrls,
  uClarionLoop;

const
  // Field IDs — analogous to Clarion's ?ControlName.
  FLD_EDIT_VALUE  =  10;
  FLD_BTN_PING    = 100;
  FLD_BTN_OK      = 200;
  FLD_BTN_CANCEL  = 201;

type
  TfrmAcceptDemo = class(TForm)
    pnlTop:        TPanel;
    memLog:        TMemo;
    pnlBottom:     TPanel;
    lblValue:      TLabel;
    edtValue:      TEdit;
    btnPing:       TBitBtn;
    btnOK:         TBitBtn;
    btnCancel:     TBitBtn;
    StatusBar1:    TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnPingClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure edtValueEnter(Sender: TObject);
    procedure edtValueChange(Sender: TObject);
  private
    FLoop:      TAcceptLoop;
    FPingCount: Integer;
    procedure HandleEvent(const Ev: TClarionEvent);
    procedure Log(const S: string);
  public
    procedure RunAcceptLoop;
  end;

var
  frmAcceptDemo: TfrmAcceptDemo;

implementation

{$R *.lfm}

procedure TfrmAcceptDemo.FormCreate(Sender: TObject);
begin
  Caption     := 'Clarion-style ACCEPT loop demo';
  FPingCount  := 0;
  FLoop       := TAcceptLoop.Create;
  FLoop.OnEvent := @HandleEvent;
  FLoop.OpenTraceFile(GetTempDir(False) + 'accept_demo.evt');
  StatusBar1.SimpleText := 'Trace: ' + GetTempDir(False) + 'accept_demo.evt';
end;

procedure TfrmAcceptDemo.FormDestroy(Sender: TObject);
begin
  FLoop.Free;
end;

procedure TfrmAcceptDemo.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Window-manager close (Alt+F4 / X button) translates to EV_CLOSE_WINDOW.
  // Don't close yet — let the loop see the event and decide.
  if FLoop.Accepting then
  begin
    FLoop.Post(EV_CLOSE_WINDOW, 0);
    CanClose := False;
  end
  else
    CanClose := True;
end;

// ============================================================================
// Lazarus event handlers — each one is a single Post(...) call.
// ============================================================================

procedure TfrmAcceptDemo.btnPingClick(Sender: TObject);
begin
  FLoop.Post(EV_ACCEPTED, FLD_BTN_PING);
end;

procedure TfrmAcceptDemo.btnOKClick(Sender: TObject);
begin
  FLoop.Post(EV_ACCEPTED, FLD_BTN_OK);
end;

procedure TfrmAcceptDemo.btnCancelClick(Sender: TObject);
begin
  FLoop.Post(EV_REJECTED, FLD_BTN_CANCEL);
end;

procedure TfrmAcceptDemo.edtValueEnter(Sender: TObject);
begin
  FLoop.Post(EV_SELECTED, FLD_EDIT_VALUE);
end;

procedure TfrmAcceptDemo.edtValueChange(Sender: TObject);
begin
  FLoop.Post(EV_NEW_SELECTION, FLD_EDIT_VALUE, edtValue.Text);
end;

// ============================================================================
// The Clarion-style central dispatcher.
// ============================================================================

procedure TfrmAcceptDemo.HandleEvent(const Ev: TClarionEvent);
begin
  case Ev.Kind of

    EV_OPEN_WINDOW:
      Log('Window opened.');

    EV_CLOSE_WINDOW:
      begin
        Log('Close requested.');
        FLoop.Break_;
      end;

    EV_NEW_SELECTION:
      case Ev.FieldId of
        FLD_EDIT_VALUE:
          Log(Format('edtValue changed: "%s"', [Ev.StrArg]));
      end;

    EV_SELECTED:
      case Ev.FieldId of
        FLD_EDIT_VALUE:
          Log('edtValue focused.');
      end;

    EV_ACCEPTED:
      case Ev.FieldId of
        FLD_BTN_PING:
          begin
            Inc(FPingCount);
            Log(Format('Ping #%d.', [FPingCount]));
          end;
        FLD_BTN_OK:
          begin
            Log(Format('OK pressed (value="%s", pings=%d). Closing.',
              [edtValue.Text, FPingCount]));
            FLoop.Break_;
          end;
      end;

    EV_REJECTED:
      case Ev.FieldId of
        FLD_BTN_CANCEL:
          begin
            Log('Cancel pressed. Closing.');
            FLoop.Break_;
          end;
      end;
  end;
end;

procedure TfrmAcceptDemo.Log(const S: string);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + S);
end;

procedure TfrmAcceptDemo.RunAcceptLoop;
begin
  FLoop.Run;   // blocks until Break_
  Close;        // FormCloseQuery sees Accepting=False and allows it.
end;

end.
