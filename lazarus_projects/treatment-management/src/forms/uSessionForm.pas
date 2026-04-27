unit uSessionForm;

{$mode objfpc}{$H+}

// Treatment Sessions maintenance form. Per-fraction delivery records.
//
// Reuses the offset/ISqrt logic from clarion_projects/treatment-offset/:
//   * Three signed mm offsets (Anterior / Superior / Lateral)
//   * Magnitude = ISqrt(A^2 + S^2 + L^2) at 0.1 mm resolution (cGy-style
//     fixed-point: scale up by 100, sqrt, scale back down)
//   * [Recalc] button reapplies the formula on demand
//   * Lifecycle: Pending -> InProgress -> (Completed | Aborted)

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  DBGrids, DBCtrls, DB, Buttons, ComCtrls, Mask, Math;

type
  TfrmSession = class(TForm)
    pnlTop:           TPanel;
    DBGrid1:          TDBGrid;
    pnlEdit:          TPanel;
    DBNavigator1:     TDBNavigator;
    btnStart:         TBitBtn;
    btnComplete:      TBitBtn;
    btnAbort:         TBitBtn;
    btnRecalc:        TBitBtn;
    btnClose:         TBitBtn;
    lblAppointment:   TLabel;
    cmbAppointment:   TDBLookupComboBox;
    lblPlan:          TLabel;
    cmbPlan:          TDBLookupComboBox;
    lblFraction:      TLabel;
    edtFraction:      TDBEdit;
    lblDelivered:     TLabel;
    edtDelivered:     TDBEdit;
    lblOffsetA:       TLabel;
    edtOffsetA:       TDBEdit;
    lblOffsetS:       TLabel;
    edtOffsetS:       TDBEdit;
    lblOffsetL:       TLabel;
    edtOffsetL:       TDBEdit;
    lblMagnitude:     TLabel;
    edtMagnitude:     TDBEdit;
    lblStatus:        TLabel;
    cmbStatus:        TDBComboBox;
    lblTherapist:     TLabel;
    edtTherapist:     TDBEdit;
    lblStartedAt:     TLabel;
    edtStartedAt:     TDBEdit;
    lblEndedAt:       TLabel;
    edtEndedAt:       TDBEdit;
    lblNotes:         TLabel;
    memNotes:         TDBMemo;
    StatusBar1:       TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btnStartClick(Sender: TObject);
    procedure btnCompleteClick(Sender: TObject);
    procedure btnAbortClick(Sender: TObject);
    procedure btnRecalcClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure qryAfterInsert(DataSet: TDataSet);
    procedure qryBeforePost(DataSet: TDataSet);
    procedure qryAfterPost(DataSet: TDataSet);
    procedure qryAfterDelete(DataSet: TDataSet);
    procedure qryAfterScroll(DataSet: TDataSet);
  private
    procedure RefreshStatus;
    procedure TransitionTo(const NewStatus: string);
    function  ComputeMagnitude(A, S, L: Double): Double;
    procedure ApplyMagnitude(DataSet: TDataSet);
  public
  end;

var
  frmSession: TfrmSession;

implementation

uses
  uDataModule, uAppConfig;

{$R *.lfm}

procedure TfrmSession.FormCreate(Sender: TObject);
begin
  Caption := 'Treatment Sessions';

  if not dmMain.qryLookupAppts.Active then dmMain.qryLookupAppts.Open;
  if not dmMain.qryLookupPlans.Active then dmMain.qryLookupPlans.Open;

  DBGrid1.DataSource         := dmMain.dsSessions;
  DBNavigator1.DataSource    := dmMain.dsSessions;
  cmbAppointment.DataSource  := dmMain.dsSessions;
  cmbAppointment.ListSource  := dmMain.dsLookupAppts;
  cmbAppointment.DataField   := 'AppointmentID';
  cmbAppointment.KeyField    := 'AppointmentID';
  cmbAppointment.ListField   := 'Label';
  cmbPlan.DataSource         := dmMain.dsSessions;
  cmbPlan.ListSource         := dmMain.dsLookupPlans;
  cmbPlan.DataField          := 'PlanID';
  cmbPlan.KeyField           := 'PlanID';
  cmbPlan.ListField          := 'Label';
  edtFraction.DataSource     := dmMain.dsSessions;
  edtDelivered.DataSource    := dmMain.dsSessions;
  edtOffsetA.DataSource      := dmMain.dsSessions;
  edtOffsetS.DataSource      := dmMain.dsSessions;
  edtOffsetL.DataSource      := dmMain.dsSessions;
  edtMagnitude.DataSource    := dmMain.dsSessions;
  cmbStatus.DataSource       := dmMain.dsSessions;
  edtTherapist.DataSource    := dmMain.dsSessions;
  edtStartedAt.DataSource    := dmMain.dsSessions;
  edtEndedAt.DataSource      := dmMain.dsSessions;
  memNotes.DataSource        := dmMain.dsSessions;

  dmMain.qrySessions.AfterInsert := @qryAfterInsert;
  dmMain.qrySessions.BeforePost  := @qryBeforePost;
  dmMain.qrySessions.AfterPost   := @qryAfterPost;
  dmMain.qrySessions.AfterDelete := @qryAfterDelete;
  dmMain.qrySessions.AfterScroll := @qryAfterScroll;

  if not dmMain.qrySessions.Active then
    dmMain.qrySessions.Open;

  RefreshStatus;
end;

procedure TfrmSession.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  dmMain.qrySessions.AfterInsert := nil;
  dmMain.qrySessions.BeforePost  := nil;
  dmMain.qrySessions.AfterPost   := nil;
  dmMain.qrySessions.AfterDelete := nil;
  dmMain.qrySessions.AfterScroll := nil;
end;

