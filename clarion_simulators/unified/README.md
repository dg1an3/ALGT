# Unified Clarion Simulator

SWI-Prolog simulator that parses and executes Clarion 4GL source files. Combines a proven DCG parser with a modular execution engine.

## Quick Start

```bash
swipl -g "main,halt" -t "halt(1)" test_unified.pl
```

## Module Overview

### Core Pipeline

| Module | Role |
|--------|------|
| `clarion_parser.pl` | DCG parser — tokenizes and parses `.clw` files into a simple AST |
| `ast_bridge.pl` | Translates simple parser AST into the modular engine's AST format |
| `clarion.pl` | Unified API (`parse_clarion`, `exec_procedure`, `init_session`, `call_procedure`, `exec_program`) |

### Execution Engine

| Module | Role |
|--------|------|
| `simulator.pl` | Main executor — statement dispatch, procedure calls, ACCEPT loop |
| `simulator_eval.pl` | Expression evaluator (arithmetic, comparisons, logical ops) |
| `simulator_builtins.pl` | Built-in functions (SIZE, ERRORCODE, CLIP, LEFT, UPPER, etc.) |
| `simulator_state.pl` | Variable state management (get/set, scoping) |
| `simulator_control.pl` | Control flow (BREAK, CYCLE, EXIT, RETURN) via exceptions |
| `simulator_classes.pl` | OOP support (class instances, method dispatch) |

### Storage Backends

| Module | Role |
|--------|------|
| `storage_backend.pl` | Storage dispatch — routes file ops to the appropriate backend |
| `storage_memory.pl` | In-memory record storage (default for testing) |
| `storage_csv.pl` | CSV file-backed storage |
| `storage_odbc.pl` | ODBC/SQL database storage |

### UI Simulation

| Module | Role |
|--------|------|
| `ui_backend.pl` | UI backend abstraction |
| `ui_simulation.pl` | Event queue simulation for WINDOW/ACCEPT loops |

### Tracing & Analysis

| Module | Role |
|--------|------|
| `execution_tracer.pl` | Execution trace capture, DAG construction, ML exports (PyTorch Geometric, PGM, PyMC, Stan, GNN-VAE) |
| `templates/` | External Python templates loaded by `execution_tracer.pl` (`analyze_paths.py`, `gnn_vae.py`) |
| `trace_sensorlib.pl` | SensorLib trace script for comparison against compiled DLL |
| `compare_cdb_unified.py` | Three-way trace comparison: CDB debugger vs unified simulator vs original simulator |

### Scenario DSL

| Module | Role |
|--------|------|
| `scenario_dsl.pl` | YAML-like scenario definitions for automated testing |
| `scenario_ahk.pl` | AutoHotKey script generation from scenarios |

### Tests & Config

| File | Role |
|------|------|
| `test_unified.pl` | Test suite (130 tests) |
| `CLAUDE.md` | Detailed architecture notes, AST translation rules, fix history |

## API

```prolog
% One-shot procedure execution
exec_procedure(Source, ProcName, Args, Result).

% Stateful session (DLL simulation)
init_session(Source, Session).
call_procedure(Session, ProcName, Args, Result, Session2).

% Full program execution (GUI/event simulation)
exec_program(Source, Events, Result).
```

## Execution Tracing

Tracing is built into the simulator. Wrap any execution with `start_trace`/`stop_trace` to capture a detailed event log and execution DAG.

### Basic usage

```prolog
:- use_module(simulator).
:- use_module(execution_tracer).
:- use_module(clarion).

% Option 1: Use run_file_traced (parses + executes + traces in one call)
?- run_file_traced('example.clw', Trace).

% Option 2: Wrap any execution manually
?- start_trace,
   exec_procedure(Source, 'MyProc', [1, 2], Result),
   stop_trace(Trace).

% Trace is a dict: trace{events, duration, summary}
```

### Inspecting the trace

```prolog
% After start_trace + some execution...

% Get the execution path (sequence of statements and branches)
?- get_execution_path(Path).

% Get all branch decisions (IF/CASE conditions and which way they went)
?- get_branch_decisions(Decisions).

% Get the history of a specific variable
?- get_variable_history('Counter', History).

% Get the full execution DAG (nodes = operations, edges = control + data flow)
?- get_execution_graph(Graph).

% Export the DAG as GraphViz DOT
?- get_execution_graph(Graph), graph_to_dot(Graph, DotString).
```

### What gets traced automatically

The simulator emits trace events during execution — no source modification needed:

- **Assignments**: variable name, old value, new value, plus data-dependency edges
- **Branches**: IF/CASE conditions, the evaluated value, which branch was taken
- **Loops**: start/end, iteration count, condition values
- **Procedure calls**: name, arguments, return value

### ML exports

The execution DAG can be exported for machine learning pipelines:

```prolog
% PyTorch Geometric COO format
?- get_execution_graph(G), graph_to_edge_index(G, EdgeIndex, EdgeTypes).

% Probabilistic graphical model (Bayesian network over branches)
?- get_execution_graph(G), graph_to_pgm(G, PGM).

% Generate a complete PyMC + Stan package
?- get_execution_graph(G), graph_to_pgm(G, PGM),
   pgm_to_python_package(PGM, G, Files).
% Files = ['model_pymc.py'-Code, 'model.stan'-Code, 'graph.json'-Json, 'analyze_paths.py'-Script]

% Generate a GNN-VAE training package (for latent space learning over traces)
?- generate_gnn_vae_package([Graph1, Graph2, ...], Files).
% Files = ['traces.json'-DatasetJson, 'gnn_vae.py'-VAECode]
```
