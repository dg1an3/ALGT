#!/usr/bin/env python3
"""Capture WAL events from the treatment_mgmt database into wal2json JSONL.

Connects via psycopg2's logical replication API, creates (or reuses) a
replication slot using the wal2json output plugin, and streams change
records to stdout — one JSON object per line — in the same format as the
db/traces/*.wal.jsonl fixtures.

Usage:
    # Start streaming (Ctrl-C to stop):
    python3 capture_wal.py > my_run.wal.jsonl

    # Replay db/scenarios/01_clinical_workflow.sql in another shell, then
    # the events appear here in real time.

Prerequisites:
    * postgresql.conf has wal_level = logical
    * wal2json output plugin is installed (apt: postgresql-NN-wal2json)
    * The role in treatment_mgmt.ini has REPLICATION privilege

If wal2json is unavailable, set OUTPUT_PLUGIN=pgoutput below — the format
will differ (binary protocol; you'd need a decoder).
"""

import configparser
import json
import os
import signal
import sys
from pathlib import Path

try:
    import psycopg2
    from psycopg2.extras import LogicalReplicationConnection, ReplicationCursor
except ImportError:
    sys.stderr.write("psycopg2 is required: pip install psycopg2-binary\n")
    sys.exit(1)

SLOT_NAME      = os.environ.get("TM_SLOT", "tm_capture_slot")
OUTPUT_PLUGIN  = os.environ.get("TM_PLUGIN", "wal2json")
INI_DEFAULT    = Path(__file__).resolve().parents[2] / "config" / "treatment_mgmt.ini"


def load_dsn() -> str:
    ini_path = Path(os.environ.get("TM_INI", INI_DEFAULT))
    if not ini_path.exists():
        sys.stderr.write(f"INI not found: {ini_path}\n")
        sys.exit(1)
    cp = configparser.ConfigParser()
    cp.read(ini_path)
    db = cp["Database"]
    return (
        f"host={db['Host']} port={db['Port']} dbname={db['Database']} "
        f"user={db['User']} password={db['Password']}"
    )


def main() -> int:
    conn = psycopg2.connect(load_dsn(), connection_factory=LogicalReplicationConnection)
    cur: ReplicationCursor = conn.cursor()

    try:
        cur.create_replication_slot(SLOT_NAME, output_plugin=OUTPUT_PLUGIN)
        sys.stderr.write(f"Created replication slot {SLOT_NAME}\n")
    except psycopg2.errors.DuplicateObject:
        sys.stderr.write(f"Reusing replication slot {SLOT_NAME}\n")
        conn.rollback()

    options = {"format-version": "2", "include-types": "true",
               "include-lsn": "true", "include-timestamp": "true"}
    cur.start_replication(slot_name=SLOT_NAME, decode=True, options=options)

    def on_sigint(_sig, _frame):
        sys.stderr.write("\nStopping capture.\n")
        sys.exit(0)
    signal.signal(signal.SIGINT, on_sigint)

    def consume(msg):
        # wal2json v2 emits one JSON object per message already.
        sys.stdout.write(msg.payload)
        if not msg.payload.endswith("\n"):
            sys.stdout.write("\n")
        sys.stdout.flush()
        msg.cursor.send_feedback(flush_lsn=msg.data_start)

    cur.consume_stream(consume)
    return 0


if __name__ == "__main__":
    sys.exit(main())
