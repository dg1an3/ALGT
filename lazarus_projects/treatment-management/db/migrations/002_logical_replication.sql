-- Logical Replication Publication for the future Prolog WAL consumer.
--
-- Note: this requires postgresql.conf to have `wal_level = logical`.
-- See db/scripts/setup_postgres.sh for the server-side setup.
--
-- The Prolog port will subscribe by creating a replication slot and
-- streaming changes via wal2json or pgoutput. Each emitted event has the
-- shape:
--   { op: 'I'|'U'|'D', table: 'Patients' | ..., old: <tuple>, new: <tuple>,
--     txid: <int>, lsn: <text>, ts: <timestamp> }
-- which the LTS / Logtalk model consumes as the "ground truth" trace.

BEGIN;

-- Drop and recreate so this migration is idempotent during dev.
DROP PUBLICATION IF EXISTS tm_pub_all;

CREATE PUBLICATION tm_pub_all FOR TABLE
    tm."Patients",
    tm."TreatmentPlans",
    tm."Appointments",
    tm."TreatmentSessions"
WITH (publish = 'insert,update,delete');

-- REPLICA IDENTITY FULL so DELETE/UPDATE events include the full old tuple
-- (essential for the Prolog model to reconstruct prior state).
ALTER TABLE tm."Patients"          REPLICA IDENTITY FULL;
ALTER TABLE tm."TreatmentPlans"    REPLICA IDENTITY FULL;
ALTER TABLE tm."Appointments"      REPLICA IDENTITY FULL;
ALTER TABLE tm."TreatmentSessions" REPLICA IDENTITY FULL;

COMMIT;
