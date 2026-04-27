# Treatment Management System

Fat-client / 2-tier client-server treatment management system, written in
FreePascal/Lazarus against PostgreSQL. Architected as if it were designed
in the late 1990s: shared `TDataModule`, data-aware controls, business
logic in form event handlers, no middle tier.

This is the first stage of a three-step modeling exercise:

1. **Lazarus + Postgres** (this project) — the period-correct fat client.
2. **Idiomatic Prolog LTS model** — a DCG over the Postgres WAL event
   stream (the "LDF events" of Postgres, surfaced via logical decoding).
   The grammar *is* the labelled transition system: non-terminals are
   states, productions are transitions, and recognition of a
   `*.wal.jsonl` trace verifies the model accepts the same lifecycle the
   fat client produced. No Logtalk objects — plain Prolog + DCG, in the
   same style as `simulators/clarion/unified/clarion_parser.pl`.
3. **Elixir port** — Commanded + `:eventstore` (Postgres-backed event
   store), reusing the same WAL trace as the seed event log.

## Repository Layout

```
lazarus_projects/treatment-management/
  TreatmentMgmt.lpi              # Lazarus project file
  TreatmentMgmt.lpr              # program entry point
  src/
    uAppConfig.pas               # TIniFile-backed settings
    uDataModule.pas + .lfm       # shared TPQConnection / TSQLTransaction
    forms/
      uMainForm.pas + .lfm       # main menu form
      uPatientForm.pas + .lfm    # patient browse/edit
      uPlanForm.pas + .lfm       # treatment plan browse/edit + Approve
      uAppointmentForm.pas + .lfm# appointment browse/edit + lifecycle
      uSessionForm.pas + .lfm    # session browse/edit + offset magnitude
  config/
    treatment_mgmt.ini.sample    # connection settings template
  db/
    migrations/
      001_initial_schema.sql     # 3NF schema, RowVersion triggers
      002_logical_replication.sql# tm_pub_all publication + REPLICA IDENTITY FULL
    scripts/
      setup_postgres.sh          # one-shot DB + role + migration runner
      capture_wal.py             # streams live WAL events as JSONL
    scenarios/
      01_clinical_workflow.sql   # end-to-end clinical scenario
    traces/
      01_clinical_workflow.wal.jsonl   # pre-recorded WAL fixture (wal2json v2)
```

## Local Postgres Setup

```bash
cd db/scripts
./setup_postgres.sh
```

The script:
1. Sets `wal_level = logical`, `max_wal_senders`, `max_replication_slots`
   in `postgresql.conf` and restarts the service (requires sudo).
2. Creates a `tm_app` role with `LOGIN REPLICATION` and a
   `treatment_mgmt` database.
3. Runs migrations in `db/migrations/` in order.

## Lazarus Build

Open `TreatmentMgmt.lpi` in Lazarus 2.2+ and build (F9). The required
package is `SQLDBLaz`, which ships with Lazarus.

Before first run, copy the INI sample:

```bash
cp config/treatment_mgmt.ini.sample treatment_mgmt.ini
# edit credentials if not using the defaults from setup_postgres.sh
```

