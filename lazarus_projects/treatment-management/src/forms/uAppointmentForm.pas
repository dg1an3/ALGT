unit uAppointmentForm;

{$mode objfpc}{$H+}

// Appointments maintenance form. Browse + edit with two lookup combos
// (Patient, Plan) and dedicated transition buttons:
//   [Check In]  Scheduled  -> CheckedIn  (sets CheckedInAt = now)
//   [Complete]  CheckedIn|InProgress -> Completed (sets CompletedAt = now)
//   [Cancel]    any -> Cancelled (prompts for reason)
// Mirrors the appointment lifecycle implied by the CHECK constraint on
// Appointments.Status.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  DBGrids, DBCtrls, DB, Buttons, ComCtrls, Mask;

type
  TfrmAppointment = class(TForm)
    pnlTop:           TPanel;
    DBGrid1:          TDBGrid;
    pnlEdit:          TPanel;
    DBNavigator1:     TDBNavigator;
    btnCheckIn:       TBitBtn;
    btnComplete:      TBitBtn;
    btnCancel:        TBitBtn;
    btnClose:         TBitBtn;
    lblPatient:       TLabel;
    cmbPatient:       TDBLookupComboBox;
    lblPlan:          TLabel;
    cmbPlan:          TDBLookupComboBox;
    lblStart:         TLabel;
    edtStart:         TDBEdit;
    lblEnd:           TLabel;
    edtEnd:           TDBEdit;
    lblType:          TLabel;
    cmbType:          TDBComboBox;
    lblStatus:        TLabel;
    cmbStatus:        TDBComboBox;
    lblResource:      TLabel;
    edtResource:      TDBEdit;
    lblCheckedIn:     TLabel;
    edtCheckedIn:     TDBEdit;
    lblCompleted:     TLabel;
    edtCompleted:     TDBEdit;
    lblCancelReason:  TLabel;
    edtCancelReason:  TDBEdit;
    lblNotes:         TLabel;
    memNotes:         TDBMemo;
    StatusBar1:       TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btnCheckInClick(Sender: TObject);
    procedure btnCompleteClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure qryAfterInsert(DataSet: TDataSet);
    procedure qryBeforePost(DataSet: TDataSet);
    procedure qryAfterPost(DataSet: TDataSet);
    procedure qryAfterDelete(DataSet: TDataSet);
    procedure qryAfterScroll(DataSet: TDataSet);
  private
    procedure RefreshStatus;
    procedure TransitionTo(const NewStatus: string);
  public
  end;

var
  frmAppointment: TfrmAppointment;

implementation

uses
  uDataModule, uAppConfig, DateUtils;

{$R *.lfm}

procedure TfrmAppointment.FormCreate(Sender: TObject);
begin
  Caption := 'Appointments';

  if not dmMain.qryLookupPatients.Active then dmMain.qryLookupPatients.Open;
  if not dmMain.qryLookupPlans.Active    then dmMain.qryLookupPlans.Open;

  DBGrid1.DataSource         := dmMain.dsAppointments;
  DBNavigator1.DataSource    := dmMain.dsAppointments;
  cmbPatient.DataSource      := dmMain.dsAppointments;
  cmbPatient.ListSource      := dmMain.dsLookupPatients;
  cmbPatient.DataField       := 'PatientID';
  cmbPatient.KeyField        := 'PatientID';
  cmbPatient.ListField       := 'Label';
  cmbPlan.DataSource         := dmMain.dsAppointments;
  cmbPlan.ListSource         := dmMain.dsLookupPlans;
  cmbPlan.DataField          := 'PlanID';
  cmbPlan.KeyField           := 'PlanID';
  cmbPlan.ListField          := 'Label';
  edtStart.DataSource        := dmMain.dsAppointments;
  edtEnd.DataSource          := dmMain.dsAppointments;
  cmbType.DataSource         := dmMain.dsAppointments;
  cmbStatus.DataSource       := dmMain.dsAppointments;
  edtResource.DataSource     := dmMain.dsAppointments;
  edtCheckedIn.DataSource    := dmMain.dsAppointments;
  edtCompleted.DataSource    := dmMain.dsAppointments;
  edtCancelReason.DataSource := dmMain.dsAppointments;
  memNotes.DataSource        := dmMain.dsAppointments;

  dmMain.qryAppointments.AfterInsert := @qryAfterInsert;
  dmMain.qryAppointments.BeforePost  := @qryBeforePost;
  dmMain.qryAppointments.AfterPost   := @qryAfterPost;
  dmMain.qryAppointments.AfterDelete := @qryAfterDelete;
  dmMain.qryAppointments.AfterScroll := @qryAfterScroll;

  if not dmMain.qryAppointments.Active then
    dmMain.qryAppointments.Open;

  RefreshStatus;
end;

procedure TfrmAppointment.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  dmMain.qryAppointments.AfterInsert := nil;
  dmMain.qryAppointments.BeforePost  := nil;
  dmMain.qryAppointments.AfterPost   := nil;
  dmMain.qryAppointments.AfterDelete := nil;
  dmMain.qryAppointments.AfterScroll := nil;
