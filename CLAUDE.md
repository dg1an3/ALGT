# CLAUDE.md - AI Assistant Guide

This document provides guidance for AI assistants working with this combined codebase.

## Project Overview

This repository contains two Prolog-based projects:

### 1. ALGT - Algorithm Logic Verification Tool
An expert system using SWI Prolog and Logtalk for formal verification of imaging algorithms used in medical radiation treatment planning.

### 2. Clarion Interpreter
A Prolog-based interpreter for Clarion, a 4GL (fourth-generation language) used primarily for database application development.

## Technology Stack

- **SWI Prolog**: Core logic programming language
- **Logtalk**: Object-oriented extension for Prolog (ALGT components)
- **Model Checking**: Formal verification of concurrent operations
- **Domain-Driven Design**: Event sourcing and domain modeling

## Project Structure

```
├── algt_tests/              # ALGT algorithm verification tests
├── imaging_services/        # ALGT domain services (Logtalk)
├── model_checker/           # ALGT concurrent operation verification
├── subject_image_domain_model/
├── treatment_image_domain_model/
├── appointment_domain_model/
├── src/                     # Clarion interpreter modules
│   ├── clarion.pl           # Main entry point
│   ├── lexer.pl             # Tokenizer
│   ├── parser.pl            # Parser (DCG)
│   ├── interpreter.pl       # Interpreter core
│   ├── ui_backend.pl        # UI abstraction layer
│   ├── scenario_dsl.pl      # Test scenario DSL
│   └── scenario_ahk.pl      # AutoHotkey script generator
├── examples/                # Sample Clarion programs
└── docs/                    # Documentation
```

---

## ALGT Components

### Algorithm Verification Tests (`algt_tests/`)
Verify geometric algorithms:
- **Beam Volume**: Radiation beam volume generation
- **Mesh Generation**: 3D mesh creation and manipulation
- **Isodensity**: Dose distribution calculations
- **Structure Projection**: 2D/3D geometric projections

### Imaging Services (`imaging_services/`)
Domain services implementing image import, review, and workflow management:
- **Protocols (contracts.lgt)**: Interface definitions using Logtalk protocols
- **Managers**: Coordinate operations (import, review, trending)
- **Event Store**: Event sourcing implementation

### Model Checker (`model_checker/`)
Verifies interleaved concurrent operations to identify race conditions.

---

## Clarion Interpreter Components

### Lexer (`src/lexer.pl`)
Tokenizes Clarion source files into a token stream.

### Parser (`src/parser.pl`)
Parses tokens into an AST using DCG (Definite Clause Grammars).

### Interpreter (`src/interpreter.pl`)
Executes Clarion programs from their AST representation.

**Supported features:**
- Variables (local, global, prefixed file fields like `Cust:CustomerID`)
- Expressions (arithmetic, comparison, logical, string concatenation)
- Control flow: `IF/ELSIF/ELSE`, `LOOP`, `CASE/OF`, `BREAK`, `CYCLE`
- Procedures with parameters and local variables
- Routines (`DO`/`ROUTINE` with `EXIT`)
- File I/O operations (in-memory simulation)
- Built-in functions: `MESSAGE`, `CLIP`, `LEN`, `CHR`, `VAL`, `TODAY`, `CLOCK`

### UI Backend (`src/ui_backend.pl`)
Pluggable UI abstraction supporting:
- Simulation backend (testing)
- TUI backend (terminal)
- Remote backend (JSON/JavaScript)

### Scenario DSL (`src/scenario_dsl.pl`, `src/scenario_ahk.pl`)
Declarative testing DSL with AutoHotkey script generation for real Clarion app testing.

---

## Running Code

### Clarion Interpreter
```prolog
?- use_module(src/clarion).
?- run_file('examples/hello_world.clw').
```

### ALGT Tests
```bash
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl
```

### Logtalk Services
```bash
logtalk
?- logtalk_load('imaging_services/loader.lgt').
```

### Running Tests
```prolog
?- run_tests.
```

---

## Development Guidelines

### Prolog/Logtalk
- Use descriptive predicate names with underscores
- Document predicates with comments
- Use DCG for parsing when appropriate
- Prefix Logtalk protocols with `i` (e.g., `iimage_import_manager`)

### Code Style
- Keep facts and rules modular for easy testing
- Comment complex logical expressions
- Use meaningful variable names (capitalize in Prolog)

### Important Considerations

1. **Medical Software** (ALGT): Code relates to radiation treatment planning
   - Correctness is critical for patient safety
   - Geometric calculations must be precise
   - Always maintain test coverage

2. **Formal Verification**: Don't weaken assertions without justification
   - Maintain mathematical rigor in predicates
   - Document assumptions and tolerances

---

## File Naming Conventions

- `.pl` - Prolog source files
- `.lgt` - Logtalk source files
- `.clw` - Clarion source files
- `.inc` - Clarion include files

## Resources

- [SWI Prolog Documentation](https://www.swi-prolog.org/pldoc/doc_for?object=manual)
- [Logtalk Documentation](https://logtalk.org/documentation.html)
- Model Checker: See `model_checker/README.md`
