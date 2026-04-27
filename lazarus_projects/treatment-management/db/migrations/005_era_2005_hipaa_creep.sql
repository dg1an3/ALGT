-- ============================================================================
-- Migration 005 — Era 2005 (HIPAA creep)
-- ============================================================================
--
-- DBA: K. Ramirez (Hollister left in 2004)
-- Tickets: TM-318, TM-319, TM-320, TM-321
--
-- HIPAA Privacy Rule compliance audit (March 2005) generated a list of 47
-- findings. This migration addresses the database-side ones. The form-side
-- findings became `ConsentForm1Signed`, `ConsentForm2Signed`, …
--
-- A note on Notes vs Notes2:
--   The original Notes field is VARCHAR(2000). The HIPAA disclosure log
--   takes a row's worth on its own, so we added Notes2 as TEXT. The plan
--   was to migrate Notes to TEXT in the next release. The plan is still
--   the plan as of the 2005 release of this comment.
--
-- A note on AccessLog:
--   This is a 4000-byte VARCHAR holding concatenated entries of the form
--     "username:YYYY-MM-DD;"
--   When it's full, the application truncates from the front. We are aware
--   that this is not how an audit log works. Compliance signed off because
--   "the disk audit captures everything anyway."
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Patients"
    ADD COLUMN "Notes2"              TEXT,
    ADD COLUMN "AccessLog"           VARCHAR(4000),
    ADD COLUMN "ConsentForm1Signed"  BOOLEAN DEFAULT FALSE,
    ADD COLUMN "ConsentForm2Signed"  BOOLEAN DEFAULT FALSE,
    ADD COLUMN "ConsentForm3Signed"  BOOLEAN DEFAULT FALSE,
    ADD COLUMN "ConsentForm1SignedAt" TIMESTAMP,
    ADD COLUMN "ConsentForm2SignedAt" TIMESTAMP,
    ADD COLUMN "ConsentForm3SignedAt" TIMESTAMP;

COMMENT ON COLUMN tm."Patients"."Notes2" IS
    'HIPAA disclosure log. Original Notes column also still in use for general comments. Migration plan from 2005 still pending.';
COMMENT ON COLUMN tm."Patients"."AccessLog" IS
    'Concatenated "user:YYYY-MM-DD;" log entries. Truncates from the front when full (~120 entries). Compliance signed off (Ramirez, 2005).';
COMMENT ON COLUMN tm."Patients"."ConsentForm1Signed" IS
    'Consent form rev 1 (2005). Superseded by form 2 (2009) and form 3 (2014). All three columns retained for audit.';

-- ----------------------------------------------------------------------------
-- Patient_Photos_DEPRECATED orphan table
-- ----------------------------------------------------------------------------
-- A 2002 attempt to embed JPEG photos in the database. Killed by the storage
-- group when it reached 8 GB. Replaced by a network share, but the table is
-- still here because two reports JOIN it via LEFT OUTER and would crash if
-- it disappeared. The reports have not been touched since 2003.

CREATE TABLE tm."Patient_Photos_DEPRECATED" (
    "PatientID"   INTEGER,
    "PhotoBlob"   BYTEA,        -- always NULL since 2003
    "PhotoPath"   VARCHAR(255), -- usually NULL too
    "TakenAt"     TIMESTAMP,
    "TakenBy"     VARCHAR(60)
);

COMMENT ON TABLE tm."Patient_Photos_DEPRECATED" IS
    'Empty since 2003. Two Crystal Reports LEFT JOIN it. Cannot be dropped without breaking those reports. (Ramirez, 2005)';
