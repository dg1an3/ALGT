unit uPlanForm;

{$mode objfpc}{$H+}

// Treatment Plans maintenance form. Same vintage browse/edit pattern as
// uPatientForm: TDBGrid + TDBNavigator + TDBEdit fields, BeforePost
// validation, AfterPost commit.
//
// Adds: TDBLookupComboBox for the Patient FK, an [Approve] button that
// transitions the plan to Approved (setting ApprovedBy/ApprovedAt),
// and BeforePost enforcement of the
//     PrescribedDose ~= Fractions * DosePerFraction
// invariant when all three are populated.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  DBGrids, DBCtrls, DB, Buttons, ComCtrls, Mask;

type
  TfrmPlan = class(TForm)
    pnlTop:           TPanel;
    DBGrid1:          TDBGrid;
    pnlEdit:          TPanel;
    DBNavigator1:     TDBNavigator;
    btnApprove:       TBitBtn;
    btnAmend:         TBitBtn;
    btnClose:         TBitBtn;
    lblVersion:       TLabel;
    lblPatient:       TLabel;
    cmbPatient:       TDBLookupComboBox;
    lblPlanCode:      TLabel;
    edtPlanCode:      TDBEdit;
    lblPlanName:      TLabel;
    edtPlanName:      TDBEdit;
    lblDiagnosis:     TLabel;
    edtDiagnosis:     TDBEdit;
    lblSite:          TLabel;
    edtSite:          TDBEdit;
    lblPrescribed:    TLabel;
    edtPrescribed:    TDBEdit;
    lblFractions:     TLabel;
    edtFractions:     TDBEdit;
    lblDosePerFx:     TLabel;
    edtDosePerFx:     TDBEdit;
    lblStatus:        TLabel;
    cmbStatus:        TDBComboBox;
    lblApprovedBy:    TLabel;
    edtApprovedBy:    TDBEdit;
    lblApprovedAt:    TLabel;
    edtApprovedAt:    TDBEdit;
    lblNotes:         TLabel;
    memNotes:         TDBMemo;
    StatusBar1:       TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btnApproveClick(Sender: TObject);
    procedure btnAmendClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure qryAfterInsert(DataSet: TDataSet);
    procedure qryBeforePost(DataSet: TDataSet);
    procedure qryAfterPost(DataSet: TDataSet);
    procedure qryAfterDelete(DataSet: TDataSet);
    procedure qryAfterScroll(DataSet: TDataSet);
  private
    procedure RefreshStatus;
  public
  end;

var
  frmPlan: TfrmPlan;

implementation

uses
  uDataModule, uAppConfig, Math;

{$R *.lfm}

procedure TfrmPlan.FormCreate(Sender: TObject);
begin
  Caption := 'Treatment Plans';

  // Open the lookup before binding so the combo can show labels for
  // the first scrolled row.
  if not dmMain.qryLookupPatients.Active then
    dmMain.qryLookupPatients.Open;

  DBGrid1.DataSource         := dmMain.dsPlans;
  DBNavigator1.DataSource    := dmMain.dsPlans;
  cmbPatient.DataSource      := dmMain.dsPlans;
  cmbPatient.ListSource      := dmMain.dsLookupPatients;
  cmbPatient.DataField       := 'PatientID';
  cmbPatient.KeyField        := 'PatientID';
  cmbPatient.ListField       := 'Label';
  edtPlanCode.DataSource     := dmMain.dsPlans;
  edtPlanName.DataSource     := dmMain.dsPlans;
  edtDiagnosis.DataSource    := dmMain.dsPlans;
  edtSite.DataSource         := dmMain.dsPlans;
  edtPrescribed.DataSource   := dmMain.dsPlans;
  edtFractions.DataSource    := dmMain.dsPlans;
  edtDosePerFx.DataSource    := dmMain.dsPlans;
  cmbStatus.DataSource       := dmMain.dsPlans;
  edtApprovedBy.DataSource   := dmMain.dsPlans;
  edtApprovedAt.DataSource   := dmMain.dsPlans;
  memNotes.DataSource        := dmMain.dsPlans;

  dmMain.qryPlans.AfterInsert := @qryAfterInsert;
  dmMain.qryPlans.BeforePost  := @qryBeforePost;
  dmMain.qryPlans.AfterPost   := @qryAfterPost;
  dmMain.qryPlans.AfterDelete := @qryAfterDelete;
  dmMain.qryPlans.AfterScroll := @qryAfterScroll;

  if not dmMain.qryPlans.Active then
    dmMain.qryPlans.Open;

  RefreshStatus;