procedure TfrmSession.btnCloseClick(Sender: TObject);
begin
  if dmMain.qrySessions.State in [dsEdit, dsInsert] then
    dmMain.qrySessions.Post;
  Close;
end;

// ISqrt-style magnitude over the three signed mm offsets. Scaled to
// preserve 0.01 mm resolution through integer sqrt the way OffsetLib does.
function TfrmSession.ComputeMagnitude(A, S, L: Double): Double;
var
  ScaledSumSq: Int64;
begin
  // Scale to integer hundredths-of-mm.
  ScaledSumSq := Round(A * 100) * Round(A * 100)
               + Round(S * 100) * Round(S * 100)
               + Round(L * 100) * Round(L * 100);
  Result := Sqrt(ScaledSumSq) / 100.0;
end;

procedure TfrmSession.ApplyMagnitude(DataSet: TDataSet);
var
  A, S, L, M: Double;
begin
  A := 0; S := 0; L := 0;
  if not DataSet.FieldByName('OffsetAnterior').IsNull then
    A := DataSet.FieldByName('OffsetAnterior').AsFloat;
  if not DataSet.FieldByName('OffsetSuperior').IsNull then
    S := DataSet.FieldByName('OffsetSuperior').AsFloat;
  if not DataSet.FieldByName('OffsetLateral').IsNull then
    L := DataSet.FieldByName('OffsetLateral').AsFloat;
  M := ComputeMagnitude(A, S, L);
  DataSet.FieldByName('OffsetMagnitude').AsFloat :=
    SimpleRoundTo(M, -2);  // 0.01 mm resolution
end;

procedure TfrmSession.btnRecalcClick(Sender: TObject);
var
  Q: TDataSet;
begin
  Q := dmMain.qrySessions;
  if Q.IsEmpty then Exit;
  if not (Q.State in [dsEdit, dsInsert]) then Q.Edit;
  ApplyMagnitude(Q);
end;

procedure TfrmSession.TransitionTo(const NewStatus: string);
var
  Q: TDataSet;
  Curr: string;
begin
  Q := dmMain.qrySessions;
  if Q.IsEmpty then Exit;
  Curr := Q.FieldByName('Status').AsString;

  if (NewStatus = 'InProgress') and (Curr <> 'Pending') then
    raise EDatabaseError.Create('Can only start a Pending session.');
  if (NewStatus = 'Completed') and (Curr <> 'InProgress') then
    raise EDatabaseError.Create('Can only complete an InProgress session.');
  if (NewStatus = 'Aborted')
     and (Curr in ['Completed','Aborted']) then
    raise EDatabaseError.Create('Cannot abort a ' + Curr + ' session.');

  Q.Edit;
  Q.FieldByName('Status').AsString := NewStatus;
  if NewStatus = 'InProgress' then
    Q.FieldByName('StartedAt').AsDateTime := Now
  else if NewStatus in ['Completed','Aborted'] then
    Q.FieldByName('EndedAt').AsDateTime := Now;
  Q.Post;
end;

procedure TfrmSession.btnStartClick(Sender: TObject);
begin
  TransitionTo('InProgress');
end;

procedure TfrmSession.btnCompleteClick(Sender: TObject);
begin
  TransitionTo('Completed');
end;

procedure TfrmSession.btnAbortClick(Sender: TObject);
begin
  TransitionTo('Aborted');
end;

procedure TfrmSession.qryAfterInsert(DataSet: TDataSet);
begin
  DataSet.FieldByName('Status').AsString := 'Pending';
  DataSet.FieldByName('FractionNumber').AsInteger := 1;
  DataSet.FieldByName('RowVersion').AsInteger := 1;
end;

procedure TfrmSession.qryBeforePost(DataSet: TDataSet);
var
  StartT, EndT: TDateTime;
begin
  if DataSet.FieldByName('AppointmentID').IsNull then
    raise EDatabaseError.Create('Appointment is required.');
  if DataSet.FieldByName('PlanID').IsNull then
    raise EDatabaseError.Create('Plan is required.');
  if DataSet.FieldByName('FractionNumber').AsInteger <= 0 then
    raise EDatabaseError.Create('Fraction Number must be a positive integer.');

  // Ensure magnitude is consistent with the three offsets at post time.
  ApplyMagnitude(DataSet);

  if not DataSet.FieldByName('StartedAt').IsNull
    and not DataSet.FieldByName('EndedAt').IsNull then
  begin
    StartT := DataSet.FieldByName('StartedAt').AsDateTime;
    EndT   := DataSet.FieldByName('EndedAt').AsDateTime;
    if EndT < StartT then
      raise EDatabaseError.Create('EndedAt cannot be before StartedAt.');
  end;

  DataSet.FieldByName('UpdatedBy').AsString := AppCfg.Operator;
  if DataSet.State = dsInsert then
    DataSet.FieldByName('CreatedBy').AsString := AppCfg.Operator;
end;

procedure TfrmSession.qryAfterPost(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  RefreshStatus;
end;

procedure TfrmSession.qryAfterDelete(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  RefreshStatus;
end;

procedure TfrmSession.qryAfterScroll(DataSet: TDataSet);
begin
  RefreshStatus;
end;

procedure TfrmSession.RefreshStatus;
var
  Q: TDataSet;
begin
  Q := dmMain.qrySessions;
  if Q.Active and not Q.IsEmpty then
    StatusBar1.SimpleText := Format(
      'Record %d of %d  |  Plan %s  |  Fx %d  |  %s',
      [Q.RecNo, Q.RecordCount,
       Q.FieldByName('PlanCode').AsString,
       Q.FieldByName('FractionNumber').AsInteger,
       Q.FieldByName('Status').AsString])
  else
    StatusBar1.SimpleText := '(no sessions)';
end;

end.
