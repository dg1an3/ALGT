unit uDataModule;

{$mode objfpc}{$H+}

// Shared data module — period-correct fat-client architecture.
// Owns the single TPQConnection + TSQLTransaction for the application.
// Each browse form binds its own TSQLQuery components to dmMain.Connection.

interface

uses
  Classes, SysUtils, DB, SQLDB, pqconnection, uAppConfig;

type
  TdmMain = class(TDataModule)
    Connection:        TPQConnection;
    MainTrans:         TSQLTransaction;
    qryPatients:       TSQLQuery;
    dsPatients:        TDataSource;
    qryPlans:          TSQLQuery;
    dsPlans:           TDataSource;
    qryAppointments:   TSQLQuery;
    dsAppointments:    TDataSource;
    qrySessions:       TSQLQuery;
    dsSessions:        TDataSource;
    // Read-only lookup queries for combo boxes / lookup fields.
    qryLookupPatients: TSQLQuery;
    dsLookupPatients:  TDataSource;
    qryLookupPlans:    TSQLQuery;
    dsLookupPlans:     TDataSource;
    qryLookupAppts:    TSQLQuery;
    dsLookupAppts:     TDataSource;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
  public
    procedure ConnectToDatabase;
    procedure CommitWork;
    procedure RollbackWork;
    procedure RefreshLookups;
  end;

var
  dmMain: TdmMain;

implementation

{$R *.lfm}

procedure TdmMain.DataModuleCreate(Sender: TObject);
begin
  Connection.HostName     := AppCfg.Db.Host;
  Connection.DatabaseName := AppCfg.Db.Database;
  Connection.UserName     := AppCfg.Db.User;
  Connection.Password     := AppCfg.Db.Password;
  Connection.Params.Clear;
  Connection.Params.Add('port=' + IntToStr(AppCfg.Db.Port));
  Connection.Params.Add('search_path=tm,public');
  if AppCfg.Db.Params <> '' then
    Connection.Params.Add(AppCfg.Db.Params);

  Connection.Transaction := MainTrans;
  MainTrans.Database     := Connection;

  ConnectToDatabase;
end;

procedure TdmMain.DataModuleDestroy(Sender: TObject);
begin
  if Assigned(Connection) and Connection.Connected then
  begin
    if MainTrans.Active then
      MainTrans.Rollback;
    Connection.Close;
  end;
end;

procedure TdmMain.ConnectToDatabase;
begin
  if not Connection.Connected then
    Connection.Open;
  if not MainTrans.Active then
    MainTrans.StartTransaction;
end;

procedure TdmMain.CommitWork;
begin
  if MainTrans.Active then
    MainTrans.CommitRetaining;
end;

procedure TdmMain.RollbackWork;
begin
  if MainTrans.Active then
    MainTrans.RollbackRetaining;
end;

procedure TdmMain.RefreshLookups;
  procedure ReopenIfActive(Q: TSQLQuery);
  begin
    if Q.Active then
    begin
      Q.Close;
      Q.Open;
    end;
  end;
begin
  ReopenIfActive(qryLookupPatients);
  ReopenIfActive(qryLookupPlans);
  ReopenIfActive(qryLookupAppts);
end;

end.
