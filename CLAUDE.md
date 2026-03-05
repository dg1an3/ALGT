# learn-clarion-semantics

Experiments learning Clarion language semantics: building, DLL exports, and Python interop.

## TODO FROM DEREK
* ~~Separate clarion.pl in to clarion_parser.pl and clarion_interpreter.pl (and separate tests as well)~~ DONE
* ~~Implement an ODBC-based data store, and then get the clarion_interpreter to support this as well~~ DONE — odbc-store/ project with SQL Server LocalDB + OWNER/KEY/DELETE parser support
* ~~Add a project with a GUI form, and then determine how best to simulate that with the interpreter (web interface?)~~ DONE — form-demo/ project + event queue simulation in interpreter
* ~~Document strategy for determining that execution traces match between interpreter and compiled code~~ DONE — see Execution Trace Comparison section below

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

This level is not available from the compiled DLL without source instrumentation.

### Level 3: Instrumented Clarion source (future)

To get statement-level traces from the compiled DLL:
1. Add a `TraceLog(LONG bufPtr)` export to a shared logging DLL
2. Insert `TraceLog('SSAddReading:after_clear')` calls at key points in the `.clw` source
3. Both sides (Prolog interpreter + instrumented DLL) emit the same trace point IDs
4. Compare the trace point sequences with `diff`

This requires recompiling the Clarion DLL with the instrumentation, so it's best used for targeted debugging rather than continuous CI.

## Projects

### hello-world/
Simple Clarion EXE that displays a message box. Uses `PROGRAM` keyword.

### python-dll/
Clarion DLL with exported functions called from Python via `ctypes`.

**Key files:**
- `MathLib.clw` — Clarion source with `MathAdd` and `Multiply` procedures
- `MathLib.cwproj` — MSBuild project (`OutputType=Library`, `Model=Dll`)
- `MathLib.exp` — Export definitions
- `MathLib.sln` — Solution file
- `test_mathlib.py` — Python test script using `ctypes.CDLL`

**Build & test:**
```bash
cd python-dll
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe MathLib.cwproj
cp ../hello-world/bin/ClaRUN.dll bin/   # Clarion runtime dependency
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_mathlib.py
```

**Important:** Clarion 11 produces 32-bit DLLs, so a 32-bit Python is required (`3.11.9-win32`).

### diagnosis-store/
Clarion DLL with DOS flat-file storage for cancer diagnosis records, called from Python via a wrapper module.

**Key files:**
- `DiagnosisStore.clw` — Clarion DLL source with 8 exported CRUD + approval functions
- `DiagnosisStore.cwproj` — MSBuild project (links `ClaDOS.lib` for the DOS file driver)
- `diagnosis_store.py` — Python wrapper: `DiagnosisStore` context manager, `Diagnosis` dataclass, Clarion date conversion
- `test_diagnosis_store.py` — 8 tests covering create/read/update/approve/delete/list/persistence

**Build & test:**
```bash
cd diagnosis-store
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe DiagnosisStore.cwproj
cp ../hello-world/bin/ClaRUN.dll bin/   # Clarion runtime
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_diagnosis_store.py
```

**Architecture:** Python → `ctypes.CDLL` → `DiagnosisStore.dll` → `Diagnosis.dat` (flat file)

**Key lessons learned:**
- `*CSTRING` params with `C` calling convention pass a hidden `LONG length` before each string pointer on the stack. From Python, pass `(bufsize, c_char_p)` per `*CSTRING` param to match. See `_cstr_args()` helper in `diagnosis_store.py`.
- File drivers need `<Library>` (not `<FileDriver>`) in `.cwproj`. Runtime driver DLL (e.g. `ClaDOS.dll`) must be in `bin/`.
- Struct passing: `LONG` pointer param + `MemCopy` via `RtlMoveMemory`, with `ADDRESS()` and `SIZE()`. Python side uses `_pack_ = 1` to match Clarion's default GROUP packing.

### sensor-data/
Clarion DLL with DOS flat-file sensor readings, weighted average calculations, and record cleanup. Used as the primary test case for execution trace comparison between the Prolog interpreter and compiled Clarion.

**Key files:**
- `SensorLib.clw` — Clarion DLL: SSOpen, SSClose, SSAddReading, SSGetReading, SSCalculateWeightedAverage, SSCleanupLowReadings
- `SensorLib.cwproj` — MSBuild project (links `ClaDOS.lib`)
- `test_sensorlib.py` — Python test (all assertions pass)
- `trace_sensorlib.py` — Procedure-level trace output for diff comparison

**Build & test:**
```bash
cd sensor-data
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe SensorLib.cwproj
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_sensorlib.py
```

**Architecture:** Python → `ctypes.CDLL` → `SensorLib.dll` → `Sensors.dat` (DOS flat file)

### form-demo/
Clarion EXE with a GUI form for sensor data entry. Uses `PROGRAM` (not `MEMBER`), WINDOW declaration with controls, and ACCEPT event loop. Used as the test case for GUI simulation in the Prolog interpreter.

**Key files:**
- `FormDemo.clw` — Clarion PROGRAM with WINDOW, ENTRY, BUTTON controls, ACCEPT/CASE event handling
- `FormDemo.cwproj` — MSBuild project (`OutputType=WinExe`, `Model=Exe`)

**Build:**
```bash
cd form-demo
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe FormDemo.cwproj
```

**GUI simulation approach:** The Prolog interpreter simulates the GUI event loop via an event queue. `exec_program(AST, Events, Result)` takes a list of simulated events (equate numbers for button presses), feeds them one-at-a-time through the ACCEPT loop, and executes the CASE body for each event. No actual GUI rendering — pure behavioral simulation.