end;

procedure TfrmAppointment.btnCloseClick(Sender: TObject);
begin
  if dmMain.qryAppointments.State in [dsEdit, dsInsert] then
    dmMain.qryAppointments.Post;
  Close;
end;

procedure TfrmAppointment.TransitionTo(const NewStatus: string);
var
  Q: TDataSet;
  Curr: string;
begin
  Q := dmMain.qryAppointments;
  if Q.IsEmpty then Exit;
  Curr := Q.FieldByName('Status').AsString;

  // Lifecycle transition guards (mirrors what a Prolog DCG-LTS would
  // accept).
  if (NewStatus = 'CheckedIn') and (Curr <> 'Scheduled') then
    raise EDatabaseError.Create('Can only check in a Scheduled appointment.');
  if (NewStatus = 'Completed')
     and not (Curr in ['CheckedIn','InProgress']) then
    raise EDatabaseError.Create('Can only complete a CheckedIn or InProgress appointment.');
  if (NewStatus = 'Cancelled')
     and (Curr in ['Completed','Cancelled','NoShow']) then
    raise EDatabaseError.Create('Cannot cancel a ' + Curr + ' appointment.');

  Q.Edit;
  Q.FieldByName('Status').AsString := NewStatus;
  if NewStatus = 'CheckedIn' then
    Q.FieldByName('CheckedInAt').AsDateTime := Now
  else if NewStatus = 'Completed' then
    Q.FieldByName('CompletedAt').AsDateTime := Now;
  Q.Post;
end;

procedure TfrmAppointment.btnCheckInClick(Sender: TObject);
begin
  TransitionTo('CheckedIn');
end;

procedure TfrmAppointment.btnCompleteClick(Sender: TObject);
begin
  TransitionTo('Completed');
end;

procedure TfrmAppointment.btnCancelClick(Sender: TObject);
var
  Q: TDataSet;
  Reason: string;
begin
  Q := dmMain.qryAppointments;
  if Q.IsEmpty then Exit;
  Reason := '';
  if not InputQuery('Cancel Appointment', 'Cancellation reason:', Reason) then
    Exit;
  if Trim(Reason) = '' then
    raise EDatabaseError.Create('Cancellation reason is required.');

  Q.Edit;
  Q.FieldByName('Status').AsString := 'Cancelled';
  Q.FieldByName('CancelReason').AsString := Reason;
  Q.Post;
end;

procedure TfrmAppointment.qryAfterInsert(DataSet: TDataSet);
begin
  DataSet.FieldByName('Status').AsString := 'Scheduled';
  DataSet.FieldByName('AppointmentType').AsString := 'Treatment';
  DataSet.FieldByName('RowVersion').AsInteger := 1;
end;

procedure TfrmAppointment.qryBeforePost(DataSet: TDataSet);
var
  StartT, EndT: TDateTime;
  Status: string;
begin
  if DataSet.FieldByName('PatientID').IsNull then
    raise EDatabaseError.Create('Patient is required.');
  if DataSet.FieldByName('ScheduledStart').IsNull then
    raise EDatabaseError.Create('Scheduled Start is required.');
  if DataSet.FieldByName('ScheduledEnd').IsNull then
    raise EDatabaseError.Create('Scheduled End is required.');

  StartT := DataSet.FieldByName('ScheduledStart').AsDateTime;
  EndT   := DataSet.FieldByName('ScheduledEnd').AsDateTime;
  if EndT <= StartT then
    raise EDatabaseError.Create('Scheduled End must be after Scheduled Start.');

  Status := DataSet.FieldByName('Status').AsString;
  if (Status = 'Cancelled')
     and (Trim(DataSet.FieldByName('CancelReason').AsString) = '') then
    raise EDatabaseError.Create('Cancellation reason is required for Cancelled appointments.');

  DataSet.FieldByName('UpdatedBy').AsString := AppCfg.Operator;
  if DataSet.State = dsInsert then
    DataSet.FieldByName('CreatedBy').AsString := AppCfg.Operator;
end;

procedure TfrmAppointment.qryAfterPost(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  dmMain.RefreshLookups;
  RefreshStatus;
end;

procedure TfrmAppointment.qryAfterDelete(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  dmMain.RefreshLookups;
  RefreshStatus;
end;

procedure TfrmAppointment.qryAfterScroll(DataSet: TDataSet);
begin
  RefreshStatus;
end;

procedure TfrmAppointment.RefreshStatus;
var
  Q: TDataSet;
begin
  Q := dmMain.qryAppointments;
  if Q.Active and not Q.IsEmpty then
    StatusBar1.SimpleText := Format('Record %d of %d  |  %s  |  %s',
      [Q.RecNo, Q.RecordCount,
       FormatDateTime('yyyy-mm-dd hh:nn', Q.FieldByName('ScheduledStart').AsDateTime),
       Q.FieldByName('Status').AsString])
  else
    StatusBar1.SimpleText := '(no appointments)';
end;

end.
