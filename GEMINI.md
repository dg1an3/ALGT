# GEMINI.md

This file provides context for Gemini Code when working on this project.

## Project Overview

This project uses Prolog to parse, analyze, and execute Clarion programs. Clarion is a 4GL (fourth-generation language) used primarily for database application development. It also includes formal verification of medical imaging algorithms (ALGT).

## Technology Stack

- **Prolog**: Primary implementation language (targeting SWI-Prolog)
- **Logtalk**: Object-oriented Prolog extension (domain models)
- **Clarion 11.1**: The language being analyzed (compiles to 32-bit Windows DLLs/EXEs)
- **Python 3.11 (32-bit)**: ctypes interop with Clarion DLLs

## Key Concepts

### Clarion Language Basics

Clarion programs consist of:
- **Program files** (.clw) - Main source files
- **Include files** (.inc) - Header/interface files
- **Dictionary files** (.dct) - Database schema definitions

Clarion uses a structured syntax with:
- `PROGRAM`, `MAP`, `CODE` sections
- `PROCEDURE` definitions
- Data declarations with types like `STRING`, `LONG`, `SHORT`, `DECIMAL`
- Control structures: `IF`, `LOOP`, `CASE`
- Embedded SQL for database access

### Prolog Analysis Approach

The analyzer represents Clarion code as Prolog facts and rules:
- Source code is parsed into an AST represented as Prolog terms
- Analysis queries are written as Prolog predicates
- Results can be queried interactively

## Repository Structure

```
├── clarion_projects/              # Compiled Clarion projects
│   ├── hello-world/               # Simple PROGRAM exe
│   ├── python-dll/                # DLL with exported functions (Python ctypes)
│   ├── diagnosis-store/           # DOS flat-file CRUD DLL
│   ├── sensor-data/               # Sensor readings DLL, trace comparison
│   ├── stats-calc/                # Statistical calculations DLL
│   ├── odbc-store/                # ODBC DLL with SQL Server LocalDB
│   └── clarion_examples/          # Reference .clw files
├── clarion_interpreters/          # Prolog interpreters for Clarion
│   ├── prolog-interp/             # Original interpreter (2,764 lines, 8 files)
│   └── clarion_interpreter/       # ALGT interpreter (7,629 lines, 18 files)
├── form-demo/                     # GUI form with WINDOW/ACCEPT event loop
├── form-cli/                      # CLI form with EventReader, .evt format
├── algt_tests/                    # Algorithm verification test suite
├── domain_models/                 # Logtalk domain models & workflows
│   ├── imaging_services/          # Image import manager, contracts
│   ├── subject_image_domain_model/
│   ├── treatment_image_domain_model/
│   └── appointment_domain_model/
├── model_checker/                 # Concurrent operation verification
├── mcp_server/                    # MCP server (Prolog)
├── mcp_server_erlang/             # MCP server (Erlang)
├── mcp_server_elixir/             # MCP server (Elixir)
└── docs/
```

## Architecture

The project has two Clarion interpreters under `clarion_interpreters/`:

### Original Interpreter (`clarion_interpreters/prolog-interp/`)
Single-file architecture with parser, interpreter, and tracing (2,764 lines, 8 files).

### Modular Interpreter (`clarion_interpreters/clarion_interpreter/`)
Full modular interpreter (7,629 lines, 18 files):

#### Lexer (`lexer.pl`)
Tokenizes Clarion source files into a token stream.

#### Parser (`parser.pl`)
Parses tokens into an AST using DCG (Definite Clause Grammars).

#### Interpreter (`interpreter.pl`)
Executes Clarion programs from their AST representation.

**Supported features:**
- Variables (local, global, prefixed file fields like `Cust:CustomerID`)
- Expressions (arithmetic, comparison, logical, string concatenation)
- Control flow: `IF/ELSIF/ELSE`, `LOOP` (infinite, TO, WHILE, UNTIL), `CASE/OF`, `BREAK`, `CYCLE`
- Procedures with parameters and local variables
- Routines (`DO`/`ROUTINE` with `EXIT`)
- File I/O operations (in-memory simulation):
  - `CREATE`, `OPEN`, `CLOSE`, `CLEAR`, `EMPTY`
  - `ADD`, `GET`, `PUT`, `DELETE`, `NEXT`, `SET`
  - `RECORDS`, `ERRORCODE`, `ERROR`
- Built-in functions: `MESSAGE`, `CLIP`, `LEN`, `CHR`, `VAL`, `TODAY`, `CLOCK`
- UI simulation with pluggable backends
- Scenario-based testing with AutoHotkey generation

## Running Programs

```prolog
?- use_module(clarion_interpreters/clarion_interpreter/clarion).

% Parse and display AST
?- analyze_file('clarion_projects/clarion_examples/hello_world.clw').

% Execute a program
?- run_file('clarion_projects/clarion_examples/hello_world.clw').

% Parse to AST for inspection
?- parse_file('clarion_projects/clarion_examples/file_io.clw', AST).
```

## Development Guidelines

- Use descriptive predicate names following Prolog conventions (lowercase, underscores)
- Document predicates with comments explaining their purpose
- Keep facts and rules modular for easy testing
- Use DCG (Definite Clause Grammars) for parsing when appropriate

## File Naming Conventions

- `.pl` - Prolog source files
- `.clw` - Clarion source files (input for analysis)
- `.inc` - Clarion include files
- `.lgt` - Logtalk source files

## Running Tests

```bash
# Prolog interpreter tests
cd clarion_interpreters/prolog-interp
swipl -g "main,halt" -t "halt(1)" test_parser.pl
swipl -g "main,halt" -t "halt(1)" test_interpreter.pl

# ALGT verification tests
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl
```

## Common Tasks

### Adding a new analysis rule

1. Define the pattern to match as a Prolog predicate
2. Add test cases in the test suite
3. Document the rule's purpose and usage

### Parsing new Clarion constructs

1. Extend the DCG grammar in the parser module
2. Add corresponding AST term definitions
3. Update analysis rules to handle new constructs
