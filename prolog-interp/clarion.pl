% clarion.pl — DCG grammar for Clarion syntax + AST interpreter
%
% Two cleanly separated layers:
%   1. DCG grammar:  source text --> AST
%   2. Interpreter:  AST --> results

:- module(clarion, [
    parse_clarion/2,
    exec_procedure/4,
    init_file_io/0,
    set_trace/1,
    get_trace/1,
    clear_trace/0,
    print_trace/0,
    program//1
]).

:- set_prolog_flag(double_quotes, codes).

%% File I/O simulation state (persists across exec_procedure calls)
:- dynamic file_exists/1.      % file_exists(FileName)
:- dynamic file_records/2.     % file_records(FileName, [RecordValuesList, ...])
:- dynamic file_cursor/2.      % file_cursor(FileName, Position)  % 0 = before first
:- dynamic last_errorcode/1.   % last_errorcode(Code)

%% Execution trace state
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
%% AST definition
%% ==========================================================================
%
%   program(Files, Groups, Globals, MapEntries, Procedures)
%
%   File declarations:
%     file(Name, Prefix, Attrs, Fields)
%
%   Group declarations:
%     group(Name, Prefix, Fields)
%
%   Global variables:
%     global(Name, Type, InitVal)
%
%   Map entries:
%     map_entry(Name, Params, RetType, Attrs)
%     module_entry(ModName, Entries)
%
%   Procedures:
%     procedure(Name, Params, ReturnType, Locals, Body)
%       Locals = [local(Name, Type, InitVal), ...]
%
%   Types: long, cstring(Size)
%
%   Statements: return(Expr), assign(Var, Expr), if(Cond, Then, Else), loop(Body), loop_for(Var, Start, End, Body), case(Expr, Ofs, Else), break
%
%   Expressions: lit(N), var(Name), array_ref(Name, Index), add(A,B), sub(A,B), mul(A,B), div(A,B), eq(A,B), neq(A,B), lt(A,B), lte(A,B), gt(A,B), gte(A,B), call(Name, Args)

%% ==========================================================================
%% DCG grammar
%% ==========================================================================

parse_clarion(Source, AST) :-
    ( atom(Source) -> atom_codes(Source, Codes)
    ; string_to_list(Source, Codes)
    ),
    phrase(program(AST), Codes).

% --- Top-level structure ---

program(program(Files, Groups, Globals, MapEntries, Procs)) -->
    ws, kw("MEMBER"), ws, "(", ws, ")", ws,
    top_decls(Files, Groups, Globals), ws,
    map_block(MapEntries), ws,
    procedures(Procs), ws.

% --- Top-level declarations (FILE, GROUP, global vars) ---
% Unified dispatch: peek at keyword after ident to decide which kind

top_decls(Files, Groups, Globals) -->
    top_decl_items(Items),
    { partition_decls(Items, Files, Groups, Globals) }.

top_decl_items([I|Is]) --> top_decl_item(I), !, ws, top_decl_items(Is).
top_decl_items([]) --> [].

% FILE declaration
top_decl_item(file(Name, Prefix, Attrs, Fields)) -->
    ident(Name), ws, kw("FILE"), ws, !,
    file_attrs(Attrs0, Prefix), ws,
    record_block(Fields), ws,
    kw("END"),
    { exclude_pre(Attrs0, Attrs) }.

% GROUP declaration
top_decl_item(group(Name, Prefix, Fields)) -->
    ident(Name), ws, kw("GROUP"), ws, !,
    group_attrs(Prefix), ws,
    field_list(Fields), ws,
    kw("END").

% Array declaration: Name TYPE,DIM(n)
top_decl_item(array(Name, Type, Size)) -->
    ident(Name), ws, type(Type), ws,
    ",", ws, kw("DIM"), ws, "(", ws, number(Size), ws, ")".

% Global variable: Name TYPE(Init)
top_decl_item(global(Name, Type, Init)) -->
    ident(Name), ws, type(Type), ws,
    ( "(", ws, number(Init), ws, ")" ; { Init = 0 } ).

