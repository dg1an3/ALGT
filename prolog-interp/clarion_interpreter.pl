% clarion_interpreter.pl — AST interpreter for Clarion programs
%
% Takes an AST produced by clarion_parser.pl and executes it,
% with file I/O simulation and execution tracing.

:- module(clarion_interpreter, [
    exec_procedure/4,
    exec_program/3,
    init_file_io/0,
    set_events/1,
    set_trace/1,
    get_trace/1,
    clear_trace/0,
    print_trace/0
]).

:- set_prolog_flag(double_quotes, codes).

%% ==========================================================================
%% GUI event simulation state
%% ==========================================================================

:- dynamic event_queue/1.      % event_queue([Event, ...])
:- dynamic last_accepted/1.    % last_accepted(EquateNum)
:- dynamic equate_map/2.       % equate_map(Name, Number)

set_events(Events) :-
    retractall(event_queue(_)),
    assert(event_queue(Events)).

init_gui :-
    retractall(event_queue(_)),
    retractall(last_accepted(_)),
    retractall(equate_map(_, _)),
    assert(event_queue([])),
    assert(last_accepted(0)).

% Assign equate numbers to ?name references found in a window declaration
assign_equates([], _).
assign_equates([Control|Cs], N) :-
    ( control_equate(Control, Name) ->
        retractall(equate_map(Name, _)),
        assert(equate_map(Name, N)),
        N1 is N + 1,
        assign_equates(Cs, N1)
    ; assign_equates(Cs, N)
    ).

control_equate(entry(_, _, equate(Name)), Name).
control_equate(button(_, _, equate(Name)), Name).
control_equate(string_ctl(_, _, equate(Name)), Name).

%% exec_program(+AST, +Events, -Result)
%% Execute a PROGRAM-style AST with simulated GUI events.
exec_program(AST, Events, Result) :-
    init_gui,
    set_events(Events),
    AST = program(_, _, Globals, _, _),
    % Find and register window equates
    ( member(window(_, _, _, Controls), Globals) ->
        assign_equates(Controls, 1)
    ; true
    ),
    exec_procedure(AST, '_main', [], Result).

%% ==========================================================================
%% File I/O simulation state (persists across exec_procedure calls)
%% ==========================================================================

:- dynamic file_exists/1.      % file_exists(FileName)
:- dynamic file_records/2.     % file_records(FileName, [RecordValuesList, ...])
:- dynamic file_cursor/2.      % file_cursor(FileName, Position)  % 0 = before first
:- dynamic last_errorcode/1.   % last_errorcode(Code)

init_file_io :-
    retractall(file_exists(_)),
    retractall(file_records(_, _)),
    retractall(file_cursor(_, _)),
    retractall(last_errorcode(_)),
    assert(last_errorcode(0)).

set_errorcode(Code) :-
    retractall(last_errorcode(_)),
    assert(last_errorcode(Code)).

%% ==========================================================================
%% Execution trace state
%% ==========================================================================

:- dynamic trace_enabled/0.
:- dynamic trace_entry/1.

set_trace(on) :- retractall(trace_enabled), assert(trace_enabled).
set_trace(off) :- retractall(trace_enabled).

emit_trace(Entry) :- ( trace_enabled -> assert(trace_entry(Entry)) ; true ).

get_trace(Log) :- findall(E, trace_entry(E), Log).
clear_trace :- retractall(trace_entry(_)).

print_trace :-
    findall(E, trace_entry(E), Log),
    print_trace_entries(Log).

print_trace_entries([]).
print_trace_entries([E|Es]) :-
    print_trace_entry(E),
    print_trace_entries(Es).

print_trace_entry(proc_enter(Name, Args)) :-
    format("CALL ~w(", [Name]),
    print_args(Args),
    format(")~n").
print_trace_entry(proc_exit(_Name, Result)) :-
    format("  -> ~w~n", [Result]).
print_trace_entry(stmt(Name, Type, Details)) :-
    format("  ~w: ~w ~w~n", [Name, Type, Details]).

print_args([]).
print_args([A]) :- format("~w", [A]).
print_args([A,B|Rest]) :- format("~w, ", [A]), print_args([B|Rest]).

% Extract current procedure name from env (uses the most recent proc_enter trace)
trace_current_proc(_, ProcName) :-
    trace_enabled,
    !,
    ( predicate_property(trace_entry(_), defined),
      findall(N, trace_entry(proc_enter(N, _)), Ns),
      Ns \= [],
      last(Ns, ProcName) -> true
    ; ProcName = '?'
    ).
