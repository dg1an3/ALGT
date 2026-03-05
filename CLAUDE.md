# ALGT + learn-clarion-semantics

Combined repository: formal algorithm verification (ALGT) + Clarion language semantics experiments.

## TODO FROM DEREK
* ~~Separate clarion.pl in to clarion_parser.pl and clarion_interpreter.pl (and separate tests as well)~~ DONE
* ~~Implement an ODBC-based data store, and then get the clarion_interpreter to support this as well~~ DONE — odbc-store/ project with SQL Server LocalDB + OWNER/KEY/DELETE parser support
* ~~Add a project with a GUI form, and then determine how best to simulate that with the interpreter (web interface?)~~ DONE — form-demo/ project + event queue simulation in interpreter
* ~~Document strategy for determining that execution traces match between interpreter and compiled code~~ DONE — see Execution Trace Comparison section below

## Technology Stack

- **Clarion 11.1**: 4GL language, compiles to 32-bit Windows DLLs/EXEs
- **SWI Prolog**: Two Clarion interpreters (prolog-interp/ and clarion_interpreter/)
- **Logtalk**: Object-oriented Prolog extension (ALGT domain models)
- **Python 3.11 (32-bit)**: ctypes interop with Clarion DLLs
- **MSBuild**: Clarion project builds (.cwproj)

## Repository Structure

### Clarion Projects (compiled, tested)
- `hello-world/` — Simple PROGRAM exe
- `python-dll/` — DLL with exported functions callable from Python
- `diagnosis-store/` — DOS flat-file CRUD DLL with Python wrapper
- `sensor-data/` — Sensor readings DLL, primary trace comparison test case
- `stats-calc/` — Statistical calculations DLL
- `form-demo/` — GUI form with WINDOW/ACCEPT event loop
- `form-cli/` — CLI form with EventReader, .evt file format
- `odbc-store/` — ODBC DLL with SQL Server LocalDB
- `clarion_examples/` — Reference .clw files (syntax documentation)

### Clarion Interpreters (Prolog)
- `prolog-interp/` — Original interpreter (2,764 lines, 3 files, simple)
- `clarion_interpreter/` — ALGT interpreter (7,629 lines, 18 files, modular)

### ALGT Verification & Domain Models
- `algt_tests/` — Formal verification of geometric algorithms (beam volume, mesh, margins)
- `domain_models/` — Logtalk domain models (to be reorganized here)
- `model_checker/` — Concurrent operation verification
- `mcp_server/` — MCP server implementations (Prolog, Erlang, Elixir)

### Supporting
- `docs/` — Documentation
- `run_tests.pl` — ALGT test runner

## Execution Trace Comparison

Strategy for verifying the Prolog interpreter produces the same behavior as compiled Clarion DLLs.

### Level 1: Procedure-level traces (implemented)

Both sides emit `CALL ProcName(args) -> result` lines and are compared with `diff`.

**Prolog side** (`prolog-interp/trace_sensorlib.pl`):
- `set_trace(on)` enables the trace infrastructure in `clarion.pl`
- `exec_procedure` emits `proc_enter`/`proc_exit` entries via `assert`
- `print_trace` formats the log; grep `^CALL.*->` for procedure-level lines

**Python side** (`sensor-data/trace_sensorlib.py`):
- `trace_call(lib, name, *args)` wraps each `ctypes` DLL call with logging
- Outputs the same `CALL name(args) -> result` format

**Comparison**:
```bash
diff <(cd sensor-data && python trace_sensorlib.py | grep "^CALL") \
     <(cd prolog-interp && swipl -g "main,halt" trace_sensorlib.pl | grep "^CALL.*->")
```

### Level 2: Statement-level traces (Prolog interpreter only)

The Prolog interpreter traces every statement: `assign`, `call`, `if` (with condition value and branch taken), `loop` enter/exit, `break`, and `return`. Enabled via `set_trace(on)`.

### Level 3: Instrumented Clarion source (future)

Insert `TraceLog('label')` calls at key points in `.clw` source, compare trace point sequences with `diff`.

## Clarion Projects Detail

### hello-world/
Simple Clarion EXE that displays a message box. Uses `PROGRAM` keyword.

### python-dll/
Clarion DLL with exported functions called from Python via `ctypes`.

**Key files:** `MathLib.clw`, `MathLib.cwproj`, `test_mathlib.py`

**Build & test:**
```bash
cd python-dll
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe MathLib.cwproj
cp ../hello-world/bin/ClaRUN.dll bin/
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_mathlib.py
```

**Important:** Clarion 11 produces 32-bit DLLs, so a 32-bit Python is required (`3.11.9-win32`).

### diagnosis-store/
Clarion DLL with DOS flat-file storage for cancer diagnosis records.

**Key files:** `DiagnosisStore.clw`, `diagnosis_store.py`, `test_diagnosis_store.py`

**Key lessons learned:**
- `*CSTRING` params with `C` calling convention pass a hidden `LONG length` before each string pointer on the stack
- File drivers need `<Library>` (not `<FileDriver>`) in `.cwproj`
- Struct passing: `LONG` pointer param + `MemCopy` via `RtlMoveMemory`

### sensor-data/
Clarion DLL with DOS flat-file sensor readings, weighted average calculations, and record cleanup.

**Key files:** `SensorLib.clw`, `test_sensorlib.py`, `trace_sensorlib.py`

### form-demo/
Clarion EXE with a GUI form for sensor data entry. WINDOW/ACCEPT event loop.

**Key files:** `FormDemo.clw`, `FormDemo.cwproj`, `test_formdemo_gui.py`, `compare_traces.py`

### form-cli/
CLI version of FormDemo using EventReader.clw and .evt event files.

**Key files:** `FormDemo_CLI.clw`, `EventReader.clw`, `FormDemo_CLI.cwproj`, `gui-to-cli.md`

### odbc-store/
Clarion DLL with ODBC-based sensor reading storage using SQL Server.

**Key files:** `OdbcStore.clw`, `setup_db.py`, `test_odbcstore.py`

### prolog-interp/
Original SWI-Prolog interpreter for Clarion source code.

**Key files:** `clarion_parser.pl`, `clarion_interpreter.pl`, `clarion.pl`, test suites

**Run tests:**
```bash
cd prolog-interp
swipl -g "main,halt" -t "halt(1)" test_parser.pl
swipl -g "main,halt" -t "halt(1)" test_interpreter.pl
```

## ALGT Components

### Algorithm Verification Tests (`algt_tests/`)
Formal verification of geometric algorithms for medical imaging:
- Beam Volume, Mesh Generation, Isodensity, Structure Projection, Margins, SSD

### Clarion Interpreter (`clarion_interpreter/`)
Modular interpreter: lexer, parser, interpreter core, builtins, state management, control flow, expression evaluation, class support, execution tracer, UI backend, scenario DSL.

### Model Checker (`model_checker/`)
Verifies interleaved concurrent operations to identify race conditions.

### MCP Servers (`mcp_server/`, `mcp_server_erlang/`, `mcp_server_elixir/`)
Model Context Protocol server implementations for Claude Code integration.

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
