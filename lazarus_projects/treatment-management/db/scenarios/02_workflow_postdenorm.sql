-- ============================================================================
-- Scenario 02 — Post-denormalization workflow with intentional drift
-- ============================================================================
--
-- Run AFTER migrations 003-011. Exercises the rotted schema and deliberately
-- triggers each known drift pattern:
--
--   T20: register a patient with the post-2001 columns populated
--        (IsActive, Insurance fields, MaritalStatus, ConsentForm1/2/3,
--         SiteCode, Bhatt's snake_case audit columns, Lim's who_created)
--
--   T21: rename the patient (LastName Reyes -> Reyes-Mendoza)
--        => Appointment.PatientNameSnap goes stale
--        => TreatmentSession.PatientNameSnap goes stale
--        => DateOfBirth_Char does NOT update (no UPDATE trigger from 004)
--
--   T22: schedule an appointment (PatientNameSnap, PlanCodeSnap populated
--        by INSERT trigger; matches Patients at this moment)
--
--   T23: insert a session (snapshots populated; OffsetCSV populated)
--
--   T24: DIRECT SQL UPDATE to the offset columns (simulating an admin fix
--        from psql, not the GUI)
--        => OffsetCSV does NOT update (trigger only fires on INSERT)
--
--   T25: rename a TreatmentPlan's PlanCode
--        => Appointment.PlanCodeSnap goes stale
--        => Session.PlanCodeSnap goes stale
--
--   T26: cancel the appointment via Status update
--        => IsCancelled stays FALSE (sync trigger disabled October 2017)
--        => WorkflowState stays at its old value (no sync at all)
--        => ReadyForBilling stays 'N' (no sync)
--
--   T27: a patient updated via Lim's contractor-era columns
--        (who_updated set; UpdatedBy NOT set) — demonstrates that the
--        two audit conventions disagree on the same row.
--
-- The Prolog DCG should be able to recognize each of these drift conditions
-- by comparing the Snap columns against the join on the parent table.
-- ============================================================================

SET search_path TO tm, public;

\echo === T20: Register patient with post-2001 columns ===
BEGIN;
INSERT INTO tm."Patients" (
    "MRN","LastName","FirstName","DateOfBirth","Sex",
    "PhoneMobile","Email",
    "IsActive","MaritalStatus","SpouseInfo",
    "InsuranceCarrier","PolicyNumber","GroupNumber",
    "InsuranceCarrier2","PolicyNumber2","GroupNumber2",
    "ConsentForm1Signed","ConsentForm2Signed","ConsentForm3Signed",
    "ConsentForm1SignedAt","SiteCode",
    entry_user, entry_date, last_modified, who_created
)
VALUES (
    'MRN0003-WV','Park-Whittle','Alice','1971-09-04','F',
    '555-0303','alice.pw@example.org',
    'Y','M','Whittle, Robert|1969-02-11|555-0304',
    'BlueShield West','BSW-22198','GRP-44',
    'Aetna','AET-008812','GRP-WV-12',
    TRUE, TRUE, FALSE,
    '2026-04-28 10:15:00','WV',
    'rt.alvarez', '2026-04-28 10:15:00', '2026-04-28 10:15:00', 'rt.alvarez'
);
COMMIT;

\echo === T21: Rename existing patient (drift trigger) ===
-- This causes drift on every Appointment / Session row that already snapshot
-- this patient s name. The DOB_Char shadow does NOT update.
BEGIN;
UPDATE tm."Patients"
   SET "LastName" = 'Reyes-Mendoza',
       last_modified = CURRENT_TIMESTAMP
 WHERE "MRN" = 'MRN0001';
COMMIT;

\echo === T22: Schedule a new appointment (snapshots populated by trigger) ===
BEGIN;
WITH p AS (SELECT "PatientID" FROM tm."Patients" WHERE "MRN" = 'MRN0003-WV')
INSERT INTO tm."Appointments"
    ("PatientID","PlanID","ScheduledStart","ScheduledEnd",
     "AppointmentType","Resource",
     "ExternalSchedulingID","SiteCode",
     entry_user, entry_date, last_modified)
SELECT "PatientID", NULL,
       TIMESTAMP '2026-05-02 13:00:00', TIMESTAMP '2026-05-02 13:30:00',
       'Consult', 'WV-CLINIC-1',
       'v2|7741|WV','WV',
       'rt.alvarez', '2026-04-28 10:20:00', '2026-04-28 10:20:00'
FROM p;
COMMIT;

\echo === T23: Insert a treatment session for the existing plan ===
BEGIN;
WITH a AS (
    SELECT "AppointmentID","PlanID"
      FROM tm."Appointments"
     WHERE "ScheduledStart" = TIMESTAMP '2026-04-26 09:00:00'
       AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001')
)
INSERT INTO tm."TreatmentSessions"
    ("AppointmentID","PlanID","FractionNumber","DeliveredDose",
     "OffsetAnterior","OffsetSuperior","OffsetLateral","OffsetMagnitude",
     "StartedAt","EndedAt","Status","Therapist",
     "SiteCode", entry_user, entry_date, last_modified)
SELECT "AppointmentID","PlanID", 2, 200.00,
       1.5, 0.0, 0.5, 1.58,    -- magnitude pre-computed by app
       TIMESTAMP '2026-04-26 09:05:00', TIMESTAMP '2026-04-26 09:21:00',
       'Completed','rt.alvarez',
       NULL, 'rt.alvarez', '2026-04-26 09:21:00', '2026-04-26 09:21:00'
FROM a;
COMMIT;

\echo === T24: DIRECT SQL update to offsets (drift: OffsetCSV stays stale) ===
-- Simulates a DBA fixing a typed value from psql. The OffsetCSV column
-- snapshot is NOT updated because the trigger only fires on INSERT.
BEGIN;
UPDATE tm."TreatmentSessions"
   SET "OffsetAnterior" = 2.5,           -- corrected value
       "OffsetMagnitude" = 2.55           -- recomputed by hand
 WHERE "FractionNumber" = 2
   AND "PlanID" = (SELECT "PlanID" FROM tm."TreatmentPlans" WHERE "PlanCode"='PLAN-A1');
COMMIT;

\echo === T25: Rename a TreatmentPlan PlanCode (drift: PlanCodeSnap stale) ===
BEGIN;
UPDATE tm."TreatmentPlans"
   SET "PlanCode" = 'PLAN-A1-R1',
       last_modified = CURRENT_TIMESTAMP
 WHERE "PlanCode" = 'PLAN-A1';
COMMIT;

\echo === T26: Cancel an appointment (drift: IsCancelled / WorkflowState stay stale) ===
-- The 2017-disabled trigger means none of the parallel flag columns update.
BEGIN;
UPDATE tm."Appointments"
   SET "Status" = 'Cancelled',
       "CancelReason" = 'Re-planned after rename',
       last_modified = CURRENT_TIMESTAMP
 WHERE "ScheduledStart" = TIMESTAMP '2026-04-26 09:00:00'
   AND "PatientID" = (SELECT "PatientID" FROM tm."Patients" WHERE "MRN"='MRN0001');
COMMIT;

\echo === T27: Lim-era audit-column drift on a single update ===
-- Application normally writes UpdatedBy. This update only touches Lim's
-- shadow column, so the two audit columns disagree.
BEGIN;
UPDATE tm."Patients"
   SET "Email" = 'a.pw@example.org',
       who_updated = 'b.lim',
       last_modified = CURRENT_TIMESTAMP
 WHERE "MRN" = 'MRN0003-WV';
COMMIT;
