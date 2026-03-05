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
