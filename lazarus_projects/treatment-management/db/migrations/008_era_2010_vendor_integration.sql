-- ============================================================================
-- Migration 008 — Era 2010 (vendor integration)
-- ============================================================================
--
-- DBA: K. Ramirez
-- Tickets: TM-784 (SchedSync), TM-791 (LINAC R&V export)
--
-- Two unrelated integrations landed in the same release because the contract
-- said "by Q3."
--
--   1. SchedSync™ — a third-party scheduling tool that holds its own copy
--      of every appointment. Their support of an external ID has gone
--      through three formats:
--           v1: "1234"
--           v2: "v2|1234|main"
--           v3: a UUID
--      All three are still in production data. Don't normalize on parse.
--
--   2. The LINAC vendor's record-and-verify system can dump a per-fraction
--      XML blob. The schema is undocumented. We store it verbatim. Average
--      blob is ~20 KB. The fast-client GUI does not display this column;
--      it's purely for the regulatory print-out batch job.
--
-- Z_Backup_Sessions_2009 came from the catastrophic schema migration in
-- December 2009. We recovered. Most of us. The table stays in case we
-- need to reconstruct anything from those three weeks of corrupted data.
-- ============================================================================

SET search_path TO tm, public;

ALTER TABLE tm."Appointments"
    ADD COLUMN "ExternalSchedulingID" VARCHAR(60);

ALTER TABLE tm."TreatmentSessions"
    ADD COLUMN "LinacRawXML" TEXT;

COMMENT ON COLUMN tm."Appointments"."ExternalSchedulingID" IS
    'SchedSync external ref. Three known formats: bare integer, pipe-delimited v2, UUID v3. All in production.';
COMMENT ON COLUMN tm."TreatmentSessions"."LinacRawXML" IS
    'Vendor R&V XML dump. Undocumented schema. ~20 KB average. Not displayed in GUI. Read by RegulatoryReportBatch.exe nightly.';

-- ----------------------------------------------------------------------------
-- Z_Backup_Sessions_2009 orphan table
-- ----------------------------------------------------------------------------
CREATE TABLE tm."Z_Backup_Sessions_2009" (
    "SessionID"      INTEGER,
    "AppointmentID"  INTEGER,
    "PlanID"         INTEGER,
    "FractionNumber" INTEGER,
    "DeliveredDose"  NUMERIC(8,2),
    "OffsetCSV"      VARCHAR(60),
    "BackedUpAt"     TIMESTAMP,
    "BackupNotes"    VARCHAR(500),
    "RawDump"        TEXT
);

COMMENT ON TABLE tm."Z_Backup_Sessions_2009" IS
    'Disaster recovery snapshot from December 2009 incident. DO NOT TRUNCATE. The Z_ prefix sorts it to the bottom of the schema browser. (Ramirez, 2010)';
