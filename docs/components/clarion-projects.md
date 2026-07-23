---
title: Clarion projects
layout: default
parent: Components
nav_order: 3
---

# Clarion projects

Real Clarion 11.1 DLLs and EXEs that serve as the **ground-truth binaries** for
execution-trace comparison. Clarion 11 produces 32-bit Windows binaries, so a
32-bit Python (`3.11.9-win32`) hosts them via `ctypes`.

**Location:** [`clarion_projects/`](https://github.com/DLaneAtElekta/ALGT/tree/main/clarion_projects)
· **Build:** MSBuild against `.cwproj` · **Host:** 32-bit Python + CDB (x86)

## Projects

| Project | What it demonstrates |
|---|---|
| `hello-world/` | Simple `PROGRAM` EXE (message box) |
| `python-dll/` | DLL with exported functions called from Python via `ctypes` (`MathLib`) |
| `diagnosis-store/` | DOS flat-file CRUD DLL, `*CSTRING` marshalling |
| `sensor-data/` | Flat-file sensor readings, weighted averages — the **primary trace-comparison case** |
| `stats-calc/` | Statistical calculations DLL |
| `odbc-store/` | ODBC DLL backed by SQL Server LocalDB |
| `form-demo/` | GUI form (WINDOW/ACCEPT loop) + FormLib DLL for variable-level tracing |
| `form-cli/` | CLI form using `EventReader` and `.evt` event files |
| `treatment-offset/` | Direction dropdowns with sign-flip normalization + ISqrt magnitude |
| `struct-demo`, `html_gen_demo` | Struct marshalling + HTML rendering |
| `qualified-names`, `mandelbrot`, `automata` | Language features + numeric/state-machine demos |
| `brimstone-{dose,kernel,optim}` | Dose-calculation port targets |
| `dh-{graph,mtl,rtmodel,volume}` | dH RT-planning library port targets |
| `penbeam-{edit,edit-simple,indens}` | Pen-beam editor ports |
| `quickdraw-{3d,grafutil,types}` | QuickDraw graphics ports |
| `radar-{modem,picdb,term}` | RADAR Pascal ports |
| `ssm-fuel` | SSM Pascal port |
| `clarion_examples/` | Reference `.clw` syntax samples |

## Trace comparison in practice

The `sensor-data` project is the canonical demonstration. It runs the compiled
DLL under **CDB** (hardware breakpoints on each export), captures arguments and
return values straight from the binary, and diffs them against the Prolog
interpreter:

```bash
cd clarion_projects/sensor-data
python compare_cdb_prolog.py
```

See [Architecture → execution-trace comparison]({{ site.baseurl }}/architecture.html#execution-trace-comparison)
for Levels 1, 1b, and 1c in detail.

## Clarion DLL conventions

A few hard-won rules for building DLLs that Python `ctypes` can call:

- Use `MEMBER()` (no args) at the top of the `.clw` — not `PROGRAM`.
- Add the `EXPORT` attribute to each procedure in the `MAP`.
- Use the `C` calling convention for `ctypes` compatibility, and `NAME('...')` for clean export names.
- `*CSTRING` params under the `C` convention pass a hidden `LONG length` before each string pointer on the stack.
- Avoid naming a procedure `Add` — it collides with a Clarion intrinsic.
- `.clw` files require CRLF line endings, and `ClaRUN.dll` must sit alongside the built DLL at runtime.

**Build example**

```bash
cd clarion_projects/python-dll
/c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe MathLib.cwproj
cp ../hello-world/bin/ClaRUN.dll bin/
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_mathlib.py
```

## Related

- [Language simulators]({{ site.baseurl }}/components/simulators.html) — the interpreter side of every comparison.
- [MCP servers → Python DLL]({{ site.baseurl }}/components/mcp-servers.html) — wraps any Clarion DLL as MCP tools.