The app searches for `treatment_mgmt.ini` in:
1. EXE directory
2. `%APPDATA%\TreatmentMgmt\` (Windows) or `~/.treatment_mgmt.ini` (Unix)

## Schema

Four core entities under the `tm` schema:

| Table              | Purpose                                          |
|--------------------|--------------------------------------------------|
| Patients           | Patient demographics, MRN, contact info          |
| TreatmentPlans     | Prescription, dose, fractions, approval state    |
| Appointments       | Scheduled visits (consult / sim / treatment)     |
| TreatmentSessions  | Per-fraction delivery, offsets, magnitude        |

The schema in `001_initial_schema.sql` is the *original* 1996 design,
including IMPAC/Mosaiq-style **SET_ID versioning** on `TreatmentPlans`
(see below). Migrations 003–011 layer on roughly 25 years of feature
creep, performance hacks, regulatory flotsam, and contractor remnants
— see **Schema Stratigraphy** below.

### SET_ID versioning (TreatmentPlans)

Modeled on the IMPAC/Mosaiq pattern used in oncology information
systems since the late 1990s. Every row in `TreatmentPlans` carries:

| Column        | Role                                                       |
|---------------|------------------------------------------------------------|
| `PlanID`      | Physical row PK; allocated from `tm.plan_obj_seq`          |
| `PlanSetID`   | Logical plan identity, shared across versions; for v1 it equals PlanID |
| `PlanVersion` | 1, 2, 3, … within the set                                  |
| `EffectiveAt` | When this version became effective                         |
| `EndedAt`     | When superseded; `NULL` for the current version            |
| `IsCurrent`   | Boolean; partial unique index ensures one current per set  |

A new plan is just an INSERT — the `TR_Plans_DefaultSetID` trigger sets
`PlanSetID := PlanID` for v1. To amend a plan (re-prescription, dose
change, replan after offset, etc.) call:

```sql
SELECT tm.amend_plan(<plan_id>, <user>);
```

This atomically:
1. Closes the current row (`IsCurrent := FALSE`, `EndedAt := NOW()`,
   `PlanStatus := 'Superseded'`)
2. Inserts a new row with the same `PlanSetID`, `PlanVersion + 1`,
   clinical fields copied from the previous version, `PlanStatus :=
   'Draft'`, `ApprovedBy / ApprovedAt` cleared so it must be
   re-approved before delivery.

The Pascal `uPlanForm` exposes this as the **[Amend / New Version]**
button. Browse queries default to the `vw_TreatmentPlans_Current` view
(or `WHERE "IsCurrent" = TRUE`); the full version history is reachable
by querying `tm."TreatmentPlans"` directly.

`Appointments.PlanID` and `TreatmentSessions.PlanID` reference the
specific *version* a dependent row was created against, not the set.
This is the audit-correct behavior: an appointment scheduled against
v1 of a plan stays linked to v1 even after the plan is amended to v2.
Reports that want "all appointments for plan set X regardless of
version" must join via `PlanSetID`.

The dead `OldPlanID` column added in 2011 (see migration 011) is a
*second*, redundant attempt at versioning by a contractor who didn't
realize the SET_ID system already existed. ~12% of rows have stale
`OldPlanID` values from the two months it was in production; reports
that filter `WHERE OldPlanID IS NULL` silently exclude that slice.

### Schema Stratigraphy

The `db/migrations/` directory is structured as archaeological layers.
Each migration is dated in its header and adds the warts that accrued
in that era:

| Layer | File                                       | Theme                                                        |
|-------|--------------------------------------------|--------------------------------------------------------------|
| 1996  | `001_initial_schema.sql`                   | Clean 3NF + IMPAC/Mosaiq-style SET_ID versioning on TreatmentPlans (PlanSetID/PlanVersion/IsCurrent + amend_plan() helper) |
| 1997  | `002_logical_replication.sql`              | (modern hindsight: `wal_level=logical` + publication)        |
| 2001  | `003_era_2001_just_add_columns.sql`        | `IsActive` shadow flag, marital status, 3× insurance, pipe-delimited spouse info |
| 2003  | `004_era_2003_y2k_aftershock.sql`          | `DateOfBirth_Char` shadow column for Cognos; `Patients_OLD` orphan |
| 2005  | `005_era_2005_hipaa_creep.sql`             | `Notes2`, `AccessLog VARCHAR(4000)` truncating audit, three `ConsentFormN` flags, `Patient_Photos_DEPRECATED` orphan |
| 2007  | `006_era_2007_icd_migration.sql`           | `DiagnosisCode_ICD9` and `DiagnosisCode_ICD10` alongside the original free-text `Diagnosis` |
| 2008  | `007_era_2008_perf_denorm.sql`             | Snapshot columns (`PatientNameSnap`, `PlanCodeSnap`, `OffsetCSV`) populated by **INSERT-only** triggers — drift on every parent rename |
| 2010  | `008_era_2010_vendor_integration.sql`      | `ExternalSchedulingID` (3 incompatible formats), `LinacRawXML`, `Z_Backup_Sessions_2009` orphan |
| 2013  | `009_era_2013_multi_site.sql`              | `SiteCode` on every table; `NULL` and `'MAIN'` mean the same thing; rogue `'NW'` site code |
| 2015  | `010_era_2015_status_flag_accretion.sql`   | Five parallel boolean/CHAR/SMALLINT flags on `Appointments` whose sync trigger was disabled in 2017 (TM-4471) |
|  —    | `011_era_misc_warts.sql`                   | Catch-all: snake_case `entry_user`/`last_modified` shadows, redundant `OldPlanID` (2011 contractor's parallel re-implementation of versioning that already existed), Lim's 2018 abandoned rename (`who_created`/`who_updated`) |

### Known Drift Patterns

The denormalization is deliberate. The following pairs of columns are
*supposed to agree* but predictably don't, and the planned Prolog DCG /
LTS model uses them as the test surface for inconsistency detection:

| Pair                                                     | Drift cause                                                            |
|----------------------------------------------------------|------------------------------------------------------------------------|
| `Patients.Active` ↔ `Patients.IsActive`                  | Two flag columns from 1996 and 2001; GUI / reports write different ones |
| `Patients.DateOfBirth` ↔ `Patients.DateOfBirth_Char`     | Shadow column populated only on INSERT (2003 trigger)                  |
| `Patients.LastName` ↔ `Appointments.PatientNameSnap`     | INSERT-only trigger; rename does not propagate                         |
| `TreatmentPlans.PlanCode` ↔ `*.PlanCodeSnap`             | Same                                                                   |
| `TreatmentSessions.Offset*` ↔ `OffsetCSV`                | Direct SQL `UPDATE` to offsets leaves CSV stale                        |
| `Appointments.Status` ↔ `IsCancelled / WorkflowState / ReadyForBilling` | Sync trigger disabled October 2017 (TM-4471)            |
| `*.UpdatedBy` ↔ `*.who_updated` ↔ `*.entry_user`         | Three audit conventions from three contractors                         |
| `Patients.SiteCode IS NULL` ↔ `'MAIN'`                   | Convention only; reports lump them, code paths sometimes don't         |

### Orphan Tables

Three intentionally empty tables that nobody can drop:

| Table                            | Era  | Why it persists                                          |
|----------------------------------|------|----------------------------------------------------------|
| `Patients_OLD`                   | 2003 | Pre-migration archive; audit demanded retention in 2006   |
| `Patient_Photos_DEPRECATED`      | 2002 | Two Crystal Reports `LEFT JOIN` it                        |
| `Z_Backup_Sessions_2009`         | 2009 | December 2009 disaster snapshot; `Z_` prefix sorts last  |

The `tm_pub_all` publication intentionally **does not include** these
tables — they are read-only ghosts and produce no WAL events.

## WAL Event Capture (for the Prolog port)

PostgreSQL's logical replication is the equivalent of SQL Server's LDF
transaction-log events. With `wal_level=logical` and the `tm_pub_all`
publication, every committed change flows out as a structured event.

### Format

`wal2json` format-version 2: one JSON object per line, with `action`
field B (begin), I (insert), U (update), D (delete), C (commit).

Example INSERT:

```json
{"action":"I","schema":"tm","table":"Patients",
 "columns":[{"name":"PatientID","type":"integer","value":1},
            {"name":"MRN","type":"character varying(20)","value":"MRN0001"},
            ...]}
