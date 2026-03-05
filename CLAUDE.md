# learn-clarion-semantics

Experiments learning Clarion language semantics: building, DLL exports, and Python interop.

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
