unit uPatientForm;

{$mode objfpc}{$H+}

// Patient maintenance form. Vintage browse/edit pattern:
//   * TDBGrid bound to dmMain.dsPatients shows the list
//   * TDBNavigator on the same DataSource provides Insert/Delete/Post/Cancel
//   * TDBEdit fields below the grid provide the edit form for the current row
//   * BeforePost handler validates required fields
//   * AfterPost commits the transaction (commit-per-row, fat-client style)

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  DBGrids, DBCtrls, DB, Buttons, ComCtrls, Mask;

type
  TfrmPatient = class(TForm)
    pnlTop:           TPanel;
    DBGrid1:          TDBGrid;
    pnlEdit:          TPanel;
    DBNavigator1:     TDBNavigator;
    btnClose:         TBitBtn;
    lblMRN:           TLabel;
    edtMRN:           TDBEdit;
    lblLast:          TLabel;
    edtLast:          TDBEdit;
    lblFirst:         TLabel;
    edtFirst:         TDBEdit;
    lblMiddle:        TLabel;
    edtMiddle:        TDBEdit;
    lblDOB:           TLabel;
    edtDOB:           TDBEdit;
    lblSex:           TLabel;
    cmbSex:           TDBComboBox;
    lblPhoneHome:     TLabel;
    edtPhoneHome:     TDBEdit;
    lblPhoneMobile:   TLabel;
    edtPhoneMobile:   TDBEdit;
    lblEmail:         TLabel;
    edtEmail:         TDBEdit;
    chkActive:        TDBCheckBox;
    // ------ Post-2001 era controls (added bit by bit) ------------------------
    // The original tidy two-row layout above ends here. Everything below was
    // shoehorned in by various developers between 2001 and 2018. We tried to
    // group it but the QA team complained about scrolling so we just kept
    // making the form taller.
    grpAddedFields:   TGroupBox;
    lblIsActive:      TLabel;
    cmbIsActive:      TDBComboBox;     // Reports query this. The GUI also writes Active above. Drift.
    lblMarital:       TLabel;
    cmbMarital:       TDBComboBox;
    lblSiteCode:      TLabel;
    cmbSiteCode:      TDBComboBox;
    lblInsurance:     TLabel;
    edtInsCarrier:    TDBEdit;
    edtPolicyNumber:  TDBEdit;
    chkConsent1:      TDBCheckBox;     // 2005 form
    chkConsent2:      TDBCheckBox;     // 2009 revision
    chkConsent3:      TDBCheckBox;     // 2014 revision
    StatusBar1:       TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btnCloseClick(Sender: TObject);
    procedure qryBeforePost(DataSet: TDataSet);
    procedure qryAfterPost(DataSet: TDataSet);
    procedure qryAfterDelete(DataSet: TDataSet);
    procedure qryAfterInsert(DataSet: TDataSet);
    procedure qryAfterScroll(DataSet: TDataSet);
  private
    procedure RefreshStatus;
  public
  end;

var
  frmPatient: TfrmPatient;

implementation

uses
  uDataModule, uAppConfig, DateUtils;

{$R *.lfm}

procedure TfrmPatient.FormCreate(Sender: TObject);
begin
  Caption := 'Patients';

  // Wire data-aware controls to the data module's persistent dataset.
  DBGrid1.DataSource         := dmMain.dsPatients;
  DBNavigator1.DataSource    := dmMain.dsPatients;
  edtMRN.DataSource          := dmMain.dsPatients;
  edtLast.DataSource         := dmMain.dsPatients;
  edtFirst.DataSource        := dmMain.dsPatients;
  edtMiddle.DataSource       := dmMain.dsPatients;
  edtDOB.DataSource          := dmMain.dsPatients;
  cmbSex.DataSource          := dmMain.dsPatients;
  edtPhoneHome.DataSource    := dmMain.dsPatients;
  edtPhoneMobile.DataSource  := dmMain.dsPatients;
  edtEmail.DataSource        := dmMain.dsPatients;
  chkActive.DataSource       := dmMain.dsPatients;

  // Post-2001 column wiring. Note: chkActive (above) and cmbIsActive (below)
  // bind to two physically different columns that should agree but don't.
  cmbIsActive.DataSource     := dmMain.dsPatients;
  cmbMarital.DataSource      := dmMain.dsPatients;
  cmbSiteCode.DataSource     := dmMain.dsPatients;
  edtInsCarrier.DataSource   := dmMain.dsPatients;
  edtPolicyNumber.DataSource := dmMain.dsPatients;
  chkConsent1.DataSource     := dmMain.dsPatients;
  chkConsent2.DataSource     := dmMain.dsPatients;
  chkConsent3.DataSource     := dmMain.dsPatients;

  // Hook dataset events on the shared query.
  dmMain.qryPatients.BeforePost   := @qryBeforePost;
  dmMain.qryPatients.AfterPost    := @qryAfterPost;
  dmMain.qryPatients.AfterDelete  := @qryAfterDelete;
  dmMain.qryPatients.AfterInsert  := @qryAfterInsert;
  dmMain.qryPatients.AfterScroll  := @qryAfterScroll;

  if not dmMain.qryPatients.Active then
    dmMain.qryPatients.Open;

  RefreshStatus;
