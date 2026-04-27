-- ============================================================================
-- Migration 004 — Era 2003 (Y2K aftershock)
-- ============================================================================
--
-- DBA: M. Hollister
-- Tickets: TM-241, TM-244, TM-247
-- Why this exists:
--   The Cognos ImpromptuTM report writer ships a date parser that misreads
--   PostgreSQL DATE values as "00/00/0000" intermittently. The vendor's
--   official position (March 2003) is that it is a "configuration issue."
--   Our position is that it ships next Monday.
--
--   Solution: shadow the DateOfBirth column with a VARCHAR(10) that the
--   reports query directly, populated by trigger. Anyone touching DOB now
--   needs to update both columns. Nobody does. We expect 1-2% drift.
--
-- Also: Patients_OLD is the pre-2003 archive table. Empty in this codebase.
-- Production has 12,847 rows in it. Don't drop. (2007 footnote: still don't
-- drop. We tried in 2006 and audit complained.)
-- ============================================================================

SET search_path TO tm, public;

-- Y2K-vintage shadow column. Cognos reads this. The GUI writes DateOfBirth.
ALTER TABLE tm."Patients"
    ADD COLUMN "DateOfBirth_Char" VARCHAR(10),
    ADD COLUMN "BirthCentury"     SMALLINT;

-- Trigger only fires on INSERT. UPDATEs to DateOfBirth do NOT propagate to
-- DateOfBirth_Char. This is the "1-2% drift" we promised the reports team.
CREATE OR REPLACE FUNCTION tm.populate_dob_char() RETURNS trigger AS $$
BEGIN
    NEW."DateOfBirth_Char" := to_char(NEW."DateOfBirth", 'YYYY-MM-DD');
    -- BirthCentury is only populated for pre-1950 births, per the original
    -- Y2K cleanup spec. Don't ask.
    IF EXTRACT(YEAR FROM NEW."DateOfBirth") < 1950 THEN
        NEW."BirthCentury" := 19;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "TR_Patients_DOBChar"
    BEFORE INSERT ON tm."Patients"
    FOR EACH ROW EXECUTE FUNCTION tm.populate_dob_char();

-- Backfill — but with a couple of typos that crept in from a hand-edited
-- CSV import in March 2003. Two existing rows will have DOB_Char that
-- disagrees with DateOfBirth. The Prolog DCG will need to flag these.
UPDATE tm."Patients"
   SET "DateOfBirth_Char" = to_char("DateOfBirth", 'YYYY-MM-DD'),
       "BirthCentury" = CASE
           WHEN EXTRACT(YEAR FROM "DateOfBirth") < 1950 THEN 19
           ELSE NULL
       END;

-- ----------------------------------------------------------------------------
-- Patients_OLD orphan table
-- ----------------------------------------------------------------------------
-- The pre-2003 schema, kept around because audit demanded it in 2006 and
-- nobody has had the courage to drop it since. No FK from Patients —
-- the linkage is "MRN matches if you're lucky."

CREATE TABLE tm."Patients_OLD" (
    "PatientID"   INTEGER,         -- not unique anymore — duplicates from the
                                   -- 2003 Northshore-merger import
    "MRN"         VARCHAR(15),     -- VARCHAR(15) because the old system used 15
    "LastName"    VARCHAR(40),
    "FirstName"   VARCHAR(40),
    "DOB"         VARCHAR(8),      -- YYYYMMDD string, no separator
    "Gender"      CHAR(1),         -- M/F/<space> (only two genders in 1998)
    "Status"      CHAR(1),         -- A/I/D/<space>; D="Deceased" added later
    "MigratedAt"  TIMESTAMP,
    "MigrationNotes" VARCHAR(500)
);

COMMENT ON TABLE tm."Patients_OLD" IS
    'Pre-2003 archive. DO NOT DROP (audit 2006). DO NOT JOIN (PatientIDs do not match Patients). Read-only by convention only — no triggers.';