trace_current_proc(_, '?').

%% ==========================================================================
%% Statement-level call dispatch (handles file builtins + user procs)
%% ==========================================================================
%% exec_stmt_call(+Name, +RawArgs, +Env, -NewEnv)

exec_stmt_call('OPEN', [var(Name)], Env, Env) :- !,
    ( memberchk(program_ast(AST), Env),
      AST = program(_, _, Globals, _, _),
      member(window(Name, _, _, _), Globals)
    -> true  % Window open is a no-op
    ; ( file_exists(Name) -> set_errorcode(0)
      ; set_errorcode(2)  % File not found
      )
    ).

exec_stmt_call('CREATE', [var(FileName)], Env, Env) :- !,
    retractall(file_exists(FileName)),
    retractall(file_records(FileName, _)),
    assert(file_exists(FileName)),
    assert(file_records(FileName, [])),
    set_errorcode(0).

exec_stmt_call('CLOSE', [var(_Name)], Env, Env) :- !,
    set_errorcode(0).  % No-op for both files and windows

exec_stmt_call('SET', [var(FileName)], Env, Env) :- !,
    retractall(file_cursor(FileName, _)),
    assert(file_cursor(FileName, 0)).

exec_stmt_call('NEXT', [var(FileName)], Env, NewEnv) :- !,
    ( file_cursor(FileName, Pos) -> true ; Pos = 0 ),
    NextPos is Pos + 1,
    retractall(file_cursor(FileName, _)),
    assert(file_cursor(FileName, NextPos)),
    ( file_records(FileName, Records),
      nth1(NextPos, Records, Record) ->
        set_errorcode(0),
        memberchk(program_ast(AST), Env),
        AST = program(Files, _, _, _, _),
        memberchk(file(FileName, Prefix, _, Fields), Files),
        load_record_to_env(Prefix, Fields, Record, Env, NewEnv)
    ;
        set_errorcode(33),  % End of file
        NewEnv = Env
    ).

exec_stmt_call('ADD', [var(FileName)], Env, Env) :- !,
    memberchk(program_ast(AST), Env),
    AST = program(Files, _, _, _, _),
    memberchk(file(FileName, Prefix, _, Fields), Files),
    read_record_from_env(Prefix, Fields, Env, Record),
    ( file_records(FileName, Records) ->
        retractall(file_records(FileName, _)),
        append(Records, [Record], NewRecords),
        assert(file_records(FileName, NewRecords))
    ;
        assert(file_records(FileName, [Record]))
    ),
    set_errorcode(0).

exec_stmt_call('PUT', [var(FileName)], Env, Env) :- !,
    ( file_cursor(FileName, Pos), Pos > 0 ->
        memberchk(program_ast(AST), Env),
        AST = program(Files, _, _, _, _),
        memberchk(file(FileName, Prefix, _, Fields), Files),
        read_record_from_env(Prefix, Fields, Env, Record),
        file_records(FileName, Records),
        replace_nth1_list(Pos, Records, Record, NewRecords),
        retractall(file_records(FileName, _)),
        assert(file_records(FileName, NewRecords)),
        set_errorcode(0)
    ;
        set_errorcode(1)
    ).

