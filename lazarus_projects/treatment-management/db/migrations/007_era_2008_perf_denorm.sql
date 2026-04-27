-- ============================================================================
-- Migration 007 — Era 2008 (performance denormalization)
-- ============================================================================
--
-- DBA: K. Ramirez
-- Tickets: TM-622 ("schedule grid takes 14 seconds to load")
--
-- The schedule grid joins Appointments → Patients → TreatmentPlans for every
-- visible row. With the new Northshore satellite, that's 80,000 patients
-- and a 14-second redraw. Vendor's official solution: "buy more RAM."
--
-- Our solution: copy the patient name and plan code onto the Appointments
-- and TreatmentSessions rows. Populate on INSERT via trigger. UPDATE the
-- snapshot when the GUI saves a row. Manual SQL edits to the parent table
-- will *not* propagate. We are aware. Compliance is not.
--
-- Ramirez 2008-04-22: known drift triggers:
--   * Patient name change   -> Appointment.PatientNameSnap stale
--   * Plan code rename      -> Appointment.PlanCodeSnap stale
--   * Direct UPDATE to TreatmentSessions.OffsetAnterior etc -> OffsetCSV stale
-- All three have been observed in QA. Flagged as "future work."
--
-- Ramirez 2009-02: still future work.
-- (annotation 2014, R. Park): some things never change.
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Appointments"
    ADD COLUMN "PatientNameSnap" VARCHAR(120),
    ADD COLUMN "PlanCodeSnap"    VARCHAR(20);

ALTER TABLE tm."TreatmentSessions"
    ADD COLUMN "PatientNameSnap" VARCHAR(120),
    ADD COLUMN "PlanCodeSnap"    VARCHAR(20),
    ADD COLUMN "OffsetCSV"       VARCHAR(60);

-- INSERT trigger for Appointments. Pulls patient name + plan code at
-- creation time. There is intentionally no UPDATE trigger; rename
-- propagation was deferred to "future work."
CREATE OR REPLACE FUNCTION tm.snap_appointment_parents() RETURNS trigger AS $$
BEGIN
    SELECT "LastName" || ', ' || "FirstName"
      INTO NEW."PatientNameSnap"
      FROM tm."Patients"
     WHERE "PatientID" = NEW."PatientID";

    IF NEW."PlanID" IS NOT NULL THEN
        SELECT "PlanCode"
          INTO NEW."PlanCodeSnap"
          FROM tm."TreatmentPlans"
         WHERE "PlanID" = NEW."PlanID";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "TR_Appt_SnapParents"
    BEFORE INSERT ON tm."Appointments"
    FOR EACH ROW EXECUTE FUNCTION tm.snap_appointment_parents();

-- INSERT trigger for TreatmentSessions. Pulls patient name from the
-- plan→patient join, plan code, and a comma-separated offset summary.
CREATE OR REPLACE FUNCTION tm.snap_session_parents() RETURNS trigger AS $$
BEGIN
    SELECT pa."LastName" || ', ' || pa."FirstName", pl."PlanCode"
      INTO NEW."PatientNameSnap", NEW."PlanCodeSnap"
      FROM tm."TreatmentPlans" pl
      JOIN tm."Patients"       pa ON pa."PatientID" = pl."PatientID"
     WHERE pl."PlanID" = NEW."PlanID";

    -- OffsetCSV: A,S,L,Magnitude — the BeamMaster reporting tool reads this
    -- column directly because parsing four numeric columns "took too long."
    NEW."OffsetCSV" :=
        COALESCE(NEW."OffsetAnterior"::text, '') || ',' ||
        COALESCE(NEW."OffsetSuperior"::text, '') || ',' ||
        COALESCE(NEW."OffsetLateral"::text,  '') || ',' ||
        COALESCE(NEW."OffsetMagnitude"::text, '');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "TR_Session_SnapParents"
    BEFORE INSERT ON tm."TreatmentSessions"
    FOR EACH ROW EXECUTE FUNCTION tm.snap_session_parents();

-- Backfill existing rows. Note: this happens once. Subsequent updates to
-- the parent rows do not propagate. (See header comment.)
UPDATE tm."Appointments" a
   SET "PatientNameSnap" = pa."LastName" || ', ' || pa."FirstName",
       "PlanCodeSnap"    = pl."PlanCode"
  FROM tm."Patients" pa
  LEFT JOIN tm."TreatmentPlans" pl ON pl."PlanID" = a."PlanID"
 WHERE pa."PatientID" = a."PatientID";

UPDATE tm."TreatmentSessions" s
   SET "PatientNameSnap" = pa."LastName" || ', ' || pa."FirstName",
       "PlanCodeSnap"    = pl."PlanCode",
       "OffsetCSV"       =
            COALESCE(s."OffsetAnterior"::text, '') || ',' ||
            COALESCE(s."OffsetSuperior"::text, '') || ',' ||
            COALESCE(s."OffsetLateral"::text,  '') || ',' ||
            COALESCE(s."OffsetMagnitude"::text, '')
  FROM tm."TreatmentPlans" pl
  JOIN tm."Patients"       pa ON pa."PatientID" = pl."PatientID"
 WHERE pl."PlanID" = s."PlanID";

COMMENT ON COLUMN tm."Appointments"."PatientNameSnap" IS
    'Snapshot of patient name at appointment creation. Does NOT update on patient rename — known drift, "future work" since 2008.';
COMMENT ON COLUMN tm."TreatmentSessions"."OffsetCSV" IS
    'Comma-separated A,S,L,Magnitude. Populated on INSERT only. Direct SQL updates to offset columns will leave this stale. (Ramirez, 2008)';
