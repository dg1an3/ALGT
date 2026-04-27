-- ============================================================================
-- Migration 006 — Era 2007 (ICD-9 → ICD-10 migration that never finished)
-- ============================================================================
--
-- DBA: K. Ramirez
-- Tickets: TM-512, TM-516
--
-- Diagnosis on TreatmentPlans started life as a free-text VARCHAR(200) so
-- the doctors would actually fill it in. Billing has been asking for coded
-- diagnoses since 2005. This is the compromise:
--
--   * The original `Diagnosis` (free text) column stays. The doctors still
--     write into it. They will never stop.
--   * Add `DiagnosisCode_ICD9` for billing. Backfilled by the coders.
--   * In 2015, add `DiagnosisCode_ICD10` because of the federal mandate.
--     TODO: backfill from ICD-9. (This TODO is from 2015. It is now 2026.)
--
-- All three columns will coexist forever and disagree intermittently. The
-- form code reads the free-text and writes both code columns when the user
-- happens to fill them in (rarely). Reports query whichever column the
-- analyst was trained on.
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."TreatmentPlans"
    ADD COLUMN "DiagnosisCode_ICD9"  VARCHAR(10),
    ADD COLUMN "DiagnosisCode_ICD10" VARCHAR(10);

-- Bonus: the coders requested a "Diagnosed By" field in 2007 because the
-- HIPAA log doesn't capture who entered the code. We added "DxCodedBy" but
-- somebody in 2009 added "diagnosis_coded_by" (snake_case, contractor) and
-- now we have two. The application writes to DxCodedBy. Reports query
-- whichever. The contractor's column is in migration 011.
ALTER TABLE tm."TreatmentPlans"
    ADD COLUMN "DxCodedBy" VARCHAR(60),
    ADD COLUMN "DxCodedAt" TIMESTAMP;

COMMENT ON COLUMN tm."TreatmentPlans"."DiagnosisCode_ICD9" IS
    'ICD-9 code. Coexists with free-text Diagnosis. Disagrees ~5% of the time. Backfilled by coding team 2007-2009.';
COMMENT ON COLUMN tm."TreatmentPlans"."DiagnosisCode_ICD10" IS
    'ICD-10 code. TODO 2015: backfill from ICD-9. (This TODO is older than several employees.)';