exec_stmt_call('CLEAR', [var(RecRef)], Env, NewEnv) :- !,
    memberchk(program_ast(AST), Env),
    AST = program(Files, _, _, _, _),
    atom_codes(RecRef, RecRefCodes),
    ( append(PrefixCodes, [0':|_], RecRefCodes) ->
        atom_codes(Prefix, PrefixCodes),
        memberchk(file(_, Prefix, _, Fields), Files),
        clear_fields(Prefix, Fields, Env, NewEnv)
    ;
        NewEnv = Env
    ).

exec_stmt_call('MemCopy', _, Env, Env) :- !.

% User-defined procedure call (fallback)
exec_stmt_call(Name, Args, Env, Env) :-
    maplist(eval_in_env(Env), Args, ArgVals),
    memberchk(program_ast(AST), Env),
    exec_procedure(AST, Name, ArgVals, _).

%% ==========================================================================
%% File I/O helpers
%% ==========================================================================

load_record_to_env(_, [], [], Env, Env).
load_record_to_env(Prefix, [field(FName, _)|Fs], [V|Vs], Env, NewEnv) :-
    atomic_list_concat([Prefix, ':', FName], QName),
    update_env(QName, V, Env, Env1),
    load_record_to_env(Prefix, Fs, Vs, Env1, NewEnv).

read_record_from_env(_, [], _, []).
read_record_from_env(Prefix, [field(FName, _)|Fs], Env, [V|Vs]) :-
    atomic_list_concat([Prefix, ':', FName], QName),
    ( memberchk(QName=V, Env) -> true ; V = 0 ),
    read_record_from_env(Prefix, Fs, Env, Vs).

clear_fields(_, [], Env, Env).
clear_fields(Prefix, [field(FName, _)|Fs], Env, NewEnv) :-
    atomic_list_concat([Prefix, ':', FName], QName),
    update_env(QName, 0, Env, Env1),
    clear_fields(Prefix, Fs, Env1, NewEnv).

replace_nth1_list(1, [_|Rest], Elem, [Elem|Rest]) :- !.
replace_nth1_list(N, [X|Rest], Elem, [X|NewRest]) :-
    N > 1, N1 is N - 1,
    replace_nth1_list(N1, Rest, Elem, NewRest).

%% ==========================================================================
%% Procedure execution
%% ==========================================================================

exec_procedure(program(Files, Groups, Globals, Map, Procs), ProcName, ArgValues, Result) :-
    AST = program(Files, Groups, Globals, Map, Procs),
    memberchk(procedure(ProcName, Params, _RetType, Locals, Body), Procs),
    emit_trace(proc_enter(ProcName, ArgValues)),
    bind_params(Params, ArgValues, ParamEnv),
    init_locals(Locals, LocalEnv),
    init_globals(Globals, GlobalEnv),
    append(LocalEnv, ParamEnv, EnvL),
    append(GlobalEnv, EnvL, Env0),
    init_arrays(Globals, AST, ArrayEnv),
    append(ArrayEnv, Env0, Env1),
    Env = [program_ast(AST)|Env1],
    ( exec_body(Body, Env, _NewEnv, Result) -> true
    ; Result = void
    ),
    emit_trace(proc_exit(ProcName, Result)).

bind_params([], [], []).
bind_params([param(Name, _)|Ps], [V|Vs], [Name=V|Es]) :-
    bind_params(Ps, Vs, Es).

init_locals([], []).
init_locals([local(Name, _, Init)|Ls], [Name=Init|Es]) :-
    init_locals(Ls, Es).

init_globals([], []).
init_globals([global(Name, _, Init)|Gs], [Name=Init|Es]) :-
    init_globals(Gs, Es).
init_globals([_|Gs], Es) :- init_globals(Gs, Es).

init_arrays([], _, []).
init_arrays([array(Name, _, Size)|Gs], AST, [Name=Array|Es]) :-
    length(Array, Size),
    maplist(=(0), Array),
    init_arrays(Gs, AST, Es).
init_arrays([_|Gs], AST, Es) :- init_arrays(Gs, AST, Es).

%% ==========================================================================
%% Body execution
%% ==========================================================================

% exec_body(Statements, Env, NewEnv, Result)
exec_body([], Env, Env, _).

exec_body([return(Expr)|_], Env, Env, Result) :- !,
    eval(Expr, Env, Result),
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, return, Result)).

exec_body([assign(Var, Expr)|Rest], Env, FinalEnv, Result) :- !,
    eval(Expr, Env, Val),
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, assign, Var=Val)),
    update_env(Var, Val, Env, Env1),
    exec_body(Rest, Env1, FinalEnv, Result).

exec_body([if(Cond, Then, Else)|Rest], Env, FinalEnv, Result) :- !,
    eval(Cond, Env, Val),
    ( Val \= 0 -> Body = Then, Branch = true ; Body = Else, Branch = false ),
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, 'if', cond=Val/Branch)),
    ( exec_body(Body, Env, Env1, Result) ->
        ( nonvar(Result) -> FinalEnv = Env1
        ; exec_body(Rest, Env1, FinalEnv, Result)
        )
    ; exec_body(Rest, Env, FinalEnv, Result)
    ).

exec_body([loop(Body)|Rest], Env, FinalEnv, Result) :- !,
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, loop, enter)),
    exec_loop(Body, Env, Env1, LoopResult),
    emit_trace(stmt(ProcName, loop, exit)),
    ( LoopResult = return(R) -> Result = R, FinalEnv = Env1
    ; exec_body(Rest, Env1, FinalEnv, Result)
    ).

