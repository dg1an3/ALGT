# ALGT + learn-clarion-semantics

Combined repository: formal algorithm verification (ALGT) + Clarion language semantics experiments.

## TODO FROM DEREK
* ~~Separate clarion.pl in to clarion_parser.pl and clarion_interpreter.pl (and separate tests as well)~~ DONE
* ~~Implement an ODBC-based data store, and then get the clarion_interpreter to support this as well~~ DONE — odbc-store/ project with SQL Server LocalDB + OWNER/KEY/DELETE parser support
* ~~Add a project with a GUI form, and then determine how best to simulate that with the interpreter (web interface?)~~ DONE — form-demo/ project + event queue simulation in interpreter
* ~~Document strategy for determining that execution traces match between interpreter and compiled code~~ DONE — see Execution Trace Comparison section below

## Technology Stack

- **Clarion 11.1**: 4GL language, compiles to 32-bit Windows DLLs/EXEs
- **SWI Prolog**: Unified Clarion simulator (clarion_simulators/unified/)
- **Logtalk**: Object-oriented Prolog extension (ALGT domain models)
- **Python 3.11 (32-bit)**: ctypes interop with Clarion DLLs
- **MSBuild**: Clarion project builds (.cwproj)

## Repository Structure

### Clarion Projects (compiled, tested) — `clarion_projects/`
- `hello-world/` — Simple PROGRAM exe
- `python-dll/` — DLL with exported functions callable from Python
- `diagnosis-store/` — DOS flat-file CRUD DLL with Python wrapper
- `sensor-data/` — Sensor readings DLL, primary trace comparison test case
- `stats-calc/` — Statistical calculations DLL
- `odbc-store/` — ODBC DLL with SQL Server LocalDB
- `clarion_examples/` — Reference .clw files (syntax documentation)

### Clarion GUI Projects — `clarion_projects/`
- `form-demo/` — GUI form with WINDOW/ACCEPT event loop + FormLib DLL for CDB tracing
- `form-cli/` — CLI form with EventReader, .evt file format
- `treatment-offset/` — Treatment offset entry with direction dropdowns, sign-flip, ISqrt magnitude

### Clarion Simulator (Prolog) — `clarion_simulators/`
- `unified/` — Unified simulator combining DCG parser + modular execution engine (130 tests, storage dispatch, scenario DSL, execution tracer with ML exports)

### ALGT Verification & Domain Models
- `algt_tests/` — Formal verification of geometric algorithms (beam volume, mesh, margins)
- `domain_models/` — Logtalk domain models and workflows
  - `imaging_services/` — Image import manager, protocol definitions
  - `subject_image_domain_model/` — Subject image domain
  - `treatment_image_domain_model/` — Treatment image domain
  - `appointment_domain_model/` — Appointment domain
- `model_checker/` — Concurrent operation verification
- `mcp_servers/` — MCP server implementations
  - `prolog/` — Prolog MCP server
  - `erlang/` — Erlang MCP server
  - `elixir/` — Elixir MCP server

### Supporting
- `docs/` — Documentation
- `run_tests.pl` — ALGT test runner

## Execution Trace Comparison

Strategy for verifying the Prolog interpreter produces the same behavior as compiled Clarion DLLs.

### Level 1: Procedure-level traces (implemented)

Both sides emit `CALL ProcName(args) -> result` lines and are compared with `diff`.

**Prolog side** (`clarion_simulators/unified/trace_sensorlib.pl`):
- Uses `init_session`/`call_procedure` from unified `clarion.pl` module
- Outputs `CALL ProcName(args) -> result` format lines

**Python side** (`clarion_projects/sensor-data/trace_sensorlib.py`):
- `trace_call(lib, name, *args)` wraps each `ctypes` DLL call with logging
- Outputs the same `CALL name(args) -> result` format

**Comparison**:
```bash
diff <(cd clarion_projects/sensor-data && python trace_sensorlib.py | grep "^CALL") \
     <(cd clarion_simulators/unified && swipl -g "main,halt" trace_sensorlib.pl | grep "^CALL.*->")
```

### Level 1b: CDB debugger traces (implemented)

Uses the Windows CDB debugger (from Windows SDK Debugging Tools) to set hardware breakpoints on the compiled DLL's exported functions, capturing arguments from the x86 stack and return values from `eax`. This provides ground-truth traces directly from the compiled binary — no Python wrapper instrumentation involved.

**Prerequisites**:
- CDB (x86): `C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\cdb.exe`
- 32-bit Python (host process for loading the DLL via ctypes)

**How it works**:

