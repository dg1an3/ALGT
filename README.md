# Clarion Prolog Analyzer

A Prolog-based static analysis tool for Clarion programs.

## Overview

This project uses Prolog to parse and analyze Clarion source code, enabling:

- Static analysis of Clarion program structure
- Code pattern detection
- Dependency analysis
- Query-based code exploration

## Requirements

- SWI-Prolog 8.0+ (recommended) or another ISO Prolog implementation

## Getting Started

```prolog
?- [analyzer].
?- analyze_file('path/to/your/clarion/file.clw').
```

## Project Structure

```
clarion_prolog/
├── README.md           # This file
├── CLAUDE.md           # Claude Code assistant context
└── src/                # Prolog source files (to be added)
```

## Why Prolog?

Prolog excels at:

- Pattern matching on tree structures (ASTs)
- Declarative queries over code relationships
- Backtracking search for code patterns
- Logic-based reasoning about program properties

## License

TBD