exec_body([loop_for(Var, Start, End, Body)|Rest], Env, FinalEnv, Result) :- !,
    eval(Start, Env, SVal),
    eval(End, Env, EVal),
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, loop_for, Var=SVal-EVal)),
    update_env(Var, SVal, Env, Env0),
    exec_loop_for(Var, EVal, Body, Env0, Env1, LoopResult),
    ( LoopResult = return(R) -> Result = R, FinalEnv = Env1
    ; exec_body(Rest, Env1, FinalEnv, Result)
    ).

exec_body([case(Expr, Ofs, Else)|Rest], Env, FinalEnv, Result) :- !,
    eval(Expr, Env, Val),
    ( find_of(Val, Ofs, Env, OfBody) -> Body = OfBody ; Body = Else ),
    ( exec_body(Body, Env, Env1, Result) ->
        ( nonvar(Result) -> FinalEnv = Env1
        ; exec_body(Rest, Env1, FinalEnv, Result)
        )
    ; exec_body(Rest, Env, FinalEnv, Result)
    ).

exec_body([call(Name, Args)|Rest], Env, FinalEnv, Result) :- !,
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, call, Name)),
    exec_stmt_call(Name, Args, Env, Env1),
    exec_body(Rest, Env1, FinalEnv, Result).

exec_body([accept(Body)|Rest], Env, FinalEnv, Result) :- !,
    exec_accept_loop(Body, Env, Env1, AcceptResult),
    ( AcceptResult = return(R) -> Result = R, FinalEnv = Env1
    ; exec_body(Rest, Env1, FinalEnv, Result)
    ).

exec_body([display|Rest], Env, FinalEnv, Result) :- !,
    exec_body(Rest, Env, FinalEnv, Result).

exec_body([break|_], Env, Env, break) :- !,
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, break, '')).

exec_body([_|Rest], Env, FinalEnv, Result) :-
    exec_body(Rest, Env, FinalEnv, Result).

%% ==========================================================================
%% ACCEPT loop execution (GUI event simulation)
%% ==========================================================================

% Consume events from the queue one at a time, execute the body for each.
% BREAK inside the body ends the accept loop.
exec_accept_loop(Body, Env, FinalEnv, Result) :-
    ( event_queue(Events), Events = [Event|RestEvents] ->
        retractall(event_queue(_)),
        assert(event_queue(RestEvents)),
        retractall(last_accepted(_)),
        assert(last_accepted(Event)),
        exec_body(Body, Env, Env1, BodyResult),
        ( BodyResult == break -> Result = ok, FinalEnv = Env1
        ; nonvar(BodyResult) -> Result = return(BodyResult), FinalEnv = Env1
        ; exec_accept_loop(Body, Env1, FinalEnv, Result)
        )
    ; Result = ok, FinalEnv = Env  % No more events, exit accept
    ).

%% ==========================================================================
%% Loop execution
%% ==========================================================================

% exec_loop(Body, Env, NewEnv, LoopResult)
exec_loop(Body, Env, FinalEnv, LoopResult) :-
    exec_body(Body, Env, Env1, Result),
    ( Result == break -> LoopResult = ok, FinalEnv = Env1
    ; nonvar(Result) -> LoopResult = return(Result), FinalEnv = Env1
    ; exec_loop(Body, Env1, FinalEnv, LoopResult)
    ).

% exec_loop_for(Var, EndVal, Body, Env, NewEnv, LoopResult)
exec_loop_for(Var, EndVal, Body, Env, FinalEnv, LoopResult) :-
    memberchk(Var=Current, Env),
    ( Current > EndVal -> LoopResult = ok, FinalEnv = Env
    ; exec_body(Body, Env, Env1, Result),
      ( Result == break -> LoopResult = ok, FinalEnv = Env1
      ; nonvar(Result) -> LoopResult = return(Result), FinalEnv = Env1
      ; Next is Current + 1,
        update_env(Var, Next, Env1, Env2),
        exec_loop_for(Var, EndVal, Body, Env2, FinalEnv, LoopResult)
      )
    ).

%% ==========================================================================
%% CASE helpers
%% ==========================================================================

find_of(Val, [of(Range, Body)|_], Env, Body) :-
    check_range(Val, Range, Env), !.
