-- ============================================================================
-- Migration 011 — Misc warts (multiple eras, retroactively numbered)
-- ============================================================================
--
-- This file is the catch-all for changes that didn't fit a clean release.
-- Most of these were applied directly in production by a contractor and
-- got reverse-engineered into a migration file later.
--
-- Provenance, in chronological order:
--
--   2009-04: contractor S. Bhatt added entry_user / entry_date and
--            last_modified columns in snake_case because "the other
--            DB I work on uses that convention." Was supposed to migrate
--            data from the existing CreatedBy / UpdatedAt columns. Did
--            not. Now both conventions exist on the same tables.
--
--   2011-08: A contractor (D. Whitfield, here for six weeks) decided
--            TreatmentPlans needed version tracking and added OldPlanID
--            as a self-FK to the predecessor plan. The actual SET_ID /
--            PlanVersion versioning has existed in the schema since 1996
--            (see migration 001) but Whitfield was not given a tour of
--            the schema and never queried the catalog. The new column
--            shipped, ran in parallel with the working SET_ID system
--            for two months, then caused a circular reference during a
--            2011 archive job. Park (then also a contractor) dropped
--            the FK constraint but left the column. ~12% of rows have
--            meaningful values from those two months; they tend to
--            disagree with the SET_ID lineage by 0-2 versions because
--            Whitfield was off-by-one on amendments. The application
--            no longer reads or writes OldPlanID; reports that filter
--            via OldPlanID IS NULL are inadvertently filtering out a
--            slice of the August-October 2011 production data and
--            nobody has caught it.
--
--   2018-03: contractor B. Lim renamed the audit columns "for clarity":
--            CreatedBy → who_created, UpdatedBy → who_updated. Lim left
--            two days later. The rename was reverted but the new columns
--            were never dropped. They contain Lim's two days of test data
--            for ~40 patients.
--
-- Park 2019: I have stopped counting.
-- ============================================================================

SET search_path TO tm, public;

-- ----------------------------------------------------------------------------
-- snake_case audit shadows (Bhatt, 2009)
-- ----------------------------------------------------------------------------
ALTER TABLE tm."Patients"
    ADD COLUMN entry_user      VARCHAR(60),
    ADD COLUMN entry_date      TIMESTAMP,
    ADD COLUMN last_modified   TIMESTAMP;

ALTER TABLE tm."TreatmentPlans"
    ADD COLUMN entry_user      VARCHAR(60),
    ADD COLUMN entry_date      TIMESTAMP,
    ADD COLUMN last_modified   TIMESTAMP,
    -- Bhatt also added the snake_case Dx coder column referenced in 006:
    ADD COLUMN diagnosis_coded_by VARCHAR(60);

ALTER TABLE tm."TreatmentSessions"
    ADD COLUMN entry_user      VARCHAR(60),
    ADD COLUMN entry_date      TIMESTAMP,
    ADD COLUMN last_modified   TIMESTAMP;

ALTER TABLE tm."Appointments"
    ADD COLUMN entry_user      VARCHAR(60),
    ADD COLUMN entry_date      TIMESTAMP,
    ADD COLUMN last_modified   TIMESTAMP;

-- ----------------------------------------------------------------------------
-- OldPlanID dangling column (Park, 2011)
-- ----------------------------------------------------------------------------
ALTER TABLE tm."TreatmentPlans"
    ADD COLUMN "OldPlanID" INTEGER;
-- The original definition was:
--   ADD CONSTRAINT "FK_Plan_OldPlan" FOREIGN KEY ("OldPlanID")
--       REFERENCES tm."TreatmentPlans"("PlanID") ON DELETE SET NULL;
-- Dropped 2011-08 due to circular reference during archive. Column retained
-- for historical revision linkage. Application no longer reads or writes it.

COMMENT ON COLUMN tm."TreatmentPlans"."OldPlanID" IS
    'Whitfield 2011 attempt at versioning, parallel to the SET_ID system that already existed. FK constraint dropped 2011-08 after a circular reference incident. ~12% of rows have values from Aug-Oct 2011; off-by-one against PlanSetID/PlanVersion. Reports filtering OldPlanID IS NULL silently exclude that slice.';

-- ----------------------------------------------------------------------------
-- Lim's "rename" remnants (2018)
-- ----------------------------------------------------------------------------
ALTER TABLE tm."Patients"
    ADD COLUMN who_created VARCHAR(60),
    ADD COLUMN who_updated VARCHAR(60);

COMMENT ON COLUMN tm."Patients"."who_created" IS
    'Lim 2018 rename attempt. Rolled back. Column retained because ~40 patients have meaningful values from Lim s 2-day tenure.';

-- ----------------------------------------------------------------------------
-- Add the new tables to the publication so the WAL stream stays complete.
-- (Patients_OLD, Patient_Photos_DEPRECATED, Z_Backup_Sessions_2009 are
--  intentionally NOT published — they are read-only ghosts.)
-- ----------------------------------------------------------------------------
-- (Nothing to do here — the existing publication tm_pub_all in migration 002
--  already covers the four core tables. Schema additions to those tables
--  flow through automatically.)
