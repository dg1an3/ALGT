-- Scenario: 01_clinical_workflow
--
-- A realistic end-to-end clinical workflow that exercises every entity:
--   T1: register two patients
--   T2: create a treatment plan for patient 1
--   T3: approve the plan
--   T4: schedule three treatment appointments + one consult
--   T5: check in patient 1 for first appointment
--   T6: record session 1 (with offsets, ISqrt magnitude per treatment-offset/)
--   T7: complete the first appointment
--   T8: cancel the third appointment (no-show recovery)
--   T9: update patient 2 demographics
--
-- When run against a database with the tm_pub_all publication active, this
-- generates the WAL events captured in db/traces/01_clinical_workflow.wal.jsonl
-- (the offline fixture for the Prolog port).

SET search_path TO tm, public;

\echo === T1: Register two patients ===
BEGIN;
INSERT INTO tm."Patients" ("MRN","LastName","FirstName","DateOfBirth","Sex",
                           "PhoneHome","Email")
VALUES ('MRN0001','Reyes','Maria','1962-03-14','F',
        '555-0101','maria.reyes@example.org');
INSERT INTO tm."Patients" ("MRN","LastName","FirstName","DateOfBirth","Sex",
                           "PhoneMobile")
VALUES ('MRN0002','Okafor','Daniel','1955-11-02','M','555-0202');
COMMIT;

\echo === T2: Create treatment plan for patient 1 ===
BEGIN;
INSERT INTO tm."TreatmentPlans"
    ("PatientID","PlanCode","PlanName","Diagnosis","TreatmentSite",
     "PrescribedDose","Fractions","DosePerFraction","PlanStatus")
SELECT "PatientID", 'PLAN-A1', 'Right Breast IMRT',
       'Invasive ductal carcinoma, right breast', 'Right Breast',
       5000.00, 25, 200.00, 'Draft'
FROM tm."Patients" WHERE "MRN" = 'MRN0001';
COMMIT;

\echo === T3: Approve the plan ===
BEGIN;
UPDATE tm."TreatmentPlans"
   SET "PlanStatus" = 'Approved',
       "ApprovedBy" = 'dr.chen',
       "ApprovedAt" = TIMESTAMP '2026-04-22 09:15:00'
 WHERE "PlanCode" = 'PLAN-A1';
COMMIT;

\echo === T4: Schedule appointments ===
BEGIN;
WITH p AS (SELECT "PatientID" FROM tm."Patients" WHERE "MRN" = 'MRN0001'),
     pl AS (SELECT "PlanID" FROM tm."TreatmentPlans" WHERE "PlanCode" = 'PLAN-A1')
INSERT INTO tm."Appointments"
    ("PatientID","PlanID","ScheduledStart","ScheduledEnd",
     "AppointmentType","Resource")
SELECT p."PatientID", pl."PlanID",
       TIMESTAMP '2026-04-25 09:00:00', TIMESTAMP '2026-04-25 09:30:00',
       'Treatment', 'LINAC-1'
FROM p, pl
UNION ALL
SELECT p."PatientID", pl."PlanID",
       TIMESTAMP '2026-04-26 09:00:00', TIMESTAMP '2026-04-26 09:30:00',
       'Treatment', 'LINAC-1'
FROM p, pl
UNION ALL
SELECT p."PatientID", pl."PlanID",
       TIMESTAMP '2026-04-27 09:00:00', TIMESTAMP '2026-04-27 09:30:00',
       'Treatment', 'LINAC-1'
FROM p, pl
UNION ALL
SELECT p."PatientID", NULL,
       TIMESTAMP '2026-05-04 14:00:00', TIMESTAMP '2026-05-04 14:30:00',
       'Consult', 'CLINIC-3'
FROM p;
COMMIT;

\echo === T5: Check in patient 1 for first appointment ===
BEGIN;
UPDATE tm."Appointments"
   SET "Status" = 'CheckedIn',
       "CheckedInAt" = TIMESTAMP '2026-04-25 08:52:00'
 WHERE "ScheduledStart" = TIMESTAMP '2026-04-25 09:00:00'
   AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001');
COMMIT;

\echo === T6: Record treatment session 1 ===
BEGIN;
WITH a AS (
    SELECT "AppointmentID","PlanID"
      FROM tm."Appointments"
     WHERE "ScheduledStart" = TIMESTAMP '2026-04-25 09:00:00'
       AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001')
)
INSERT INTO tm."TreatmentSessions"
    ("AppointmentID","PlanID","FractionNumber","DeliveredDose",
     "OffsetAnterior","OffsetSuperior","OffsetLateral","OffsetMagnitude",
     "StartedAt","EndedAt","Status","Therapist")
SELECT "AppointmentID","PlanID", 1, 200.00,
       2.0, -1.0, 0.5, 2.29,    -- ISqrt(2.0^2 + 1.0^2 + 0.5^2) ~= 2.29 mm
       TIMESTAMP '2026-04-25 09:05:00', TIMESTAMP '2026-04-25 09:22:00',
       'Completed','rt.alvarez'
FROM a;
COMMIT;

\echo === T7: Complete the first appointment ===
BEGIN;
UPDATE tm."Appointments"
   SET "Status" = 'Completed',
       "CompletedAt" = TIMESTAMP '2026-04-25 09:24:00'
 WHERE "ScheduledStart" = TIMESTAMP '2026-04-25 09:00:00'
   AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001');
COMMIT;

\echo === T8: Cancel the third appointment ===
BEGIN;
UPDATE tm."Appointments"
   SET "Status" = 'Cancelled',
       "CancelReason" = 'Patient requested reschedule'
 WHERE "ScheduledStart" = TIMESTAMP '2026-04-27 09:00:00'
   AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001');
COMMIT;

\echo === T9: Update patient 2 demographics ===
BEGIN;
UPDATE tm."Patients"
   SET "Email" = 'daniel.okafor@example.org',
       "AddressLine1" = '742 Evergreen Terrace',
       "City" = 'Springfield',
       "StateProv" = 'IL',
       "PostalCode" = '62704'
 WHERE "MRN" = 'MRN0002';
COMMIT;

\echo === T10: Amend plan PLAN-A1 (re-plan after delivered fraction 1) ===
-- Mosaiq-style SET_ID versioning in action:
--   * Closes v1 (Status -> Superseded, IsCurrent = FALSE, EndedAt = NOW)
--   * Inserts v2 sharing the same PlanSetID, PlanVersion = 2, Status = Draft
-- The future Prolog DCG should observe these two events as a single
-- amendment transition on the plan stream identified by PlanSetID.
BEGIN;
SELECT tm.amend_plan(
    (SELECT "PlanID" FROM tm."TreatmentPlans" WHERE "PlanCode"='PLAN-A1' AND "IsCurrent"),
    'dr.chen'
);
-- Re-prescribe at a slightly higher dose for v2.
UPDATE tm."TreatmentPlans"
   SET "PrescribedDose"   = 5400.00,
       "Fractions"        = 27,
       "DosePerFraction"  = 200.00
 WHERE "PlanCode" = 'PLAN-A1'
   AND "IsCurrent" = TRUE;
COMMIT;
