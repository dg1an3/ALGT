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
clarion_types.pl      ← Declared-type conversion (padding, wrap-around), comparison, byte sizes
clarion_dates.pl      ← Clarion standard dates/times and database column conversion
ui_protocol.lgt       ← Logtalk protocol (interface) for UI backends
ui_simulation.lgt     ← Logtalk headless UI backend for testing
ui_dispatcher.lgt     ← Logtalk UI dispatcher (routes by backend type)
loader.lgt            ← Logtalk loader for all backend objects
scenario_*.pl         ← From modular (unchanged)
test_unified.pl       ← Test suite (includes test_fidelity.pl: language semantics; test_parse_coverage.pl)
clarion_preproc.pl    ← COMPILE/OMIT conditional-compile pre-pass
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
| `ref(Type)` in params | `ref(TypeAtom)`; changed values are copied back to the caller |
| `string(N)` etc. | `typed('STRING', size(N))` for variables; fields carry `size(N)` |

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
`exec_call` was restoring `OuterVars` after procedure return, discarding global variable changes made inside procedures (e.g., `NextID += 1`). Now handled by procedure frames (see Language Semantics).

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
- **IF...THEN block form**: `IF expr THEN / stmts / END` (optional THEN before block body)
- **LOOP WHILE/UNTIL**: Added `loop_while(Cond, Body)` and `loop_until(Cond, Body)`
- **CYCLE/EXIT/DO**: Control flow statements for loops and routines
- **ROUTINE**: `Name ROUTINE` parsed alongside procedures
- **Modulo**: `%` operator at multiplication precedence
- **String concatenation**: `&` operator at addition precedence
- **Line continuation**: `|` at end of line continues to next line
- **STRING/SHORT/REAL types**: Added to type parser
- **PROCEDURE in MAP**: `Name PROCEDURE[(params)]` MAP entry syntax
- **Optional procedure params**: `Name PROCEDURE` without `(params)` in definitions
- **EQUATE declarations**: `Name EQUATE(Value)` parsed as named constants
- **Float literals**: `3.14`, `10000.0` etc. parsed alongside integers
- **Local DIM arrays**: `Name TYPE,DIM(Size)` in local variable declarations
- **Keyword-as-identifier**: `SIZE`, `ADDRESS`, `POINTER` removed from keyword blacklist so they can be used as variable names (e.g., `Size EQUATE(640)`)

### 7. Db parse gaps (2026-11-23)
Found by a parse-coverage survey:
- **COMPILE/OMIT**: new pre-pass module `clarion_preproc.pl` (`preprocess_codes/3`), called by `parse_clarion/2,3`. Conditions use `parse_clarion(Src, AST, [defines(['Name'=Val])])`; undefined names are 0. Dropped lines become blank lines, so line numbers are preserved.
- **LIKE(Ref)** locals, globals and QUEUE/GROUP fields, with `,PRE()`/`,DIM()`/`,OVER()` attributes. AST `like(Name, Ref, Attrs)` / `field(Name, like(Ref, Attrs))`. The bridge emits type `like(Ref)`, so the value starts at 0 (the referenced declaration is not resolved).
- **EQUATE('text')** string equates and `::` names (`NT::THIS_MODULE`). String equates bridge to `'STRING'` vars.
- **STRING('text')** initialiser (length = text length) for locals, globals and fields.
- **Omitted first argument** `f(, a)` produces `omitted`. The simulator binds the parameter's default value.
- **OROF** in CASE produces `of(any([R1,R2,...]), Stmts)`. The bridge expands it into one `case_of` per alternative.
- **`A[i].Field`** read/assign produces `array_field/3`, bridged to `array_field_access/3` and `array_field_assign/4`. It is evaluated only when the element is a `group_val`; otherwise the read gives 0 and the assign warns.
- **Keywords added:** `OROF`, `LIKE`, `EQUATE`.
- **Simulator:** a colon name whose prefix matches no file, group or instance (`Copy:Record`, `A::B`) is stored as a plain variable (`get_var`/`set_var` fall back when the prefixed lookup fails).
- **Tests:** `test_unified.pl` paths fixed (`../../../clarion_projects`). 49 file-based checks had been silently skipped. `run_test/1` now counts a test that throws or fails as FAIL.
- **Local QUEUE/GROUP:** `bridge_locals` emits `local_decl(queue(...))` / `local_decl(group(...))`; `init_locals` initialises them via `init_globals`. Caveat: a local QUEUE is stored as a file_state and is not discarded when the procedure returns.
- **NOT / `~expr`:** `not(E)` is bridged recursively, and `eval_full_expr(not(E))` evaluates the operand with `eval_full_expr`, so calls inside `~` work.
- **Result:** `Some_Db.clw` parses and bridges with no unhandled-node warnings. Executing it still needs the dependent declarations and stubs.

