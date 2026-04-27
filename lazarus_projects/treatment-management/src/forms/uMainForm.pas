unit uMainForm;

{$mode objfpc}{$H+}

// Main application form. Period-correct: a TForm with a TMainMenu, TStatusBar,
// and menu-item handlers that launch the modal child forms.

interface

uses
  Classes, SysUtils, Forms, Controls, Menus, ComCtrls, Dialogs, ExtCtrls,
  StdCtrls, Graphics, uAppConfig;

type
  TfrmMain = class(TForm)
    MainMenu1:        TMainMenu;
    mnuFile:          TMenuItem;
    mnuFileExit:      TMenuItem;
    mnuMaintain:      TMenuItem;
    mnuPatients:      TMenuItem;
    mnuPlans:         TMenuItem;
    mnuAppointments:  TMenuItem;
    mnuSessions:      TMenuItem;
    mnuTools:         TMenuItem;
    mnuAcceptDemo:    TMenuItem;
    mnuHelp:          TMenuItem;
    mnuHelpAbout:     TMenuItem;
    StatusBar1:       TStatusBar;
    pnlBanner:        TPanel;
    lblBanner:        TLabel;
    procedure FormCreate(Sender: TObject);
    procedure mnuFileExitClick(Sender: TObject);
    procedure mnuPatientsClick(Sender: TObject);
    procedure mnuPlansClick(Sender: TObject);
    procedure mnuAppointmentsClick(Sender: TObject);
    procedure mnuSessionsClick(Sender: TObject);
    procedure mnuAcceptDemoClick(Sender: TObject);
    procedure mnuHelpAboutClick(Sender: TObject);
  private
  public
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uPatientForm, uPlanForm, uAppointmentForm, uSessionForm, uAcceptDemoForm;

{$R *.lfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption := 'Treatment Management System';
  StatusBar1.Panels[0].Text := 'Operator: ' + AppCfg.Operator;
  StatusBar1.Panels[1].Text := 'DB: ' + AppCfg.Db.Database +
                               ' @ ' + AppCfg.Db.Host;
end;

procedure TfrmMain.mnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.mnuPatientsClick(Sender: TObject);
var
  F: TfrmPatient;
begin
  F := TfrmPatient.Create(Self);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TfrmMain.mnuPlansClick(Sender: TObject);
var
  F: TfrmPlan;
begin
  F := TfrmPlan.Create(Self);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TfrmMain.mnuAppointmentsClick(Sender: TObject);
var
  F: TfrmAppointment;
begin
  F := TfrmAppointment.Create(Self);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TfrmMain.mnuSessionsClick(Sender: TObject);
var
  F: TfrmSession;
begin
  F := TfrmSession.Create(Self);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TfrmMain.mnuAcceptDemoClick(Sender: TObject);
var
  F: TfrmAcceptDemo;
begin
  // The ACCEPT-loop form is non-modal but blocks the parent via its
  // RunAcceptLoop call, mirroring the Clarion idiom:
  //     OPEN(MyWindow); ACCEPT ... END; CLOSE(MyWindow)
  F := TfrmAcceptDemo.Create(Self);
  try
    F.Show;
    F.RunAcceptLoop;
  finally
    F.Free;
  end;
end;

procedure TfrmMain.mnuHelpAboutClick(Sender: TObject);
begin
  MessageDlg(
    'Treatment Management System',
    'Treatment Management System' + LineEnding +
    'Lazarus / FreePascal fat-client demo' + LineEnding + LineEnding +
    'INI: ' + AppCfg.IniPath,
    mtInformation, [mbOK], 0);
end;

end.
