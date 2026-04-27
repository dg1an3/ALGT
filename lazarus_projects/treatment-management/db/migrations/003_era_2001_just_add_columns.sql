-- ============================================================================
-- Migration 003 — Era 2001 ("just add a column")
-- ============================================================================
--
-- DBA: M. Hollister  (left 2004)
-- Ticket: TM-117 — "PMs need marital status / spouse / second insurance"
-- Original deadline:  Tuesday
-- Actual ship date:   six weeks later
--
-- This was the migration that taught us what "schema review" meant. Originally
-- one column was requested. By the time billing got involved we ended up with
-- three insurance carriers because Mrs. Carney had three.
--
-- Notes for whoever inherits this:
--   * IsActive CHAR(1) duplicates the original Active BOOLEAN. Reports query
--     IsActive, the GUI writes Active. They mostly agree. 'X' means
--     "moved out of state, do not contact" — added on a sticky note by
--     Dr. P. and never documented anywhere else.
--   * SpouseInfo is pipe-delimited "name|dob|phone". Don't ask.
--   * Insurance fields are denormalized to 3 sets. We *will* fix this
--     properly in v3 of the system. (Last touched 2001.)
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Patients"
    ADD COLUMN "IsActive"          CHAR(1)      DEFAULT 'Y',
    ADD COLUMN "MaritalStatus"     VARCHAR(2),
    ADD COLUMN "SpouseInfo"        VARCHAR(200),
    ADD COLUMN "InsuranceCarrier"  VARCHAR(40),
    ADD COLUMN "PolicyNumber"      VARCHAR(40),
    ADD COLUMN "GroupNumber"       VARCHAR(40),
    ADD COLUMN "InsuranceCarrier2" VARCHAR(40),
    ADD COLUMN "PolicyNumber2"     VARCHAR(40),
    ADD COLUMN "GroupNumber2"      VARCHAR(40),
    ADD COLUMN "InsuranceCarrier3" VARCHAR(40),
    ADD COLUMN "PolicyNumber3"     VARCHAR(40),
    ADD COLUMN "GroupNumber3"      VARCHAR(40);

-- Backfill IsActive from the canonical Active flag. Future updates from the
-- GUI hit Active only; reports query IsActive. Drift starts here.
UPDATE tm."Patients"
   SET "IsActive" = CASE WHEN "Active" THEN 'Y' ELSE 'N' END;

-- Constraint added later, in 2002, after billing crashed on a NULL.
ALTER TABLE tm."Patients"
    ADD CONSTRAINT "CK_Patients_IsActive"
        CHECK ("IsActive" IN ('Y','N','X') OR "IsActive" IS NULL);

-- Marital status codes per the 2001 Crystal Reports lookup table.
-- (S=Single, M=Married, D=Divorced, W=Widowed, P=Partner, U=Unknown)
-- No FK because the lookup table lives in the reporting database.

COMMENT ON COLUMN tm."Patients"."IsActive" IS
    'Y/N/X. X=do-not-contact (added by Dr. P 2002). Drifts from Active.';
COMMENT ON COLUMN tm."Patients"."SpouseInfo" IS
    'Pipe-delimited: name|dob|phone. Migration target for normalization (TODO 2003).';
COMMENT ON COLUMN tm."Patients"."InsuranceCarrier3" IS
    'Third insurance. Mrs. Carney has three. Yes really. (Hollister, 2001)';