1. CDB launches 32-bit Python as the debuggee
2. `sxe ld:SensorLib` breaks when the DLL is loaded by ctypes
3. Deferred breakpoints (`bu`) are set on each export symbol (e.g., `SensorLib!SSOpen`)
4. At each breakpoint, CDB reads arguments from the stack (`dd esp+4 L1` for first arg, `esp+8` for second, etc.) — this is the C calling convention where args are pushed right-to-left
5. `gu` (Go Up) executes the function to completion, then CDB reads the return value from `eax`
6. The trace is normalized to `CALL ProcName(args) -> result` and compared with the Prolog interpreter

**Key files** (`clarion_projects/sensor-data/`):
- `cdb_breakpoints.txt` — CDB command script with breakpoint definitions
- `cdb_trace_target.py` — Python script that loads the DLL (debuggee)
- `compare_cdb_prolog.py` — Automated comparison: runs both CDB and Prolog, parses traces, diffs

**Run the comparison**:
```bash
cd clarion_projects/sensor-data
python compare_cdb_prolog.py
```

**Example output**:
```
--- Comparison ---
  OK: CALL SSOpen() -> 0
  OK: CALL SSAddReading(1, 100, 50) -> 0
  OK: CALL SSAddReading(2, 200, 25) -> 0
  OK: CALL SSAddReading(3, 300, 10) -> 0
  OK: CALL SSCalculateWeightedAverage() -> 152
  OK: CALL SSCleanupLowReadings(150) -> 1
  OK: CALL SSCalculateWeightedAverage() -> 228
  OK: CALL SSClose() -> 0

RESULT: All 8 trace entries match!
```

**Adding breakpoints for new procedures**: In `cdb_breakpoints.txt`, add a line:
```
bu SensorLib!NewProc ".echo TRACE_ENTER NewProc; .echo   arg1(name)=; dd esp+4 L1; gu; .echo TRACE_EXIT NewProc eax=; r eax; gc"
```
For each `LONG` argument, read from `esp+4`, `esp+8`, `esp+c`, etc. (4 bytes per arg in C calling convention).

### Level 1c: CDB variable-level comparison (implemented)

Uses headless DLLs (FormLib, OffsetLib) that expose get/set operations on internal variables as named exports. CDB traces each function call with arguments and return values, then compares against a standalone Prolog trace that implements the same logic.

**Pattern**: Extract form logic into a DLL with exports like `Init`, `SetField(id, val)`, `CalcBtn`, `GetVar(id)`. CDB breaks on each export, reads args from the stack, captures return from `eax`.

**Key projects**:
- `clarion_projects/form-demo/` — FormLib with 5 variables (SensorID, Reading, Weight, Result, SensorType)
- `clarion_projects/treatment-offset/` — OffsetLib with 10 variables including direction sign-flip and ISqrt magnitude

**GUI-in-DLL pattern** (`OffsetForm.clw`): The WINDOW/ACCEPT loop runs inside a DLL procedure. Exported button handlers (OFDoCalc, OFDoClear) are called from the ACCEPT loop, so CDB traces each button click live during GUI interaction.

### Level 2: Statement-level traces (Prolog interpreter only)

The Prolog interpreter traces every statement: `assign`, `call`, `if` (with condition value and branch taken), `loop` enter/exit, `break`, and `return`. Enabled via `set_trace(on)`.

### Level 3: Instrumented Clarion source (future)

Insert `TraceLog('label')` calls at key points in `.clw` source, compare trace point sequences with `diff`.

## Clarion Projects Detail

### hello-world/ (`clarion_projects/`)
Simple Clarion EXE that displays a message box. Uses `PROGRAM` keyword.

### python-dll/ (`clarion_projects/`)
Clarion DLL with exported functions called from Python via `ctypes`.

**Key files:** `MathLib.clw`, `MathLib.cwproj`, `test_mathlib.py`

**Build & test:**
```bash
cd clarion_projects/python-dll
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe MathLib.cwproj
cp ../hello-world/bin/ClaRUN.dll bin/
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_mathlib.py
```

**Important:** Clarion 11 produces 32-bit DLLs, so a 32-bit Python is required (`3.11.9-win32`).

### diagnosis-store/ (`clarion_projects/`)
Clarion DLL with DOS flat-file storage for cancer diagnosis records.

**Key files:** `DiagnosisStore.clw`, `diagnosis_store.py`, `test_diagnosis_store.py`

**Key lessons learned:**
- `*CSTRING` params with `C` calling convention pass a hidden `LONG length` before each string pointer on the stack
- File drivers need `<Library>` (not `<FileDriver>`) in `.cwproj`
- Struct passing: `LONG` pointer param + `MemCopy` via `RtlMoveMemory`