```

UPDATE events also carry an `identity` array with the old key + changed
columns (because we set `REPLICA IDENTITY FULL` in migration 002).

### Live capture

```bash
# Terminal 1: subscribe
python3 db/scripts/capture_wal.py > my_run.wal.jsonl

# Terminal 2: drive the DB
psql -h localhost -U tm_app -d treatment_mgmt -f db/scenarios/01_clinical_workflow.sql

# Ctrl-C terminal 1; my_run.wal.jsonl now holds the full trace.
```

### Offline fixtures

Two pre-recorded WAL traces live in `db/traces/`:

#### `01_clinical_workflow.wal.jsonl` — pre-rot, clean schema

A reference trace of the full clinical workflow against the **original
1996 schema** (migrations 001–002 only). 31 events across 9 transactions
(8 inserts, 5 updates). Use this for verifying the Prolog model against
clean inputs.

#### `02_workflow_postdenorm.wal.jsonl` — post-rot, drift-focused

A trace recorded after migrations 003–011 have been applied. 24 events
across 8 transactions (3 inserts, 5 updates), each annotated with a
non-standard `drift_note` field describing which inconsistency the event
demonstrates:

| Txn  | Drift demonstrated                                                  |
|------|---------------------------------------------------------------------|
| 1020 | New patient with all post-2001 columns populated (no drift; baseline) |
| 1021 | Patient rename → snapshot columns on dependent rows go stale        |
| 1022 | Insert appointment → snapshot populated by trigger (matches at this moment) |
| 1023 | Insert session → snapshot captures already-stale parent name        |
| 1024 | Direct SQL update to offset columns → `OffsetCSV` does not refresh  |
| 1025 | Plan rename → all `PlanCodeSnap` references go stale                |
| 1026 | Status → Cancelled, but `IsCancelled` / `WorkflowState` stay (TM-4471) |
| 1027 | `who_updated` set without touching `UpdatedBy` (Lim-era audit drift) |

The `drift_note` field is a fixture-only annotation, not part of
wal2json. Real captures from `capture_wal.py` will not include it; the
Prolog DCG should detect drift directly from the column values.

## Lifecycle Transitions (DCG-relevant)

The forms surface explicit lifecycle buttons that the future Prolog DCG
will mirror as productions over WAL events:

| Entity              | Transitions                                                   |
|---------------------|---------------------------------------------------------------|
| TreatmentPlan       | Draft → UnderReview → Approved → Active → Completed           |
|                     | * → Cancelled                                                  |
| Appointment         | Scheduled → CheckedIn → InProgress → Completed                |
|                     | Scheduled → Cancelled / NoShow                                 |
| TreatmentSession    | Pending → InProgress → Completed                              |
|                     | * → Aborted                                                    |

Form code rejects illegal transitions client-side; the Postgres `CHECK`
constraints enforce the value space. Together they constrain the WAL
event stream the DCG will accept.

## Clarion-style ACCEPT Loop

`src/uClarionLoop.pas` provides a `TAcceptLoop` class that translates
Clarion's `ACCEPT … END` idiom into Lazarus. Each form owns a loop;
button `OnClick` handlers each call `Loop.Post(EV_ACCEPTED, FLD_xxx)`,
and a single `HandleEvent` method does the equivalent of Clarion's
central `CASE EVENT() OF / CASE FIELD() OF` dispatcher.

`Maintain → Tools → ACCEPT loop demo…` opens `uAcceptDemoForm`, a
self-contained reference implementation. Every event the loop sees is
written to `<temp>/accept_demo.evt` in a format compatible with
`clarion_projects/form-cli/*.evt` so the planned Prolog DCG can replay
either source uniformly.

Event constants in `uClarionLoop`:

| Pascal             | Clarion equivalent       |
|--------------------|--------------------------|
| `EV_OPEN_WINDOW`   | `EVENT:OpenWindow`       |
| `EV_CLOSE_WINDOW`  | `EVENT:CloseWindow`      |
| `EV_ACCEPTED`      | `EVENT:Accepted`         |
| `EV_REJECTED`      | `EVENT:Rejected`         |
| `EV_SELECTED`      | `EVENT:Selected`         |
| `EV_NEW_SELECTION` | `EVENT:NewSelection`     |
| `EV_TIMER`         | `EVENT:Timer`            |
| `EV_USER + N`      | `EVENT:User + N`         |

Methods on `TAcceptLoop` matching Clarion verbs:

| Pascal       | Clarion          | Effect                                    |
|--------------|------------------|-------------------------------------------|
| `Post(K,F)`  | `POST(EVENT,FLD)`| push event onto the queue                 |
| `Break_`     | `BREAK`          | exit the ACCEPT loop                      |
| `Cycle`      | `CYCLE`          | skip remaining handlers, continue loop    |
| `Run`        | `ACCEPT`         | block, pumping LCL messages, until `Break_` |

The main loop body is a thin wrapper around `Application.ProcessMessages`
so all standard Lazarus widget input still works — TAcceptLoop just
adds the Clarion-style queue semantics on top.

## Modeling Roadmap

| Stage | Status | Trace Boundary             |
|-------|--------|----------------------------|
| Lazarus fat client (M1: scaffold) | done | n/a (the source of truth) |
| Lazarus fat client (M2: all four forms + lifecycle) | done | n/a |
| Schema rot (M2.5: 25 years of feature creep simulated) | done | `02_workflow_postdenorm.wal.jsonl` |
| Mosaiq-style SET_ID versioning on TreatmentPlans | done | xid 1010 in `01_clinical_workflow.wal.jsonl` |
| Prolog DCG / LTS model | planned | consume `*.wal.jsonl`; detect drift |
| Elixir port (Commanded + :eventstore) | planned | replay WAL → derive aggregates |

The same WAL trace fixture verifies all three implementations agree on
state evolution — analogous to the CDB-vs-Prolog comparison used for the
Clarion DLLs in this repo.