end;

procedure TfrmPlan.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  dmMain.qryPlans.AfterInsert := nil;
  dmMain.qryPlans.BeforePost  := nil;
  dmMain.qryPlans.AfterPost   := nil;
  dmMain.qryPlans.AfterDelete := nil;
  dmMain.qryPlans.AfterScroll := nil;
end;

procedure TfrmPlan.btnCloseClick(Sender: TObject);
begin
  if dmMain.qryPlans.State in [dsEdit, dsInsert] then
    dmMain.qryPlans.Post;
  Close;
end;

procedure TfrmPlan.btnApproveClick(Sender: TObject);
var
  Q: TDataSet;
begin
  Q := dmMain.qryPlans;
  if Q.IsEmpty then Exit;
  if Q.FieldByName('PlanStatus').AsString in ['Approved','Active','Completed'] then
  begin
    MessageDlg('Already Approved',
      'This plan has already been approved.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Approve Plan',
       'Approve plan ' + Q.FieldByName('PlanCode').AsString + '?',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  Q.Edit;
  Q.FieldByName('PlanStatus').AsString  := 'Approved';
  Q.FieldByName('ApprovedBy').AsString  := AppCfg.Operator;
  Q.FieldByName('ApprovedAt').AsDateTime := Now;
  Q.Post;  // AfterPost commits
end;

// IMPAC/Mosaiq-style amendment: closes the current version and creates a
// new draft version with the same PlanSetID. Calls tm.amend_plan() on
// the server so the close/insert pair is atomic.
procedure TfrmPlan.btnAmendClick(Sender: TObject);
var
  Q:        TDataSet;
  CurId:    Integer;
  NewId:    Integer;
  Cmd:      TSQLQuery;
begin
  Q := dmMain.qryPlans;
  if Q.IsEmpty then Exit;

  if not Q.FieldByName('IsCurrent').AsBoolean then
  begin
    MessageDlg('Not Current',
      'This is a historical version and cannot be amended directly. ' +
      'Navigate to the current version of plan set ' +
      Q.FieldByName('PlanSetID').AsString + ' first.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('Amend Plan',
       Format('Close v%d of %s and create a new draft v%d?',
              [Q.FieldByName('PlanVersion').AsInteger,
               Q.FieldByName('PlanCode').AsString,
               Q.FieldByName('PlanVersion').AsInteger + 1]),
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if Q.State in [dsEdit, dsInsert] then Q.Post;
  CurId := Q.FieldByName('PlanID').AsInteger;

  Cmd := TSQLQuery.Create(nil);
  try
    Cmd.Database := dmMain.Connection;
    Cmd.Transaction := dmMain.MainTrans;
    Cmd.SQL.Text :=
      'SELECT tm.amend_plan(:plan_id, :amended_by) AS new_id';
    Cmd.ParamByName('plan_id').AsInteger := CurId;
    Cmd.ParamByName('amended_by').AsString := AppCfg.Operator;
    Cmd.Open;
    NewId := Cmd.FieldByName('new_id').AsInteger;
    Cmd.Close;
  finally
    Cmd.Free;
  end;

  dmMain.CommitWork;
  dmMain.RefreshLookups;

  // Refetch and locate the new draft version.
  Q.Close;
  Q.Open;
  Q.Locate('PlanID', NewId, []);
  RefreshStatus;

  MessageDlg('Amended',
    Format('Created new draft v%d. Edit and re-Approve to activate.',
           [Q.FieldByName('PlanVersion').AsInteger]),
    mtInformation, [mbOK], 0);
end;

procedure TfrmPlan.qryAfterInsert(DataSet: TDataSet);
begin
  DataSet.FieldByName('PlanStatus').AsString := 'Draft';
  DataSet.FieldByName('RowVersion').AsInteger := 1;
end;

procedure TfrmPlan.qryBeforePost(DataSet: TDataSet);
var
  Code, Name, Status: string;
  Prescribed, DosePerFx, Computed: Double;
  Fractions: Integer;
begin
  if DataSet.FieldByName('PatientID').IsNull then
    raise EDatabaseError.Create('Patient is required.');

  Code := Trim(DataSet.FieldByName('PlanCode').AsString);
  Name := Trim(DataSet.FieldByName('PlanName').AsString);
  if Code = '' then raise EDatabaseError.Create('Plan Code is required.');
  if Name = '' then raise EDatabaseError.Create('Plan Name is required.');

  Status := DataSet.FieldByName('PlanStatus').AsString;
  if Pos(Status, 'Draft|UnderReview|Approved|Active|Completed|Cancelled') = 0 then
    raise EDatabaseError.Create('Status must be one of Draft / UnderReview / ' +
      'Approved / Active / Completed / Cancelled.');

  // PrescribedDose ≈ Fractions × DosePerFraction (when all three are set)
  if not DataSet.FieldByName('PrescribedDose').IsNull
    and not DataSet.FieldByName('Fractions').IsNull
    and not DataSet.FieldByName('DosePerFraction').IsNull then
  begin
    Prescribed := DataSet.FieldByName('PrescribedDose').AsFloat;
    Fractions  := DataSet.FieldByName('Fractions').AsInteger;
    DosePerFx  := DataSet.FieldByName('DosePerFraction').AsFloat;
    if Fractions > 0 then
    begin
      Computed := Fractions * DosePerFx;
      if Abs(Computed - Prescribed) > 0.5 then
        raise EDatabaseError.CreateFmt(
          'Prescribed dose %.2f cGy does not match Fractions × DosePerFraction (%d × %.2f = %.2f cGy).',
          [Prescribed, Fractions, DosePerFx, Computed]);
    end;
  end;

  // Approval invariant — DB has the same CHECK constraint, but we want
  // a friendlier message before the round-trip.
  if Status in ['Approved','Active','Completed'] then
  begin
    if DataSet.FieldByName('ApprovedBy').IsNull
      or (Trim(DataSet.FieldByName('ApprovedBy').AsString) = '') then
      raise EDatabaseError.Create('ApprovedBy is required when status is ' + Status + '.');
    if DataSet.FieldByName('ApprovedAt').IsNull then
      raise EDatabaseError.Create('ApprovedAt is required when status is ' + Status + '.');
  end;

  DataSet.FieldByName('UpdatedBy').AsString := AppCfg.Operator;
  if DataSet.State = dsInsert then
    DataSet.FieldByName('CreatedBy').AsString := AppCfg.Operator;
end;

procedure TfrmPlan.qryAfterPost(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  // Plans drive lookup labels for Appointments/Sessions.
  dmMain.RefreshLookups;
  RefreshStatus;
end;

procedure TfrmPlan.qryAfterDelete(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  dmMain.RefreshLookups;
  RefreshStatus;
end;

procedure TfrmPlan.qryAfterScroll(DataSet: TDataSet);
begin
  RefreshStatus;
end;

procedure TfrmPlan.RefreshStatus;
var
  Q: TDataSet;
  CurMark: string;
begin
  Q := dmMain.qryPlans;
  if Q.Active and not Q.IsEmpty then
  begin
    if Q.FieldByName('IsCurrent').AsBoolean then
      CurMark := 'CURRENT'
    else
      CurMark := 'historical';
    StatusBar1.SimpleText := Format(
      'Record %d of %d  |  %s v%d (set %d, %s)',
      [Q.RecNo, Q.RecordCount,
       Q.FieldByName('PlanCode').AsString,
       Q.FieldByName('PlanVersion').AsInteger,
       Q.FieldByName('PlanSetID').AsInteger,
       CurMark]);
    lblVersion.Caption := Format('v%d (set %d) — %s',
      [Q.FieldByName('PlanVersion').AsInteger,
       Q.FieldByName('PlanSetID').AsInteger,
       CurMark]);
  end
  else
  begin
    StatusBar1.SimpleText := '(no plans)';
    lblVersion.Caption := '';
  end;
end;

end.