### sensor-data/ (`clarion_projects/`)
Clarion DLL with DOS flat-file sensor readings, weighted average calculations, and record cleanup.

**Key files:** `SensorLib.clw`, `test_sensorlib.py`, `trace_sensorlib.py`, `compare_cdb_prolog.py`, `cdb_breakpoints.txt`, `cdb_trace_target.py`

### form-demo/ (`clarion_projects/`)
Clarion EXE with a GUI form for sensor data entry. WINDOW/ACCEPT event loop.
Also includes FormLib DLL for CDB variable-level tracing (Level 1c).

**Key files:** `FormDemo.clw`, `FormDemo.cwproj`, `test_formdemo_gui.py`, `compare_traces.py`
**FormLib files:** `FormLib.clw`, `FormLib.cwproj`, `cdb_breakpoints.txt`, `cdb_trace_target.py`, `compare_cdb_prolog.py`, `trace_formlib.pl`

### form-cli/ (`clarion_projects/`)
CLI version of FormDemo using EventReader.clw and .evt event files.

**Key files:** `FormDemo_CLI.clw`, `EventReader.clw`, `FormDemo_CLI.cwproj`, `gui-to-cli.md`

### treatment-offset/ (`clarion_projects/`)
Treatment offset entry form with anterior/superior/lateral patient shifts, direction dropdowns with sign-flip normalization, and ISqrt magnitude calculation.

**Key files:**
- `TreatmentOffset.clw` — GUI PROGRAM with WINDOW/ACCEPT, direction dropdowns, sign-flip
- `OffsetLib.clw` — Headless DLL for CDB tracing (OLInit, OLSetField, OLCalcBtn, OLClearBtn, OLGetVar)
- `OffsetForm.clw` — GUI form hosted in DLL with exported button handlers (OFRunForm, OFDoCalc, OFDoClear, OFGetVar)
- `trace_offsetlib.pl` — Prolog trace with sign-flip and ISqrt
- `compare_cdb_prolog.py` — Automated CDB vs Prolog comparison
- `run_form_dll.py` — Launch GUI form from DLL (standalone or under CDB)

### odbc-store/ (`clarion_projects/`)
Clarion DLL with ODBC-based sensor reading storage using SQL Server.

**Key files:** `OdbcStore.clw`, `setup_db.py`, `test_odbcstore.py`

### unified/ (`clarion_simulators/`)
Unified SWI-Prolog Clarion simulator. DCG parser + AST bridge + modular execution engine with pluggable storage backends, scenario DSL, and execution tracer with ML exports (PGM, PyMC, Stan, GNN-VAE).

**Key files:** `clarion.pl` (API), `clarion_parser.pl`, `ast_bridge.pl`, `simulator.pl`, `simulator_builtins.pl`, `test_unified.pl`

**Run tests:**
```bash
cd clarion_simulators/unified
swipl -g "main,halt" -t "halt(1)" test_unified.pl
```

## ALGT Components

### Algorithm Verification Tests (`algt_tests/`)
Formal verification of geometric algorithms for medical imaging:
- Beam Volume, Mesh Generation, Isodensity, Structure Projection, Margins, SSD

### Model Checker (`model_checker/`)
Verifies interleaved concurrent operations to identify race conditions.

### MCP Servers (`mcp_servers/`)
Model Context Protocol server implementations for Claude Code integration (Prolog, Erlang, Elixir).

## Clarion DLL Conventions

- Use `MEMBER()` (no args) at top of `.clw` — not `PROGRAM`
- No standalone `CODE` section in MEMBER files — procedures follow directly after `MAP...END`
- Add `EXPORT` attribute to each procedure in the MAP for DLL exports
- Use `C` attribute for C calling convention (ctypes compatible)
- Use `NAME('...')` for clean export names
- Avoid naming procedures `Add` — conflicts with Clarion system intrinsic
- `.clw` files require CRLF line endings
- `ClaRUN.dll` must be alongside the built DLL at runtime

## Build System

- Clarion 11.1 installed at `C:\Clarion11.1\`
- MSBuild targets: `C:\Clarion11.1\bin\SoftVelocity.Build.Clarion.targets`
- Build with: `/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe <project>.cwproj`

## Development Guidelines

### Prolog/Logtalk
- Use descriptive predicate names with underscores
- Use DCG for parsing when appropriate
- Prefix Logtalk protocols with `i` (e.g., `iimage_import_manager`)

### Medical Software (ALGT)
- Correctness is critical for patient safety
- Geometric calculations must be precise
- Always maintain test coverage
- Don't weaken assertions without justification
