# Unified Clarion Interpreter

## Architecture Decision: Hybrid Approach

Two interpreters existed with complementary strengths:

- **Simple** (`prolog-interp/`): Proven DCG parser handles real `.clw` files (MEMBER + PROGRAM, FILE declarations, WINDOW, GROUP). 51 passing tests, trace-validated against compiled DLLs. But monolithic, no string builtins, no OOP, no pluggable storage.
- **Modular** (`clarion_interpreter/`): Sophisticated execution engine — separate lexer, class/OOP support, pluggable storage backends (memory/CSV/ODBC), execution DAG tracer, scenario DSL, AHK generator. But its parser can't handle real project files.

**Decision**: Use the simple interpreter's proven DCG parser + a new AST bridge module + the modular execution engine. This avoids rewriting either parser or interpreter.

## Module Structure

```
clarion_parser.pl     ← From prolog-interp (extended: ELSIF, LOOP WHILE/UNTIL, ROUTINE, modulo, string concat, line continuation)
ast_bridge.pl         ← NEW: Translates simple AST → modular AST (~300 lines)
clarion.pl            ← NEW: Unified API (parse_clarion, exec_procedure, init_session, etc.)
interpreter.pl        ← From modular (extended: eval_full_expr for binop, PROGRAM support)
interpreter_state.pl  ← From modular (unchanged)
interpreter_eval.pl   ← From modular (extended: integer division, lowercase and/or)
interpreter_builtins.pl ← From modular (unchanged)
interpreter_classes.pl  ← From modular (unchanged)
interpreter_control.pl  ← From modular (unchanged)
execution_tracer.pl   ← From modular (unchanged)
storage_*.pl          ← From modular (unchanged)
ui_*.pl               ← From modular (unchanged)
scenario_*.pl         ← From modular (unchanged)
test_unified.pl       ← Test suite (40 tests passing)
```

## AST Bridge Translation Rules

The simple parser produces:
```prolog
program(Files, Groups, Globals, MapEntries, Procedures)
```

The modular interpreter expects:
```prolog
program(map(MapDecls), GlobalDecls, code(MainBody), Procedures)
```

### Key translations:

| Simple AST | Modular AST |
|---|---|
| `lit(N)` (integer) | `number(N)` |
| `lit(S)` (atom) | `string(S)` |
| `var(Name)` | `var(Name)` |
| `add(A,B)` | `binop('+', A, B)` |
| `sub(A,B)` | `binop('-', A, B)` |
| `mul(A,B)` | `binop('*', A, B)` |
| `div(A,B)` | `binop('/', A, B)` |
| `eq(A,B)` | `binop('=', A, B)` |
| `gt(A,B)` | `binop('>', A, B)` |
| `if(Cond, Then, Else)` | `if(Cond, Then, [], Else)` (4-arg with empty ELSIF) |
| `loop_for(V,S,E,B)` | `loop_to(V,S,E,B)` |
| `case(E, Ofs, Else)` | `case(E, Cases, Else)` with `of(single(V),S)` → `case_of(V,S)` |
| `equate(Name)` | `control_ref(Name)` |
| `param(Name, Type)` | `param(TypeAtom, Name)` (order swapped) |
| `local(Name, Type, Init)` | `local_var(Name, TypeAtom, init(Init))` |
| `ref(Type)` in params | Unwrapped to base type (ref is transparent) |

### PROGRAM handling

The simple parser creates a `_main` procedure from PROGRAM's CODE section. The bridge extracts `_main`'s body as the program's `MainBody` and puts remaining procedures in the procedure list. The PROGRAM grammar was extended to also parse procedures after the CODE section.

## Key Fixes Applied to Modular Interpreter

### 1. Integer division (interpreter_eval.pl)
Clarion LONG / LONG must produce integer results. Changed `eval_binop('/', L, R, Result)` to use `//` for integer operands.

### 2. eval_full_expr for binop (interpreter.pl)
Added `eval_full_expr(binop(Op, Left, Right), ...)` that recursively uses `eval_full_expr` for sub-expressions. This is needed because `eval_expr` (in interpreter_eval.pl) cannot handle `call(...)` expressions inside binop operands (e.g., `ERRORCODE() = 0`).

### 3. Lowercase AND/OR operators (interpreter_eval.pl)
The AST bridge produces `binop(and, ...)` and `binop(or, ...)` with lowercase atoms. Added matching clauses alongside the existing uppercase `'AND'`/`'OR'` handlers.

### 4. Undefined procedure error handling (interpreter.pl)
Changed from `format(error) + fail` to `throw(error(undefined_procedure(Name), ...))` so errors propagate properly through catch/throw rather than causing silent backtracking loops.

## Key Fixes Applied to Parser

### 1. PROGRAM form extended
Added `procedures(Procs)` after `statements(Body)` so PROGRAM files with separate procedure definitions parse correctly.

### 2. RETURN grammar (same-line expression)
Changed from `RETURN expr` (greedy, crosses newlines) to `RETURN ws_nonnl expr` so that bare `RETURN` on one line doesn't consume the next line's procedure name as a return value. Also separated `RETURN(expr)` paren form and bare `RETURN`.

### 3. Keyword boundary fix (`kw`)
Removed catch-all `kw([]) --> [].` that defeated the word-boundary check. This prevented `DISPLAY` from matching inside `DisplayResults`.

### 4. `C` removed from keyword list
`C` is a calling convention attribute, not a general keyword. Having it in the keyword list prevented `C` from being used as a variable name (e.g., `C LONG(0)` as a local variable).

### 5. New parser features
- **ELSIF**: Parses `IF...ELSIF...ELSE...END` chains as nested `if()` terms
- **LOOP WHILE/UNTIL**: Added `loop_while(Cond, Body)` and `loop_until(Cond, Body)`
- **CYCLE/EXIT/DO**: Control flow statements for loops and routines
- **ROUTINE**: `Name ROUTINE` parsed alongside procedures
- **Modulo**: `%` operator at multiplication precedence
- **String concatenation**: `&` operator at addition precedence
- **Line continuation**: `|` at end of line continues to next line
- **STRING/SHORT/REAL types**: Added to type parser
- **PROCEDURE in MAP**: `Name PROCEDURE[(params)]` MAP entry syntax
- **Optional procedure params**: `Name PROCEDURE` without `(params)` in definitions

## API

### One-shot procedure execution
```prolog
exec_procedure(Source, ProcName, Args, Result).
```

### Stateful session (DLL simulation)
```prolog
init_session(Source, Session).
call_procedure(Session, ProcName, Args, Result, Session2).
```

### Full program execution (GUI/event simulation)
```prolog
exec_program(Source, Events, Result).
```

## Test Coverage (40 tests)

- **Parser + Bridge** (11): MEMBER parse, MathLib, SensorLib, DiagnosisStore, FormDemo, OdbcStore, control_flow.clw PROGRAM
- **Arithmetic** (4): MathAdd, Multiply with various inputs
- **Control Flow** (9): IF/THEN, IF/ELSE, LOOP/BREAK, LOOP FOR, CASE with branches
- **File I/O - SensorLib** (8): Open, Add records, weighted average, cleanup, close
- **File I/O - DiagnosisStore** (3): Open, create diagnosis, close
- **Builtins** (5): SIZE, LOOP WHILE, LOOP UNTIL, modulo, string concat with LEN

## Running Tests

```bash
cd clarion_interpreters/unified
swipl -l test_unified.pl -g main -t halt
```