end;

procedure TfrmPatient.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // Unhook events so the dataset can be reused safely by other forms.
  dmMain.qryPatients.BeforePost   := nil;
  dmMain.qryPatients.AfterPost    := nil;
  dmMain.qryPatients.AfterDelete  := nil;
  dmMain.qryPatients.AfterInsert  := nil;
  dmMain.qryPatients.AfterScroll  := nil;
end;

procedure TfrmPatient.btnCloseClick(Sender: TObject);
begin
  if dmMain.qryPatients.State in [dsEdit, dsInsert] then
    dmMain.qryPatients.Post;
  Close;
end;

procedure TfrmPatient.qryAfterInsert(DataSet: TDataSet);
begin
  // Defaults for new rows. We set both Active (1996 column) and IsActive
  // (2001 column) here so they agree at creation time. Subsequent edits
  // only hit one or the other depending on which control the user touches.
  DataSet.FieldByName('Sex').AsString      := 'U';
  DataSet.FieldByName('Active').AsBoolean  := True;
  DataSet.FieldByName('IsActive').AsString := 'Y';
  DataSet.FieldByName('RowVersion').AsInteger := 1;
  // SiteCode default left NULL by convention (== MAIN since 2013).
end;

procedure TfrmPatient.qryBeforePost(DataSet: TDataSet);
var
  MRN, LName, FName, Sex: string;
  DOB: TDateTime;
begin
  MRN   := Trim(DataSet.FieldByName('MRN').AsString);
  LName := Trim(DataSet.FieldByName('LastName').AsString);
  FName := Trim(DataSet.FieldByName('FirstName').AsString);
  Sex   := DataSet.FieldByName('Sex').AsString;

  if MRN = '' then
    raise EDatabaseError.Create('MRN is required.');
  if LName = '' then
    raise EDatabaseError.Create('Last Name is required.');
  if FName = '' then
    raise EDatabaseError.Create('First Name is required.');
  if not (Length(Sex) = 1) or (Pos(Sex, 'MFOU') = 0) then
    raise EDatabaseError.Create('Sex must be M, F, O, or U.');

  if DataSet.FieldByName('DateOfBirth').IsNull then
    raise EDatabaseError.Create('Date of Birth is required.');
  DOB := DataSet.FieldByName('DateOfBirth').AsDateTime;
  if DOB > Now then
    raise EDatabaseError.Create('Date of Birth cannot be in the future.');

  DataSet.FieldByName('UpdatedBy').AsString := AppCfg.Operator;
  if DataSet.State = dsInsert then
    DataSet.FieldByName('CreatedBy').AsString := AppCfg.Operator;
end;

procedure TfrmPatient.qryAfterPost(DataSet: TDataSet);
begin
  // Commit-per-row, fat-client style. ApplyUpdates flushes pending rows
  // through the SQL connector; CommitWork commits the transaction but
  // keeps it open via CommitRetaining.
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  RefreshStatus;
end;

procedure TfrmPatient.qryAfterDelete(DataSet: TDataSet);
begin
  TSQLQuery(DataSet).ApplyUpdates;
  dmMain.CommitWork;
  RefreshStatus;
end;

procedure TfrmPatient.qryAfterScroll(DataSet: TDataSet);
begin
  RefreshStatus;
end;

procedure TfrmPatient.RefreshStatus;
var
  Cnt, RecNo: Integer;
begin
  if dmMain.qryPatients.Active then
  begin
    Cnt   := dmMain.qryPatients.RecordCount;
    RecNo := dmMain.qryPatients.RecNo;
    StatusBar1.SimpleText :=
      Format('Record %d of %d  |  Operator: %s', [RecNo, Cnt, AppCfg.Operator]);
  end;
end;

end.
