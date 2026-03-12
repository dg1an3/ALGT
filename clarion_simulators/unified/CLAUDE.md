# Unified Clarion Simulator

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
simulator.pl        ← From modular (extended: eval_full_expr for binop, PROGRAM support)
simulator_state.pl  ← From modular (unchanged)
simulator_eval.pl   ← From modular (extended: integer division, lowercase and/or)
simulator_builtins.pl ← From modular (unchanged)
simulator_classes.pl  ← From modular (unchanged)
simulator_control.pl  ← From modular (unchanged)
execution_tracer.pl   ← From modular (unchanged)
storage_backend.pl    ← Thin Prolog wrapper → Logtalk storage_dispatcher
ui_backend.pl         ← Thin Prolog wrapper → Logtalk ui_dispatcher
storage_protocol.lgt  ← Logtalk protocol (interface) for storage backends
storage_memory.lgt    ← Logtalk in-memory storage backend
storage_csv.lgt       ← Logtalk CSV file storage backend
storage_odbc.lgt      ← Logtalk ODBC database storage backend
storage_dispatcher.lgt ← Logtalk dispatcher (routes by DRIVER)
ui_protocol.lgt       ← Logtalk protocol (interface) for UI backends
ui_simulation.lgt     ← Logtalk headless UI backend for testing
ui_dispatcher.lgt     ← Logtalk UI dispatcher (routes by backend type)
loader.lgt            ← Logtalk loader for all backend objects
scenario_*.pl         ← From modular (unchanged)
test_unified.pl       ← Test suite (189 tests passing)
```

## AST Bridge Translation Rules

The simple parser produces:
```prolog
program(Files, Groups, Globals, MapEntries, Procedures)
```

The modular simulator expects:
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

## Key Fixes Applied to Modular Simulator

### 1. Integer division (simulator_eval.pl)
Clarion LONG / LONG must produce integer results. Changed `eval_binop('/', L, R, Result)` to use `//` for integer operands.

### 2. eval_full_expr for binop (simulator.pl)
Added `eval_full_expr(binop(Op, Left, Right), ...)` that recursively uses `eval_full_expr` for sub-expressions. This is needed because `eval_expr` (in simulator_eval.pl) cannot handle `call(...)` expressions inside binop operands (e.g., `ERRORCODE() = 0`).

### 3. Lowercase AND/OR operators (simulator_eval.pl)
The AST bridge produces `binop(and, ...)` and `binop(or, ...)` with lowercase atoms. Added matching clauses alongside the existing uppercase `'AND'`/`'OR'` handlers.

### 4. Undefined procedure error handling (simulator.pl)
Changed from `format(error) + fail` to `throw(error(undefined_procedure(Name), ...))` so errors propagate properly through catch/throw rather than causing silent backtracking loops.

### 5. Global variable persistence across procedure calls (simulator.pl)
`exec_call` was restoring `OuterVars` after procedure return, discarding global variable changes made inside procedures (e.g., `NextID += 1`). Fixed with `merge_globals` that preserves callee's values for vars that existed in the caller.

### 6. Variable initializers (simulator.pl)
`init_globals` and `init_locals` ignored `init(Value)` terms from the bridge, always using type defaults. Fixed to use the init value when present (e.g., `X LONG(50)` now initializes to 50, not 0).

### 7. ACCEPT loop event queue (simulator.pl)
Replaced the simple phase-based ACCEPT loop with an event-driven model matching prolog-interp: consumes events from the UI state's event queue, handles `set(Var, Val)` for field entry, `choice(Name, Index)` for list selections, and integer events for button presses. Sets `__ACCEPTED__` variable for `ACCEPTED()` builtin.

### 8. Equate assignment from WINDOW controls (simulator.pl)
Added `assign_equates` in `init_globals` for `window(...)` declarations. Assigns sequential equate numbers to controls with `USE(?Name)` attributes, stored as `equate(Name)` variables in state. `control_ref(Name)` evaluates to the equate number.

### 9. CASE range matching (simulator.pl)
Added `exec_case_traced` clause for `case_of(range(Start, End), Stmts)` that evaluates range bounds and checks `Value >= Start, Value =< End`. Required for StatsLib's `OF 0 TO 10` syntax.

### 10. Array globals (ast_bridge.pl)
Bridge now translates `array(Name, Type, Size)` globals to `var(Name, TypeAtom, init(array(Zeros)))`, creating a properly wrapped array value for the simulator's array access/assignment operations.

### 11. SELECT with index (simulator_builtins.pl)
Added 2-argument `SELECT(control, index)` builtin that stores list choice state for `CHOICE()` retrieval.

### 12. Nested GROUP support (ast_bridge.pl)
`bridge_fields` now handles nested `group(Name, Prefix, SubFields)` inside RECORD and GROUP declarations by flattening sub-fields into the parent field list. `bridge_files` and `bridge_groups` extract nested groups and emit standalone group declarations so `init_group` registers their prefixes. This enables colon-chain access like `DSP:Size` for fields in nested groups.

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

## Test Coverage (107 tests)

- **Parser + Bridge** (11): MEMBER parse, MathLib, SensorLib, DiagnosisStore, FormDemo, OdbcStore, control_flow.clw PROGRAM
- **Arithmetic** (4): MathAdd, Multiply with various inputs
- **Control Flow** (9): IF/THEN, IF/ELSE, LOOP/BREAK, LOOP FOR, CASE with branches
- **File I/O - SensorLib** (8): Open, Add records, weighted average, cleanup, close
- **File I/O - DiagnosisStore** (3): Open, create diagnosis, close
- **Builtins** (5): SIZE, LOOP WHILE, LOOP UNTIL, modulo, string concat with LEN
- **GUI Form Simulation** (5): ACCEPT/CASE ACCEPTED(), equate mapping, event queue, FormDemo.clw end-to-end
- **ODBC Store** (7): Open, add readings, count, delete all, close (in-memory simulation)
- **StatsLib** (3): CASE with range matching (OF 0 TO 10), Classify function
- **Qualified Names / Nested Groups** (5): Nested GROUP in FILE, nested GROUP in GROUP, QualNames.clw end-to-end (FILE+GROUP with sub-GROUPs and colon-chain prefixes)

## Running Tests

```bash
cd clarion_interpreters/unified
swipl -l test_unified.pl -g main -t halt
```
