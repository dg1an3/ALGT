# Clarion Prolog Analyzer

A Prolog-based static analysis tool for Clarion programs.

## Overview

This project uses Prolog to parse and analyze Clarion source code, enabling:

- Static analysis of Clarion program structure
- Code pattern detection
- Dependency analysis
- Query-based code exploration

## Requirements

- SWI-Prolog 8.0+ (recommended)

Install on macOS:
```bash
brew install swi-prolog
```

## Getting Started

```bash
# Run the test suite
swipl test_parser.pl

# Or use interactively
swipl
?- use_module(src/clarion).
?- analyze_file('examples/hello_world.clw').
```

## Project Structure

```
clarion_prolog/
├── README.md           # This file
├── CLAUDE.md           # Claude Code assistant context
├── test_parser.pl      # Test runner
├── src/
│   ├── clarion.pl      # Main entry point
│   ├── lexer.pl        # Tokenizer (DCG)
│   └── parser.pl       # Parser (DCG)
└── examples/           # Sample Clarion programs
    ├── hello_world.clw
    ├── data_types.clw
    └── ...
```

## Why Prolog?

Prolog excels at:

- Pattern matching on tree structures (ASTs)
- Declarative queries over code relationships
- Backtracking search for code patterns
- Logic-based reasoning about program properties

## License

TBD
