program TreatmentMgmt;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,         // LCL widgetset
  Forms,
  uDataModule,
  uMainForm,
  uPatientForm,
  uPlanForm,
  uAppointmentForm,
  uSessionForm,
  uClarionLoop,
  uAcceptDemoForm,
  uAppConfig;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'Treatment Management System';
  Application.Scaled := True;
  Application.Initialize;

  // Load DB connection settings before forms are created so the
  // data module can connect on form-create.
  LoadAppConfig;

  Application.CreateForm(TdmMain, dmMain);
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
