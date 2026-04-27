-- ============================================================================
-- Migration 009 — Era 2013 (multi-site rollout)
-- ============================================================================
--
-- DBA: K. Ramirez (last migration before retirement)
-- Tickets: TM-902, TM-905, TM-908, TM-911
--
-- The west valley clinic (WV) and downtown satellite (DT) come online in
-- Q3 2013. The application doesn't really know about sites, but reports
-- need to filter by location. Solution: SiteCode VARCHAR(8) on every core
-- table. NULL means "main campus" because nobody wanted to backfill 12
-- years of data.
--
-- Acceptable values are 'MAIN', 'WV', 'DT' but the constraint was never
-- written. NULL and 'MAIN' both occur in the wild and are not distinguished
-- by any consumer. The reporting team agreed to treat NULL as 'MAIN' and
-- moved on.
--
-- (2017 footnote: a contractor added 'NW' for a Northwoods clinic that
-- never opened. There are 17 rows with SiteCode='NW'. They are real
-- patients. Don't delete.)
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Patients"          ADD COLUMN "SiteCode" VARCHAR(8);
ALTER TABLE tm."TreatmentPlans"    ADD COLUMN "SiteCode" VARCHAR(8);
ALTER TABLE tm."Appointments"      ADD COLUMN "SiteCode" VARCHAR(8);
ALTER TABLE tm."TreatmentSessions" ADD COLUMN "SiteCode" VARCHAR(8);

-- The intended check constraint, never actually written:
--    CHECK ("SiteCode" IN ('MAIN','WV','DT') OR "SiteCode" IS NULL)
-- Don't add it now. There are 17 rows with 'NW'. (See header.)

COMMENT ON COLUMN tm."Patients"."SiteCode" IS
    'Multi-site flag. NULL == MAIN by convention. Acceptable: MAIN/WV/DT/NW. No constraint. (Ramirez, 2013)';