partition_decls([], [], [], []).
partition_decls([file(N,P,A,F)|Is], [file(N,P,A,F)|Fs], Gs, Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([group(N,P,F)|Is], Fs, [group(N,P,F)|Gs], Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([global(N,T,I)|Is], Fs, Gs, [global(N,T,I)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([array(N,T,S)|Is], Fs, Gs, [array(N,T,S)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).

%% --- FILE attributes ---

file_attrs([A|As], Pre) -->
    ",", ws, file_attr(A, Pre0), ws,
    file_attrs_rest(As, Pre0, Pre).
file_attrs([], none) --> [].

file_attrs_rest([A|As], PreAcc, Pre) -->
    ",", ws, file_attr(A, Pre0), ws,
    { merge_pre(PreAcc, Pre0, PreAcc1) },
    file_attrs_rest(As, PreAcc1, Pre).
file_attrs_rest([], Pre, Pre) --> [].

file_attr(driver(Driver), none) -->
    kw("DRIVER"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(Driver, Cs) }.
file_attr(name(FName), none) -->
    kw("NAME"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(FName, Cs) }.
file_attr(create, none) --> kw("CREATE").
file_attr(pre(Pre), Pre) --> kw("PRE"), ws, "(", ws, ident(Pre), ws, ")".

merge_pre(none, none, none) :- !.
merge_pre(none, P, P) :- !.
merge_pre(P, none, P) :- !.
merge_pre(_, P, P).

exclude_pre([], []).
exclude_pre([pre(_)|As], Bs) :- !, exclude_pre(As, Bs).
exclude_pre([A|As], [A|Bs]) :- exclude_pre(As, Bs).

% RECORD block
record_block(Fields) -->
    word(_), ws, kw("RECORD"), ws,
    field_list(Fields), ws,
    kw("END").

%% --- GROUP attributes ---

group_attrs(Prefix) --> ",", ws, kw("PRE"), ws, "(", ws, ident(Prefix), ws, ")".
group_attrs(none) --> [].

%% --- Field list (shared by RECORD and GROUP) ---

field_list([F|Fs]) --> field_decl(F), !, ws, field_list(Fs).
field_list([]) --> [].

field_decl(field(Name, Type)) --> word(Name), ws, type(Type).

%% --- MAP block ---

map_block(Entries) -->
    kw("MAP"), ws,
    map_entries(Entries), ws,
    kw("END").

map_entries([E|Es]) --> map_entry_or_module(E), !, ws, map_entries(Es).
map_entries([]) --> [].

% MODULE('name') ... END
map_entry_or_module(module_entry(ModName, Entries)) -->
    kw("MODULE"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")", ws,
    map_entries(Entries), ws,
    kw("END"),
    { atom_codes(ModName, Cs) }.

% Regular map entry
map_entry_or_module(map_entry(Name, Params, RetType, Attrs)) -->
    ident(Name), ws, "(", ws, map_param_list(Params), ws, ")", ws,
    map_return_and_attrs(RetType, Attrs).

map_return_and_attrs(RetType, Attrs) -->
    ",", ws, map_ret_or_attr(RetType, Attrs).
map_return_and_attrs(void, []) --> [].

map_ret_or_attr(RetType, Attrs) -->
    type(RetType), !, ws, map_attrs(Attrs).
map_ret_or_attr(void, [Attr|Attrs]) -->
    map_attr(Attr), ws, map_attrs(Attrs).

map_attrs([A|As]) --> ",", ws, map_attr(A), !, ws, map_attrs(As).
map_attrs([]) --> [].

map_attr(c) --> kw("C").
map_attr(raw) --> kw("RAW").
map_attr(pascal) --> kw("PASCAL").
map_attr(private) --> kw("PRIVATE").
map_attr(export) --> kw("EXPORT").
map_attr(name(N)) -->
    kw("NAME"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(N, Cs) }.

% MAP parameter list
map_param_list([P|Ps]) --> map_param(P), ws, map_param_list_rest(Ps).
map_param_list([]) --> [].

map_param_list_rest([P|Ps]) --> ",", ws, map_param(P), ws, map_param_list_rest(Ps).
map_param_list_rest([]) --> [].

map_param(param(Name, ref(Type))) --> "*", ws, type(Type), ws, opt_ident(Name).
map_param(param(Name, Type)) --> type(Type), ws, opt_ident(Name).

opt_ident(Name) --> ident(Name), !.
opt_ident(anonymous) --> [].

%% --- Procedure definitions ---

procedures([P|Ps]) --> procedure(P), !, ws, procedures(Ps).
procedures([]) --> [].

procedure(procedure(Name, Params, RetType, Locals, Body)) -->
    ident(Name), ws,
    kw("PROCEDURE"), ws, "(", ws, proc_param_list(Params), ws, ")", ws,
    return_type(RetType), ws,
    local_vars(Locals), ws,
    kw("CODE"), ws,
    statements(Body).

return_type(RetType) --> ",", ws, type(RetType), ws.
return_type(void) --> [].

% Local variables between PROCEDURE line and CODE
local_vars([L|Ls]) --> local_var(L), !, ws, local_vars(Ls).
local_vars([]) --> [].

local_var(local(Name, Type, Init)) -->
    word(Name), ws, type(Type), ws,
    ( "(", ws, number(Init), ws, ")" ; { Init = 0 } ).

%% --- Procedure parameter list ---

proc_param_list([P|Ps]) --> proc_param(P), ws, proc_param_list_rest(Ps).
proc_param_list([]) --> [].

proc_param_list_rest([P|Ps]) --> ",", ws, proc_param(P), ws, proc_param_list_rest(Ps).
proc_param_list_rest([]) --> [].

proc_param(param(Name, ref(Type))) --> "*", ws, type(Type), ws, ident(Name).
proc_param(param(Name, Type)) --> type(Type), ws, ident(Name).

%% --- Types ---

type(long) --> kw("LONG").
type(cstring(Size)) --> kw("CSTRING"), ws, "(", ws, number(Size), ws, ")".
type(cstring) --> kw("CSTRING").

%% --- Statements ---

statements([S|Ss]) --> statement(S), !, ws, statements(Ss).
statements([]) --> [].

statement(if(Cond, [Then], [])) -->
    kw("IF"), ws, expr(Cond), ws, kw("THEN"), ws, statement(Then), ws, ".".

% IF expr / stmts / [ELSE / stmts] / END
statement(if(Cond, Then, Else)) -->
    kw("IF"), ws, expr(Cond), ws,
    statements(Then), ws,
    if_else(Else), ws,
    kw("END").

% LOOP var = start TO end / stmts / END
statement(loop_for(Var, Start, End, Body)) -->
    kw("LOOP"), ws, ident(Var), ws, "=", ws, expr(Start), ws, kw("TO"), ws, expr(End), ws,
    statements(Body), ws,
    kw("END").

% LOOP / stmts / END
statement(loop(Body)) -->
    kw("LOOP"), ws,
    statements(Body), ws,
    kw("END").

% CASE expr / OF val / stmts / ... / ELSE / stmts / END
statement(case(Expr, Ofs, Else)) -->
    kw("CASE"), ws, expr(Expr), ws,
    of_blocks(Ofs), ws,
    case_else(Else), ws,
    kw("END").

statement(break) -->
    kw("BREAK").

statement(return(Expr)) -->
    kw("RETURN"), ws, expr(Expr).

statement(assign(array_ref(Name, Index), Expr)) -->
    ident(Name), ws, "[", ws, expr(Index), ws, "]", ws, "=", ws, expr(Expr).

statement(assign(Var, Expr)) -->
    ident(Var), ws, "=", ws, expr(Expr).

statement(assign(Var, add(var(Var), Expr))) -->
    ident(Var), ws, "+=", ws, expr(Expr).

statement(call(Name, Args)) -->
    word(Name), ws, "(", ws, expr_list(Args), ws, ")".

if_else(Stmts) --> kw("ELSE"), ws, statements(Stmts).
if_else([]) --> [].

of_blocks([O|Os]) --> of_block(O), ws, of_blocks(Os).
of_blocks([]) --> [].

of_block(of(Range, Stmts)) -->
    kw("OF"), ws, range(Range), ws, statements(Stmts).

range(range(Start, End)) --> expr(Start), ws, kw("TO"), ws, expr(End).
range(single(Val)) --> expr(Val).

case_else(Stmts) --> kw("ELSE"), ws, statements(Stmts).
case_else([]) --> [].

%% --- Expressions ---

expr(E) --> or_expr(E).

or_expr(E) --> and_expr(L), ws, or_rest(L, E).
or_rest(L, or(L, R)) --> kw("OR"), ws, and_expr(R).
or_rest(E, E) --> [].

and_expr(E) --> compare_expr(L), ws, and_rest(L, E).
and_rest(L, and(L, R)) --> kw("AND"), ws, compare_expr(R).
and_rest(E, E) --> [].

compare_expr(E) --> add_expr(L), ws, compare_rest(L, E).
compare_rest(L, eq(L, R)) --> "=", ws, add_expr(R).
compare_rest(L, neq(L, R)) --> "<>", ws, add_expr(R).
compare_rest(L, lt(L, R)) --> "<", ws, add_expr(R).
compare_rest(L, lte(L, R)) --> "<=", ws, add_expr(R).
compare_rest(L, gt(L, R)) --> ">", ws, add_expr(R).
compare_rest(L, gte(L, R)) --> ">=", ws, add_expr(R).
compare_rest(E, E) --> [].

add_expr(E) --> mul_expr(L), ws, add_rest(L, E).
add_rest(L, E) --> "+", ws, mul_expr(R), ws, add_rest(add(L, R), E).
add_rest(L, E) --> "-", ws, mul_expr(R), ws, add_rest(sub(L, R), E).
add_rest(E, E) --> [].

mul_expr(E) --> primary(L), ws, mul_rest(L, E).
mul_rest(L, E) --> "*", ws, primary(R), ws, mul_rest(mul(L, R), E).
mul_rest(L, E) --> "/", ws, primary(R), ws, mul_rest(div(L, R), E).
mul_rest(E, E) --> [].

primary(lit(N))    --> number(N), !.
primary(lit(S))    --> "'", qchars(Cs), "'", { atom_codes(S, Cs) }, !.
primary(call(Name, Args)) -->
    word(Name), ws, "(", ws, expr_list(Args), ws, ")", !.
primary(array_ref(Name, Index)) -->
    ident(Name), ws, "[", ws, expr(Index), ws, "]", !.
primary(var(Name)) --> ident(Name), !.
primary(E)         --> "(", ws, expr(E), ws, ")".

expr_list([E|Es]) --> expr(E), ws, expr_list_rest(Es).
expr_list([]) --> [].

expr_list_rest([E|Es]) --> ",", ws, expr(E), ws, expr_list_rest(Es).
expr_list_rest([]) --> [].

%% --- Lexical rules ---

% Case-insensitive keyword (must not be followed by ident char)
kw([]) --> \+ ( [C], { ident_cont(C) } ).
kw([]) --> [].
kw([K|Ks]) --> [C], { to_upper(C, U), to_upper(K, U) }, kw(Ks).

to_upper(C, U) :- C >= 0'a, C =< 0'z, !, U is C - 32.
to_upper(C, C).

% Word: any identifier-shaped token (including keywords)
% Used for labels, field names, record names where keywords are valid names
word(Name) -->
    [C], { ident_start(C) },
    ident_rest(Cs),
    { atom_codes(Name, [C|Cs]) }.

% Identifier: word that is not a keyword
% Used where keywords would be ambiguous (var names, proc names)
ident(Name) -->
    word(Part1),
    ( ":", word(Part2) -> { atomic_list_concat([Part1, ':', Part2], Name) }
    ; { Name = Part1 }
    ),
    { \+ is_keyword(Name) }.

ident_start(C) :- C >= 0'a, C =< 0'z.
ident_start(C) :- C >= 0'A, C =< 0'Z.
ident_start(0'_).

ident_rest([C|Cs]) --> [C], { ident_cont(C) }, !, ident_rest(Cs).
ident_rest([]) --> [].

ident_cont(C) :- ident_start(C).
ident_cont(C) :- C >= 0'0, C =< 0'9.

is_keyword(Name) :-
    upcase_atom(Name, U),
    member(U, ['MEMBER','MAP','END','PROCEDURE','CODE','RETURN',
               'LONG','CSTRING','C','NAME','EXPORT','FILE','DRIVER',
               'CREATE','PRE','RECORD','GROUP','MODULE','RAW','PASCAL',
               'PRIVATE','IF','THEN','ELSE','LOOP','BREAK','SET',
               'NEXT','OPEN','CLOSE','GET','PUT','ADD','CLEAR',
               'ERRORCODE','TODAY','ADDRESS','SIZE','POINTER',
               'TO','CASE','OF','DIM','AND','OR']).

% Integer literal
number(N) -->
    ( "-", { Sign = [0'-] } ; { Sign = [] } ),
    digit(D), digits(Ds),
    { append(Sign, [D|Ds], Codes), number_codes(N, Codes) }.

digit(D) --> [D], { D >= 0'0, D =< 0'9 }.
digits([D|Ds]) --> digit(D), !, digits(Ds).
digits([]) --> [].

% Quoted characters (returns code list)
qchars([C|Cs]) --> [C], { C \= 0'' }, !, qchars(Cs).
qchars([]) --> [].

% Whitespace and comments
ws --> [C], { C =< 32 }, !, ws.
ws --> "!", comment_body, !, ws.
ws --> [].

comment_body --> "\n", !.
comment_body --> [_], !, comment_body.
comment_body --> [].

%% ==========================================================================
%% Interpreter
%% ==========================================================================

%% --- File I/O initialization ---

init_file_io :-
    retractall(file_exists(_)),
    retractall(file_records(_, _)),
    retractall(file_cursor(_, _)),
    retractall(last_errorcode(_)),
    assert(last_errorcode(0)).

set_errorcode(Code) :-
    retractall(last_errorcode(_)),
    assert(last_errorcode(Code)).

%% --- Statement-level call dispatch (handles file builtins + user procs) ---
%% exec_stmt_call(+Name, +RawArgs, +Env, -NewEnv)

exec_stmt_call('OPEN', [var(FileName)], Env, Env) :- !,
    ( file_exists(FileName) -> set_errorcode(0)
    ; set_errorcode(2)  % File not found
    ).

exec_stmt_call('CREATE', [var(FileName)], Env, Env) :- !,
    retractall(file_exists(FileName)),
    retractall(file_records(FileName, _)),
    assert(file_exists(FileName)),
    assert(file_records(FileName, [])),
    set_errorcode(0).

exec_stmt_call('CLOSE', [var(_FileName)], Env, Env) :- !,
    set_errorcode(0).

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

%% --- File I/O helpers ---

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

exec_body([break|_], Env, Env, break) :- !,
    trace_current_proc(Env, ProcName),
    emit_trace(stmt(ProcName, break, '')).

exec_body([_|Rest], Env, FinalEnv, Result) :-
    exec_body(Rest, Env, FinalEnv, Result).

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

find_of(Val, [of(Range, Body)|_], Env, Body) :-
    check_range(Val, Range, Env), !.
find_of(Val, [_|Os], Env, Body) :-
    find_of(Val, Os, Env, Body).

check_range(Val, single(E), Env) :-
    eval(E, Env, V), Val =:= V.
check_range(Val, range(S, E), Env) :-
    eval(S, Env, SVal), eval(E, Env, EVal),
    Val >= SVal, Val =< EVal.

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

eval(lit(N), _, N) :- !.
eval(var(Name), Env, V) :- !, (memberchk(Name=V, Env) -> true ; V = 0). % Default to 0 for uninit
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
