---
title: Language simulators
layout: default
parent: Components
nav_order: 2
---

# Language simulators

Executable semantic models of the legacy languages ALGT targets. Each simulator
pairs a **parser** (usually a DCG) with a **modular execution engine**, so a
legacy program can be *run* — and its execution trace compared against the
compiled binary.

**Location:** [`simulators/`](https://github.com/dg1an3/ALGT/tree/main/simulators)

| Simulator | Target language | Notes |
|---|---|---|
| `clarion/unified/` | Clarion 4GL | The flagship simulator — DCG parser + pluggable storage/UI |
| `clarion/erlog_sim/` | Clarion 4GL | Erlang-based experiment |
| `pascal/unified/` | Object Pascal / Lazarus | The MUZAQ front end |
| `c34gl/` | C3/4GL variant | Prolog + web interface |
| `llvm/unified/` | LLVM IR (Pascal/RADAR target) | Lowers to LLVM IR |
| `fsharp/unified/` | F# simulator | F# variant of the engine |
| `common/` | — | Shared simulator utilities |

---

## Clarion unified simulator

The most developed component. A DCG parser plus a modular execution engine with
**Logtalk-based pluggable backends**: storage (memory / CSV / ODBC via protocol
dispatch) and UI, a scenario DSL, and an execution tracer with ML exports (PGM,
PyMC, Stan, GNN-VAE).

**Location:** [`simulators/clarion/unified/`](https://github.com/dg1an3/ALGT/tree/main/simulators/clarion/unified)

**Key files**

- `clarion.pl` — the public API
- `clarion_parser.pl` — DCG parser
- `ast_bridge.pl` — AST bridge between parser and engine
- `simulator*.pl` — the execution engine (`simulator.pl`, `simulator_builtins.pl`, `simulator_eval.pl`, `simulator_control.pl`, `simulator_state.pl`, `simulator_classes.pl`)
- `execution_tracer.pl` — statement-level tracing + ML exports
- `scenario_dsl.pl`, `scenario_ahk.pl` — scenario DSL and AutoHotkey compilation
- `storage_backend.pl` / `storage_*.lgt` — Logtalk storage protocol + memory/CSV/ODBC backends + dispatcher
- `ui_backend.pl` / `ui_*.lgt` — Logtalk UI protocol + simulation backend + dispatcher
- `web_server.pl` — web interface
- `test_unified.pl` — the test suite

**Run the tests**

```bash
cd simulators/clarion/unified
swipl -g "main,halt" -t "halt(1)" test_unified.pl
```

### Pluggable storage and UI

The simulator dispatches file I/O and UI events through Logtalk protocols
(`storage_protocol.lgt`, `ui_protocol.lgt`), so the *same* program can run
against in-memory, CSV, ODBC, or simulated-GUI backends without changing the
program under test. This is what makes both fast unit tests and
faithful trace comparison possible from one codebase.

### Scenario DSL

`scenario_dsl.pl` describes UI test flows declaratively; `scenario_ahk.pl`
compiles them to **AutoHotkey** scripts that drive the *real* compiled
application — closing the loop between the simulated and compiled worlds.

---

## Pascal, LLVM, and F# simulators

- **`pascal/unified/`** — Object Pascal / Lazarus parser + interpreter. This is the front end of the [MUZAQ modernization]({{ site.baseurl }}/architecture.html#the-muzaq-modernization-story): it extracts each `TForm` into a labeled transition system.
- **`llvm/unified/`** — lowers a Pascal/RADAR target to LLVM IR, giving a second, independent execution path to compare against.
- **`fsharp/unified/`** — an F# realization of the engine; see also the [F# projects]({{ site.baseurl }}/components/fsharp-projects.html).
- **`c34gl/`** — a C3/4GL variant with a Prolog core and a web interface.

## Related

- [Clarion projects]({{ site.baseurl }}/components/clarion-projects.html) — the compiled binaries these simulators are checked against.
- [Architecture → execution-trace comparison]({{ site.baseurl }}/architecture.html#execution-trace-comparison).