find_of(Val, [_|Os], Env, Body) :-
    find_of(Val, Os, Env, Body).

check_range(Val, single(E), Env) :-
    eval(E, Env, V), Val =:= V.
check_range(Val, range(S, E), Env) :-
    eval(S, Env, SVal), eval(E, Env, EVal),
    Val >= SVal, Val =< EVal.

%% ==========================================================================
%% Environment management
%% ==========================================================================

update_env(array_ref(Name, IndexExpr), Val, Env, NewEnv) :- !,
    eval(IndexExpr, Env, Index),
    ( memberchk(Name=Array, Env) ->
        ( Index > 0, update_nth1(Index, Array, Val, NewArray) ->
            update_env(Name, NewArray, Env, NewEnv)
        ; NewEnv = Env % Out of bounds
        )
    ; NewEnv = Env % Array not found
    ).
update_env(Var, Val, [Var=_|Env], [Var=Val|Env]) :- !.
update_env(Var, Val, [Other|Env], [Other|Env1]) :- update_env(Var, Val, Env, Env1).
update_env(Var, Val, [], [Var=Val]).

update_nth1(1, [_|Rest], Val, [Val|Rest]) :- !.
update_nth1(N, [X|Rest], Val, [X|NewRest]) :-
    N > 1, N1 is N - 1,
    update_nth1(N1, Rest, Val, NewRest).

%% ==========================================================================
%% Expression evaluation
%% ==========================================================================

eval(lit(N), _, N) :- !.
eval(var(Name), Env, V) :- !, (memberchk(Name=V, Env) -> true ; V = 0).
eval(array_ref(Name, IndexExpr), Env, V) :- !,
    eval(IndexExpr, Env, Index),
    ( memberchk(Name=Array, Env) ->
        ( Index > 0, nth1(Index, Array, V) -> true ; V = 0 )
    ; V = 0
    ).
eval(call('SIZE', [var(Name)]), Env, V) :- !,
    eval_size(Name, Env, V).
eval(call('ADDRESS', [_]), _, 1234) :- !. % Mock address
eval(call('POINTER', [_]), _, 1) :- !.    % Mock pointer
eval(call('TODAY', []), _, 80000) :- !.   % Mock date
eval(call('ERRORCODE', []), _, V) :- !,
    ( last_errorcode(V) -> true ; V = 0 ).
eval(call('ACCEPTED', []), _, V) :- !,
    ( last_accepted(V) -> true ; V = 0 ).
eval(equate(Name), _, V) :- !,
    ( equate_map(Name, V) -> true ; V = 0 ).
eval(call(Name, Args), Env, V) :- !,
    maplist(eval_in_env(Env), Args, ArgVals),
    ( memberchk(program_ast(AST), Env) -> true ; fail ),
    exec_procedure(AST, Name, ArgVals, V).
eval(add(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), V is VA + VB.
eval(sub(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), V is VA - VB.
eval(mul(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), V is VA * VB.
eval(div(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VB \= 0 -> V is VA // VB ; V = 0).
eval(and(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA \= 0, VB \= 0 -> V = 1 ; V = 0).
eval(or(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), ((VA \= 0 ; VB \= 0) -> V = 1 ; V = 0).
eval(eq(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA =:= VB -> V = 1 ; V = 0).
eval(neq(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA \= VB -> V = 1 ; V = 0).
eval(lt(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA < VB -> V = 1 ; V = 0).
eval(lte(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA =< VB -> V = 1 ; V = 0).
eval(gt(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA > VB -> V = 1 ; V = 0).
eval(gte(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), (VA >= VB -> V = 1 ; V = 0).

eval_in_env(Env, Expr, Val) :- eval(Expr, Env, Val).

eval_size(Name, Env, Size) :-
    memberchk(program_ast(program(Files, Groups, _Globals, _Map, _Procs)), Env),
    ( memberchk(group(Name, _, Fields), Groups) -> calc_fields_size(Fields, Size)
    ; memberchk(file(Name, _, _, Fields), Files) -> calc_fields_size(Fields, Size)
    ; Size = 4 % Default for LONG
    ).

calc_fields_size([], 0).
calc_fields_size([field(_, Type)|Fs], Size) :-
    type_size(Type, S1),
    calc_fields_size(Fs, S2),
    Size is S1 + S2.

type_size(long, 4).
type_size(cstring(N), N).
type_size(cstring, 1). % Minimal
