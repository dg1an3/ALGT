# ALGT - Algorithm Logic Verification Tool & Clarion Simulator

A Prolog-based platform combining:
- **ALGT**: Formal verification of imaging algorithms for medical radiation treatment planning
- **Clarion Simulator**: Unified DCG parser and execution engine for the Clarion 4GL language

## Overview

This repository provides formal verification and analysis capabilities using SWI Prolog and Logtalk:

- **Geometric Algorithm Verification**: Formal verification of beam volumes, mesh generation, isodensity calculations
- **Model Checking**: Verification of concurrent operations with interleaving analysis
- **Clarion Language Support**: Parse, analyze, and execute Clarion programs via a unified simulator
- **Execution Trace Comparison**: Verify Prolog interpreter matches compiled Clarion DLL behavior (procedure-level, CDB debugger, variable-level)
- **Scenario-Based Testing**: DSL for UI testing with AutoHotkey script generation

## Requirements

- [SWI Prolog](https://www.swi-prolog.org/) (version 8.0+ recommended)
- [Logtalk](https://logtalk.org/) (for ALGT object-oriented components)

### Optional (for Clarion DLL trace comparison)

- [Clarion 11.1](https://www.softvelocity.com/) (compiles to 32-bit Windows DLLs/EXEs)
- Python 3.11 (32-bit) for ctypes interop with Clarion DLLs
- CDB (x86) from Windows SDK Debugging Tools

### Installation

```bash
# On macOS
brew install swi-prolog

# On Ubuntu/Debian
sudo apt-get install swi-prolog

# Clone this repository
git clone https://github.com/DLaneAtElekta/ALGT.git
cd ALGT
```

## Quick Start

### Clarion Simulator
```bash
cd clarion_simulators/unified
swipl
?- use_module(clarion).
?- init_session(Source, Session), call_procedure(Session, 'MyProc', Result).
```

### Run Simulator Tests
```bash
cd clarion_simulators/unified
swipl -g "main,halt" -t "halt(1)" test_unified.pl
```

### ALGT Verification Tests
```bash
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl
```

### Model Checker
```prolog
swipl -s model_checker/model_checker.pl
?- valid(sequence([capture_image -> img1, update_contour -> img1])).
```

## Project Structure

```
├── clarion_projects/              # Compiled Clarion projects
│   ├── hello-world/               # Simple PROGRAM exe
│   ├── python-dll/                # DLL with exported functions (Python ctypes)
│   ├── diagnosis-store/           # DOS flat-file CRUD DLL
│   ├── sensor-data/               # Sensor readings DLL, trace comparison
│   ├── stats-calc/                # Statistical calculations DLL
│   ├── odbc-store/                # ODBC DLL with SQL Server LocalDB
│   ├── clarion_examples/          # Reference .clw files
│   ├── form-demo/                 # GUI form + FormLib DLL for CDB tracing
│   ├── form-cli/                  # CLI form with EventReader, .evt format
│   └── treatment-offset/          # Treatment offset entry with sign-flip
├── clarion_simulators/            # Prolog Clarion simulator
│   └── unified/                   # DCG parser + execution engine (104 tests)
│       ├── clarion.pl             # Public API
│       ├── clarion_parser.pl      # DCG parser
│       ├── ast_bridge.pl          # AST transformation
│       ├── simulator.pl           # Core execution engine
│       ├── simulator_builtins.pl  # Built-in functions
│       ├── simulator_eval.pl      # Expression evaluation
│       ├── simulator_control.pl   # Control flow
│       ├── simulator_state.pl     # State management
│       ├── simulator_classes.pl   # Class support
│       ├── execution_tracer.pl    # ML exports (PGM, PyMC, Stan, GNN-VAE)
│       ├── scenario_dsl.pl        # Scenario DSL
│       ├── scenario_ahk.pl        # AutoHotkey generation
│       ├── storage_backend.pl     # Pluggable storage dispatch
│       ├── storage_memory.pl      # In-memory storage
│       ├── storage_csv.pl         # CSV file storage
│       ├── storage_odbc.pl        # ODBC storage
│       ├── ui_backend.pl          # UI backend abstraction
│       ├── ui_simulation.pl       # UI simulation
│       ├── web_server.pl          # Web server interface
│       └── test_unified.pl        # Test suite
├── algt_tests/                    # Algorithm verification test suite
│   ├── ALGT_BEAM_VOLUME.pl        # Beam volume generation tests
│   ├── ALGT_MESH_GEN.pl           # Mesh generation tests
│   └── ...
├── domain_models/                 # Logtalk domain models & workflows
│   ├── imaging_services/          # Image import manager, contracts
│   ├── subject_image_domain_model/
│   ├── treatment_image_domain_model/
│   └── appointment_domain_model/
├── model_checker/                 # Concurrent operation verification
├── mcp_servers/                   # MCP server implementations
│   ├── prolog/                    # MCP server (Prolog)
│   ├── erlang/                    # MCP server (Erlang)
│   └── elixir/                    # MCP server (Elixir)
└── docs/
```

## Key Components

### ALGT Algorithm Verification
Test cases that formally verify geometric algorithms critical to medical imaging:
- **ALGT_BEAM_VOLUME**: Radiation beam volume generation
- **ALGT_MESH_GEN**: 3D mesh creation and manipulation
- **ALGT_ISODENSITY**: Dose distribution calculations
- **ALGT_STRUCT_PROJ**: Geometric structure projections

### Unified Clarion Simulator (`clarion_simulators/unified/`)
A single modular simulator (21 Prolog files, 104 tests) that combines:

- **DCG Parser** — Parses Clarion `.clw` source into AST
- **Execution Engine** — Executes Clarion programs from AST with:
  - Variables, expressions, control flow (`IF/ELSIF/ELSE`, `LOOP`, `CASE`, `BREAK`, `CYCLE`)
  - Procedures with parameters, routines (`DO`/`ROUTINE`)
  - File I/O with pluggable storage backends (memory, CSV, ODBC)
  - Class support
  - UI simulation with pluggable backends
  - Built-in functions: `MESSAGE`, `CLIP`, `LEN`, `CHR`, `VAL`, `TODAY`, `CLOCK`
- **Execution Tracer** — ML model exports (PGM, PyMC, Stan, GNN-VAE)
- **Scenario DSL** — UI testing with AutoHotkey script generation

### Execution Trace Comparison
Three levels of trace comparison verify the Prolog simulator matches compiled Clarion DLLs:
- **Level 1**: Procedure-level traces (`CALL ProcName(args) -> result`)
- **Level 1b**: CDB debugger traces (hardware breakpoints on DLL exports)
- **Level 1c**: CDB variable-level comparison (headless DLLs with get/set exports)
- **Level 2**: Statement-level traces (Prolog interpreter only)

See [CLAUDE.md](CLAUDE.md) for detailed trace comparison documentation.

### Model Checker
Formal verification of concurrent operations:
- Explores all possible interleavings
- Identifies race conditions
- See `model_checker/README.md` for details

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines and AI assistant guidance.

## License

Copyright (c) 2015, dg1an3

Licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Given the critical nature of medical software, all contributions should prioritize correctness and patient safety.
