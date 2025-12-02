# CLAUDE.md

This file provides context for Claude Code when working on this project.

## Project Overview

This project uses Prolog to parse, analyze, and execute Clarion programs. Clarion is a 4GL (fourth-generation language) used primarily for database application development.

## Technology Stack

- **Prolog**: Primary implementation language (targeting SWI-Prolog)
- **Clarion**: The language being analyzed

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

## Architecture

The project consists of three main modules in `src/`:

### Lexer (`lexer.pl`)
Tokenizes Clarion source files into a token stream.

### Parser (`parser.pl`)
Parses tokens into an AST using DCG (Definite Clause Grammars).

### Interpreter (`interpreter.pl`)
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

## Running Programs

```prolog
?- use_module(src/clarion).

% Parse and display AST
?- analyze_file('examples/hello_world.clw').

% Execute a program
?- run_file('examples/hello_world.clw').

% Parse to AST for inspection
?- parse_file('examples/file_io.clw', AST).
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

## Running Tests

```prolog
?- run_tests.
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