### 8. Implicit `#` variables and ODBC fixes (2026-11-24)
- **Implicit LONG `Name#`** (`SAV:PRE:EDIT_DATE#`, `i#`): `ident//1` keeps the trailing `#` in the name. `get_var`/`set_var` (simulator_state.pl) handle such names first: they bypass prefix/file/group lookup (so `PRE:X#` never touches the PRE group), read as 0 before first assignment, and truncate assigned values to an integer. `$` (REAL) and `"` (STRING) implicits are not handled yet.
- **storage_odbc.lgt**: `CLARION_ODBC_DSN` may be a DSN name or a full connection string (contains `=`, uses `odbc_driver_connect/3`); a connection string is logged as `<connection string>` so a password is never printed. (The write-through/data-safety rework of this backend came from PRs #18/#19.)

### 9. References (`&=`, `&Type`) and keyword table names (2026-11-24)
- **`Name &Type` locals** (`objLog &LogClass`, `FREF:Image &file`) parse as `ref_var(Name, Type)`, bridge to `local_var(Name, reference(Type), init(null))`, and start as `null`.
- **`Ref &= Target` statement** parses as `ref_assign(Var, Target)`. The bridge emits `ref_assign(Var, null | new(Class) | name(N) | expr(E))`. The simulator stores `null`, a new instance (`create_instance`, class must be declared), `ref(file(N))` for a FILE/QUEUE name, or a value copy otherwise. **Aliasing is not modelled**: two references to the same object hold independent copies.
- **`Ref &= NULL` / `A &= B` in expressions** parse as `ref_eq/2` (in `compare_rest`), bridged and evaluated as identity of the stored values.
- **Keyword table names**: `Prompt`, `Queue` and other keywords are accepted as `var(Name)` when one is a whole call argument (followed by `,` or `)`), via `kw_name_arg//1` in `primary//1` and the `DELETE(...)` statement. A keyword elsewhere in an expression is still rejected. `NOT/AND/OR/TO/OF/OROF` are excluded.

### 10. `*FILE` parameters (2026-11-24)
- **Parser:** `*FILE Name` in procedure and MAP parameter lists parses as `param(Name, ref(file))`. It is deliberately not part of `type//1`, so a FILE declaration is never read as a local.
- **Bridge:** `ref(file)` becomes the parameter type `file_ref`.
- **Calls:** `eval_call_args/4` passes an argument for a `file_ref` parameter as `ref(file(F))` when it names a FILE/QUEUE (or a variable that already holds a file reference) instead of evaluating it.
- **Builtins:** `resolve_file_ref_args/3` (in `exec_call`) rewrites `var(N)` to `var(F)` when N holds `ref(file(F))`, so `ADD/PUT/DELETE(P:File)` act on the real file and `ADDRESS(P:File) = ADDRESS(Item)`. This makes a `case address(P:File) / of address(Item)` dispatcher work.
- The pre-existing loss of callee state in expression calls is fixed; see section 11.

### 11. Calls inside expressions keep their effects (2026-11-24)
- **Bug:** `eval_full_expr(call(...))` ran `exec_call` and discarded its output state, so a procedure called inside an expression (`x# = Helper()`, `if DoAdd(Item)`, `return(DoAdd:Item(...))`, `loop while Bump() < 5`) lost its global/file/ERRORCODE changes. Only statement calls kept them. (A `LOOP WHILE F()` whose F changes a global never terminated.)
- **Fix:** new `eval_expr_st(+Expr, +S0, -S, -Value)` in simulator.pl threads state through `call`, `method_call`, `binop`, `not` and `ref_eq` (left to right, no short-circuit) and falls back to the pure `eval_full_expr/3` otherwise. Used by assign, `+=`, SELF/member/array assigns, `&= expr`, RETURN, IF/ELSIF conditions, CASE selector, LOOP TO bounds, LOOP WHILE/UNTIL conditions, and procedure argument evaluation (`eval_call_args/5`, `eval_args_st/4`).
- **Still pure (calls there lose their effects):** CASE `OF` labels, `bind_params` defaults, method-call argument lists and external-stub arguments (builtin arguments: see section 14).
- **Also fixed:** `exec_call` reset the caller's SELF context to `none` after any procedure call, so a method that called a procedure could no longer use `SELF`. The caller's SELF is now restored.

### 12. FILE declarations, unique keys, case-insensitive names, builtins (2026-11-24)
- **FILE declarations** (parser): KEYs are kept (they were parsed and discarded, so `GET(file, key)` on a declared FILE always failed), plus key `NAME()`, file flags (`THREAD`, `BINDABLE`, ...), `RECORD,PRE()`, field attributes (`NAME('x |NULLABLE')`, `DIM`, `OVER`, `BINARY`), inline `GROUP,PRE()` / `GROUP,DIM(n),OVER(x)`, `ULONG` (simulated as LONG), and a keyword as the FILE label (`Prompt FILE`, `Queue FILE`). A DIM'd group inside a record is flattened as a single element.
- **Unique keys**: `init_file` records keys without `DUP` as `file_unique_keys(File)`. `ADD`, and `PUT` onto another record's values, set ERRORCODE 40 (Creates Duplicate Key) and leave the file unchanged.
- **Case-insensitive names**: variables, file names, prefixes and record fields fall back to a case-insensitive match when the exact name is not found (e.g. `O:OPtionsMask` for a parameter declared `O:OptionsMask`, `PRE:EDIT_DATE` for a field `Edit_Date`). Caveat: a local whose name differs only in case from a global updates the global instead of shadowing it.
- **Builtins**: `BAND`, `BOR`, `BXOR`, `DATE(m,d,y)` (days since 28 Dec 1800, so `DATE(1,1,1801)` = 4), `NAME(file)` (returns the label, not the NAME() attribute), `ASSERT(cond[, msg])` (logs and continues). `TRUE`/`FALSE` are predefined when no variable has that name.

### 13. `ADDRESS` collisions (2026-11-24)
- `ADDRESS(var)` was the sum of the name's character codes, so anagram names (`Listen`/`Silent`) shared an address and a `case address(P:File)` dispatcher silently ran another file's branch. It is now the upper-cased name read as a base-256 number (+65536): injective and case-insensitive.

### 14. By-reference parameters and more parsing (2026-11-24)
- **`*T` parameters are aliases.** The bridge emits `byref(T)` for `*T` (`*FILE` stays `file_ref`). When the argument is a plain name (variable, record field, key, group), `eval_call_args/5` passes `alias(Target)`; `bind_param` binds it without writing through, `get_var`/`set_var` follow it (case-insensitively, `alias_of/3`), and `resolve_file_ref_args/3` resolves it for builtins (`GET(F, K)`, `CLEAR(R)`). Any other argument (literal, expression) is passed by value.
- **New parameter types:** `*KEY`, `*GROUP`, `*QUEUE`, `*?` and untyped `?`, also optional (`<*? X>`, `<? X>`).
- **`OMITTED(param)`**: `bind_params` records `'$omitted'(Name)` (1/0) for every parameter.
- **`DISPOSE(ref)`** sets the reference to NULL.
- **Scoping fix:** `merge_globals` ignored its parameter/local name lists, so a parameter or local with a global's name overwrote the global on return. Such names now keep the caller's value.
- **Global objects:** `Name ClassName` at module level (one line) creates an instance at init (`instance_global/2`).
- **`SELF.P += E`** and other `SELF.P` reads/assignments that arrive as plain names are bridged to `self_assign`/`self_access`.
- **Calls inside builtin arguments** (`LEN(CLIP(F()))`, `ABS(Bump(5))`): `exec_call` evaluates such arguments first with `eval_expr_st` (keeping their effects) and passes `evaluated(V)`. Previously the builtin failed and the call fell through to "undefined procedure".
- **Parser:** picture tokens as literals (`@n02`, `@d01`, `@t3`, `@P.###P`; `FORMAT` still ignores the picture), `,AUTO`/`,STATIC`/`,THREAD`/`,NAME()`/`,OVER()` on locals, `LIKE(PRE:Group.Field)`.
- **Case-insensitive procedure and key names** (`helper()` calls `Helper`, `GET(t, Tt:by_item_id)`), and `PRE:Group.Field` reads/writes the flattened record field.
- The "still pure" list in section 11 no longer includes builtin arguments.

### 15. Constructs from the project survey (2026-11-25)
- **Survey:** 50 of the 56 `.clw` files under `clarion_projects/` parse. The other six need `INCLUDE`, untyped parameters, `?Ctl{PROP:x}` reads, `WINDOW` menus / `LIST`, or `REPORT`.
- **Constant expressions:** `DIM()`, `EQUATE()`, initial values and string lengths accept EQUATEs. The grammar leaves `const(Expr)`; `resolve_constants/2` replaces it after parsing and throws `unknown_constant` for a name with no EQUATE before its use.
- **Declarations** may come before and after MAP. GROUP fields keep initial values (`field_init/3`, then `group_init/3`); on a RECORD or QUEUE they are ignored with a warning.
- **Statements:** `*=` `/=`, compound assignment to array elements (`array_update/5`, index evaluated once), `LOOP BY` / `TIMES`, leading `;`, a procedure called without parentheses (the name must be the whole statement), `S[a:b]` and `S[i]` on strings.
- **Expressions:** unary minus, `1.5E-3`.
- **Labels:** non-reserved words (`NAME`, `ADD`, `KEY`, ...) are ordinary identifiers. A program's own procedure hides a built-in of the same name, except when the first argument is a FILE or QUEUE.
- **REAL** values are always floats, so a whole REAL no longer divides as an integer; `SQRT` returns REAL; text shows `7`, not `7.0`.
- **GROUP fields** are reached by PRE or by group name. `G.Field` used to create a separate variable.
- **Limits:** arrays are lists, so large ones are slow (`DcInit` takes about 40 s; PenBeamIndens is not practical). `DIM` on a GROUP or RECORD field is parsed and dropped.

### 16. Running the projects' DLL tests without the DLL (2026-11-25)
- `python3 dll_standin/run_dll_test.py ../../../clarion_projects/dh-mtl/test_mtllib.py` runs a project's Python test with `ctypes` replaced, so `CDLL('X.dll')` runs `X.clw` in the simulator. Passing: OptimLib, MtlLib, RtModelLib, MathLib.
- Numbers only: buffers, pointers and structures raise `NotImplementedError`.
- A call the simulator cannot run stops the test. `--keep-going` returns 0 instead and always exits 1, because a check can pass by accident on that 0.

### 6. ADDRESS/MemCopy simulation
- `ADDRESS(var)` returns a unique deterministic ID per variable name (the upper-cased name as a base-256 number; see section 13)
- `MemCopy` (via `MODULE('kernel32')`) is the one external that needs no stub: a no-op in the simulator since Clarion code uses direct GROUP field assignments for the actual data movement; MemCopy only matters for passing structs to external callers via pointer

## Language Semantics (2026-11-24)

Expected values are Claude's understanding of Clarion and have not been checked against the compiler or the manual, except where a trace comparison covers them.

- **Calls in expressions** thread state (`eval_full_expr/4`), left to right, so side effects survive. `AND`/`OR` evaluate both sides.
- **Frames:** a procedure sees globals plus its own parameters and locals (`enter_frame`/`leave_frame`, `'$frame'` variable). Methods still see their caller's variables. A local QUEUE is kept with the files, so it is not per-call.
- **By reference** (`pass_args`): a plain name the procedure can also see (global, record field, key, file) is an alias. The caller's own variables, and a global hidden by one of the procedure's names, are copied in and copied back. Methods take parameters by value.
- **Implicit `Name#`** belongs to its procedure: a called procedure's `i#` is separate.
- **Merge note (2026-11-25):** sections 8-14 came from `4f8dde4`, which fixed several of the same things independently. Where they differ, this section is current: `eval_full_expr/4` replaced `eval_expr_st/4`, `bind_param`/`merge_globals` gave way to frames, `file_unique_keys` to `key_attrs`, and lookup fallbacks for case to respelling before parsing.
- **Case:** `clarion_preproc.pl` respells every word one way (first column-1 label, else first use) before parsing, so AST spelling can differ from the source.
- **Types:** `set_var` and buffer/group/array assignment convert to the declared type (`'$type'(Name)` variables). DECIMAL precision and `LIKE` are not applied.
- **Integer division** still truncates inside expressions; not yet checked against the compiler.
- **Keys** now reach the simulator as `key(Name, Fields)` + `key_attrs(Name, Attrs)`. Uniqueness is enforced in the built-ins.
- **SET/NEXT/PREVIOUS** use a per-file cursor, separate from the current record used by PUT/DELETE.
- **DOS driver** pointers are byte positions, others record numbers.
- **External procedures** (MODULE, source not loaded) throw `unresolved_external`. Supply results with `with_external_stubs(['Name' = Value], Goal)`; `default` gives the empty value of the return type.
- **Built-ins** that cannot handle their arguments throw `builtin_failed` instead of being reported as undefined procedures.

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

## Test Coverage (538 checks as of 2026-11-25)

- **Parser + Bridge** (11): MEMBER parse, MathLib, SensorLib, DiagnosisStore, FormDemo, OdbcStore, control_flow.clw PROGRAM
- **Arithmetic** (4): MathAdd, Multiply with various inputs
- **Control Flow** (9): IF/THEN, IF/ELSE, LOOP/BREAK, LOOP FOR, CASE with branches
- **File I/O - SensorLib** (8): Open, Add records, weighted average, cleanup, close
- **File I/O - DiagnosisStore** (3): Open, create diagnosis, close
- **Builtins** (5): SIZE, LOOP WHILE, LOOP UNTIL, modulo, string concat with LEN
- **GUI Form Simulation** (5): ACCEPT/CASE ACCEPTED(), equate mapping, event queue, FormDemo.clw end-to-end
- **ODBC Store** (7): Open, add readings, count, delete all, close (in-memory simulation)
- **ODBC Store, SQLite** (10): Round trip through the real ODBC backend; skipped if `library(odbc)` is missing or no `SQLite3` driver is registered in `odbcinst.ini` (macOS: `brew install unixodbc sqliteodbc`)
- **ODBC data safety, SQLite** (24): Load/connect/insert failures reach `ERRORCODE()`, write-through, undeclared columns and other writers' rows preserved, conflicts refused; skipped as above
- **Clarion dates** (12): Day-number and time conversion, endpoints, a full 400-year cycle round-trips
- **ODBC dates, SQLite** (29): Database date/time/datetime columns to `LONG`/`DATE`/`TIME`/`STRING` fields and back; inexact values refused with error 90; skipped as above
- **StatsLib** (3): CASE with range matching (OF 0 TO 10), Classify function
- **Qualified Names / Nested Groups** (5): Nested GROUP in FILE, nested GROUP in GROUP, QualNames.clw end-to-end (FILE+GROUP with sub-GROUPs and colon-chain prefixes)

## Running Tests

```bash
cd clarion_interpreters/unified
swipl -l test_unified.pl -g main -t halt
```