### odbc-store/
Clarion DLL with ODBC-based sensor reading storage using SQL Server LocalDB. Demonstrates Clarion's ODBC file driver with the same file I/O operations (OPEN, SET, NEXT, ADD, DELETE, CLOSE) used for flat files.

**Key files:**
- `OdbcStore.clw` — Clarion DLL: ODBCOpen, ODBCClose, ODBCAddReading, ODBCGetReading, ODBCCountReadings, ODBCDeleteAll
- `OdbcStore.cwproj` — MSBuild project (links `ClaODB.lib`)
- `setup_db.py` — One-time setup: creates OdbcDemo database, User DSN, and SensorReadings table
- `test_odbcstore.py` — Python test (16 assertions pass)

**Setup & test:**
```bash
cd odbc-store
sqllocaldb start MSSQLLocalDB
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe setup_db.py
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe OdbcStore.cwproj
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_odbcstore.py
```

**Architecture:** Python → `ctypes.CDLL` → `OdbcStore.dll` → ODBC → SQL Server LocalDB (`OdbcDemo.SensorReadings`)

**Key lessons learned:**
- Clarion's ODBC driver uses `DRIVER('ODBC')` with `OWNER('DSN_name')` for the connection
- `{` and `}` in Clarion string literals conflict with `<nn>` character escaping; use a DSN instead of DSN-less connection strings with `{Driver Name}`
- ODBC DELETE requires a KEY with PRIMARY on the FILE declaration
- Runtime DLLs: `ClaODB.dll` and `Claodbcs.dll` must be in `bin/` alongside the built DLL

### prolog-interp/
SWI-Prolog interpreter for Clarion source code. Single-pass DCG grammar parses `.clw` files into an AST, then a separate interpreter executes the AST.

**Key files:**
- `clarion_parser.pl` — DCG grammar module (source → AST), supports MEMBER and PROGRAM forms, WINDOW/ACCEPT/controls
- `clarion_interpreter.pl` — Interpreter module (AST → results) + file I/O simulation + GUI event simulation + execution tracing
- `clarion.pl` — Convenience re-export of both modules (backward compatibility)
- `test_parser.pl` — Parser-only tests (12 tests)
- `test_interpreter.pl` — Interpreter-only tests (28 tests, includes GUI simulation)
- `test_clarion.pl` — Combined test suite (28 tests, uses clarion.pl re-export)
- `trace_sensorlib.pl` — Execution trace output for diff comparison with Python side

**Run tests:**
```bash
cd prolog-interp
swipl -g "main,halt" -t "halt(1)" test_parser.pl       # parser only
swipl -g "main,halt" -t "halt(1)" test_interpreter.pl   # interpreter only
swipl -g "main,halt" -t "halt(1)" test_clarion.pl       # all tests
```

**Run trace comparison:**
```bash
diff <(cd sensor-data && python trace_sensorlib.py | grep "^CALL") \
     <(cd prolog-interp && swipl -g "main,halt" trace_sensorlib.pl | grep "^CALL.*->")
```

**Current status:** Parses and executes MathLib, DiagnosisStore, SensorLib, StatsLib, FormDemo, and OdbcStore. Full file I/O simulation (OPEN/CREATE/SET/NEXT/ADD/PUT/DELETE/CLEAR) with stateful record storage. GUI event simulation via `exec_program(AST, Events, Result)` for PROGRAM-style forms with WINDOW/ACCEPT. Global variable persistence across procedure calls. Execution trace mode (`set_trace(on)`) logs procedure entry/exit and every statement. Supports ODBC file declarations (OWNER, KEY/PRIMARY).

**Expansion plan — DiagnosisStore support (4 chunks):**

Each chunk extends the DCG grammar and interpreter to handle more of `DiagnosisStore.clw`.

1. **Declarations & data model** (chunk 1)
   - `FILE,DRIVER(),NAME(),CREATE,PRE() / RECORD / END / END`
   - `GROUP,PRE() / fields / END`
   - Field types: `CSTRING(n)`, `LONG`
   - Global variables with initializers: `NextID LONG(0)`
   - Local variables in procedures: `Count LONG(0)`
   - Enhanced MAP: `MODULE()...END`, `PRIVATE`, `*CSTRING` param type, `RAW`/`PASCAL` attrs

2. **Control flow** (chunk 2)
   - `IF expr THEN statement .` (single-line, dot-terminated)
   - `IF expr / stmts / END` (block form)
   - `IF expr / stmts / ELSE / stmts / END`
   - `LOOP / stmts / END`
   - `BREAK`

3. **Expressions & assignment** (chunk 3)
   - Assignment: `var = expr`
   - Compound assignment: `var += expr`
   - Comparison operators: `=`, `<>`, `>=`
   - Qualified names: `DX:RecordID`, `DB:ICDCode`
   - Arithmetic in expressions: `bufPtr + Offset`, `Count * SIZE(DiagBuf)`
   - Dot statement terminator

4. **Builtins & procedure calls** (chunk 4)
   - File I/O: `SET()`, `NEXT()`, `OPEN()`, `CREATE()`, `CLOSE()`, `GET()`, `PUT()`, `ADD()`, `CLEAR()`
   - Intrinsics: `ERRORCODE()`, `TODAY()`, `ADDRESS()`, `SIZE()`, `POINTER()`
   - User-defined procedure calls: `FindRecord(id)`
   - External calls: `MemCopy(dest, src, len)`

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
