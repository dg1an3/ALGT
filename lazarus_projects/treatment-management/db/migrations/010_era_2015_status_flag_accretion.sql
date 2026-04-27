-- ============================================================================
-- Migration 010 — Era 2015 (status flag accretion)
-- ============================================================================
--
-- DBA: R. Park (Ramirez retired 2014)
-- Tickets: TM-1102, TM-1108, TM-1115, TM-1119, TM-1124
--
-- Five tickets across four months, each one adding "just a flag" to the
-- Appointments table because nobody wanted to refactor the existing Status
-- column with its CHECK constraint. The five flags don't agree with each
-- other or with Status. Reports query whichever flag the analyst was
-- familiar with. Welcome to your new normal.
--
--   IsCancelled       BOOLEAN  — should match Status='Cancelled'. Doesn't.
--   IsLocked          BOOLEAN  — billing lock; survives cancellation.
--   IsArchived        CHAR(1)  — 'Y'/'N' (Park insisted on consistency
--                                with IsActive in Patients despite
--                                the rest of the table using BOOLEAN)
--   WorkflowState     SMALLINT — magic numbers per the 2015 BPMN diagram:
--                                0=draft, 1=scheduled, 2=in-flight,
--                                3=done, 7=do-not-process, 99=ghost
--                                ("ghost" was for a 2016 CMS audit
--                                workaround and is undocumented elsewhere)
--   ReadyForBilling   CHAR(1)  — billing's parallel universe.
--
-- A trigger was written to keep IsCancelled in sync with Status. It was
-- disabled in October 2017 after it caused a deadlock during nightly batch.
-- The disabling was meant to be temporary. (See ticket TM-4471.)
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Appointments"
    ADD COLUMN "IsCancelled"     BOOLEAN  DEFAULT FALSE,
    ADD COLUMN "IsLocked"        BOOLEAN  DEFAULT FALSE,
    ADD COLUMN "IsArchived"      CHAR(1)  DEFAULT 'N',
    ADD COLUMN "WorkflowState"   SMALLINT DEFAULT 1,
    ADD COLUMN "ReadyForBilling" CHAR(1)  DEFAULT 'N';

-- Backfill IsCancelled. After this, drift accumulates with every Status
-- update because the sync trigger is disabled (see below).
UPDATE tm."Appointments"
   SET "IsCancelled"     = ("Status" = 'Cancelled'),
       "WorkflowState"   = CASE "Status"
            WHEN 'Scheduled'  THEN 1
            WHEN 'CheckedIn'  THEN 2
            WHEN 'InProgress' THEN 2
            WHEN 'Completed'  THEN 3
            WHEN 'Cancelled'  THEN 7
            WHEN 'NoShow'     THEN 7
            ELSE 0
       END,
       "ReadyForBilling" = CASE WHEN "Status" = 'Completed' THEN 'Y' ELSE 'N' END;

-- The sync trigger that was supposed to keep IsCancelled current.
-- Disabled in production since October 2017 (TM-4471). Body kept here
-- but commented out for archaeological purposes.
--
-- CREATE OR REPLACE FUNCTION tm.sync_appt_iscancelled() RETURNS trigger AS $$
-- BEGIN
--     NEW."IsCancelled" := (NEW."Status" = 'Cancelled');
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE TRIGGER "TR_Appt_SyncIsCancelled"
--     BEFORE UPDATE OF "Status" ON tm."Appointments"
--     FOR EACH ROW EXECUTE FUNCTION tm.sync_appt_iscancelled();

COMMENT ON COLUMN tm."Appointments"."IsCancelled" IS
    'Should mirror Status=Cancelled. Sync trigger disabled October 2017 (TM-4471). Drifts.';
COMMENT ON COLUMN tm."Appointments"."WorkflowState" IS
    'Per BPMN diagram 2015: 0=draft 1=scheduled 2=in-flight 3=done 7=do-not-process 99=ghost. The 99 is a 2016 audit workaround.';
COMMENT ON COLUMN tm."Appointments"."IsArchived" IS
    'Y/N. Park 2015 insisted on string consistency with Patients.IsActive even though every other 2015 column uses BOOLEAN.';
