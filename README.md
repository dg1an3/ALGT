# ALGT - Algorithm Logic Verification Tool & Clarion Interpreter

A Prolog-based platform combining:
- **ALGT**: Formal verification of imaging algorithms for medical radiation treatment planning
- **Clarion Interpreter**: Parser and interpreter for the Clarion 4GL language

## Overview

This repository provides formal verification and analysis capabilities using SWI Prolog and Logtalk:

- **Geometric Algorithm Verification**: Formal verification of beam volumes, mesh generation, isodensity calculations
- **Model Checking**: Verification of concurrent operations with interleaving analysis
- **Clarion Language Support**: Parse, analyze, and execute Clarion programs
- **Scenario-Based Testing**: DSL for UI testing with AutoHotkey script generation

## Requirements

- [SWI Prolog](https://www.swi-prolog.org/) (version 8.0+ recommended)
- [Logtalk](https://logtalk.org/) (for ALGT object-oriented components)

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

### Clarion Interpreter
```prolog
swipl
?- use_module(src/clarion).
?- run_file('examples/hello_world.clw').
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

### Running Tests
```prolog
?- run_tests.
```

## Project Structure

```
├── algt_tests/              # Algorithm verification test suite
│   ├── ALGT_BEAM_VOLUME.pl  # Beam volume generation tests
│   ├── ALGT_MESH_GEN.pl     # Mesh generation tests
│   └── ...
├── imaging_services/        # Domain services and workflows (Logtalk)
│   ├── contracts.lgt        # Protocol definitions
│   ├── image_import_manager.lgt
│   └── ...
├── model_checker/           # Concurrent operation verification
│   ├── model_checker.pl
│   └── README.md
├── src/                     # Clarion interpreter
│   ├── clarion.pl           # Main entry point
│   ├── lexer.pl             # Tokenizer
│   ├── parser.pl            # Parser (DCG)
│   ├── interpreter.pl       # Interpreter core
│   ├── ui_backend.pl        # Pluggable UI backends
│   ├── scenario_dsl.pl      # Test scenario DSL
│   └── scenario_ahk.pl      # AutoHotkey generator
├── examples/                # Sample Clarion programs
├── subject_image_domain_model/
├── treatment_image_domain_model/
├── appointment_domain_model/
└── docs/
```

## Key Components

### ALGT Algorithm Verification
Test cases that formally verify geometric algorithms critical to medical imaging:
- **ALGT_BEAM_VOLUME**: Radiation beam volume generation
- **ALGT_MESH_GEN**: 3D mesh creation and manipulation
- **ALGT_ISODENSITY**: Dose distribution calculations
- **ALGT_STRUCT_PROJ**: Geometric structure projections

### Clarion Interpreter
Full interpreter for Clarion language supporting:
- Variables, expressions, control flow
- Procedures, routines, classes
- File I/O operations (in-memory simulation)
- UI simulation with pluggable backends
- Scenario-based testing with AHK generation

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
