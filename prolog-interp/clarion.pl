% clarion.pl — DCG grammar for Clarion syntax + AST interpreter
%
% Two cleanly separated layers:
%   1. DCG grammar:  source text --> AST
%   2. Interpreter:  AST --> results

:- module(clarion, [
    parse_clarion/2,
    exec_procedure/4,
    program//1
]).

:- set_prolog_flag(double_quotes, codes).

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
%   Statements: return(Expr), assign(Var, Expr), if(Cond, Then, Else), loop(Body), break
%
%   Expressions: lit(N), var(Name), add(A,B), mul(A,B), eq(A,B), neq(A,B), lt(A,B), lte(A,B), gt(A,B), gte(A,B), call(Name, Args)

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

% Global variable: Name TYPE(Init)
top_decl_item(global(Name, Type, Init)) -->
    ident(Name), ws, type(Type), ws,
    "(", ws, number(Init), ws, ")".

partition_decls([], [], [], []).
partition_decls([file(N,P,A,F)|Is], [file(N,P,A,F)|Fs], Gs, Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([group(N,P,F)|Is], Fs, [group(N,P,F)|Gs], Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([global(N,T,I)|Is], Fs, Gs, [global(N,T,I)|Vs]) :-
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
    "(", ws, number(Init), ws, ")".

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

% LOOP / stmts / END
statement(loop(Body)) -->
    kw("LOOP"), ws,
    statements(Body), ws,
    kw("END").

statement(break) -->
    kw("BREAK").

statement(return(Expr)) -->
    kw("RETURN"), ws, "(", ws, expr(Expr), ws, ")".

statement(return(Expr)) -->
    kw("RETURN"), ws, expr(Expr).

statement(assign(Var, Expr)) -->
    ident(Var), ws, "=", ws, expr(Expr).

statement(assign(Var, add(var(Var), Expr))) -->
    ident(Var), ws, "+=", ws, expr(Expr).

statement(call(Name, Args)) -->
    word(Name), ws, "(", ws, expr_list(Args), ws, ")".

if_else(Stmts) --> kw("ELSE"), ws, statements(Stmts).
if_else([]) --> [].

%% --- Expressions ---

expr(E) --> compare_expr(E).

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
add_rest(E, E) --> [].

mul_expr(E) --> primary(L), ws, mul_rest(L, E).
mul_rest(L, E) --> "*", ws, primary(R), ws, mul_rest(mul(L, R), E).
mul_rest(E, E) --> [].

primary(lit(N))    --> number(N), !.
primary(call(Name, Args)) -->
    word(Name), ws, "(", ws, expr_list(Args), ws, ")", !.
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
               'ERRORCODE','TODAY','ADDRESS','SIZE','POINTER']).

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

exec_procedure(program(Files, Groups, Globals, Map, Procs), ProcName, ArgValues, Result) :-
    AST = program(Files, Groups, Globals, Map, Procs),
    memberchk(procedure(ProcName, Params, _RetType, Locals, Body), Procs),
    bind_params(Params, ArgValues, ParamEnv),
    init_locals(Locals, LocalEnv),
    init_globals(Globals, GlobalEnv),
    append(LocalEnv, ParamEnv, EnvL),
    append(GlobalEnv, EnvL, Env0),
    Env = [program_ast(AST)|Env0],
    ( exec_body(Body, Env, _NewEnv, Result) -> true
    ; Result = void % Procedures might not return anything
    ).

bind_params([], [], []).
bind_params([param(Name, _)|Ps], [V|Vs], [Name=V|Es]) :-
    bind_params(Ps, Vs, Es).

init_locals([], []).
init_locals([local(Name, _, Init)|Ls], [Name=Init|Es]) :-
    init_locals(Ls, Es).

init_globals([], []).
init_globals([global(Name, _, Init)|Gs], [Name=Init|Es]) :-
    init_globals(Gs, Es).

% exec_body(Statements, Env, NewEnv, Result)
exec_body([], Env, Env, _).

exec_body([return(Expr)|_], Env, Env, Result) :- !,
    eval(Expr, Env, Result).

exec_body([assign(Var, Expr)|Rest], Env, FinalEnv, Result) :- !,
    eval(Expr, Env, Val),
    update_env(Var, Val, Env, Env1),
    exec_body(Rest, Env1, FinalEnv, Result).

exec_body([if(Cond, Then, Else)|Rest], Env, FinalEnv, Result) :- !,
    eval(Cond, Env, Val),
    ( Val \= 0 -> Body = Then ; Body = Else ),
    ( exec_body(Body, Env, Env1, Result) ->
        ( nonvar(Result) -> FinalEnv = Env1 % Returned from IF
        ; exec_body(Rest, Env1, FinalEnv, Result)
        )
    ; exec_body(Rest, Env, FinalEnv, Result)
    ).

exec_body([loop(Body)|Rest], Env, FinalEnv, Result) :- !,
    exec_loop(Body, Env, Env1, LoopResult),
    ( LoopResult = return(R) -> Result = R, FinalEnv = Env1
    ; exec_body(Rest, Env1, FinalEnv, Result)
    ).

exec_body([call(Name, Args)|Rest], Env, FinalEnv, Result) :- !,
    eval(call(Name, Args), Env, _),
    exec_body(Rest, Env, FinalEnv, Result).

exec_body([break|_], Env, Env, break) :- !.

exec_body([_|Rest], Env, FinalEnv, Result) :-
    exec_body(Rest, Env, FinalEnv, Result).

% exec_loop(Body, Env, NewEnv, LoopResult)
exec_loop(Body, Env, FinalEnv, LoopResult) :-
    exec_body(Body, Env, Env1, Result),
    ( Result == break -> LoopResult = ok, FinalEnv = Env1
    ; nonvar(Result) -> LoopResult = return(Result), FinalEnv = Env1
    ; exec_loop(Body, Env1, FinalEnv, LoopResult)
    ).

update_env(Var, Val, [Var=_|Env], [Var=Val|Env]) :- !.
update_env(Var, Val, [Other|Env], [Other|Env1]) :- update_env(Var, Val, Env, Env1).
update_env(Var, Val, [], [Var=Val]).

eval(lit(N), _, N) :- !.
eval(var(Name), Env, V) :- !, (memberchk(Name=V, Env) -> true ; V = 0). % Default to 0 for uninit
eval(call('SIZE', [var(Name)]), Env, V) :- !,
    eval_size(Name, Env, V).
eval(call('ADDRESS', [_]), _, 1234). % Mock address
eval(call('POINTER', [_]), _, 1).    % Mock pointer
eval(call('TODAY', []), _, 80000).   % Mock date
eval(call('ERRORCODE', []), _, 1).    % Mock error to break loops
eval(call('SET', [_]), _, 0).
eval(call('NEXT', [_]), _, 1).
eval(call('OPEN', [_]), _, 0).
eval(call('CREATE', [_]), _, 0).
eval(call('CLOSE', [_]), _, 0).
eval(call('ADD', [_]), _, 0).
eval(call('PUT', [_]), _, 0).
eval(call('GET', [_, _]), _, 0).
eval(call('CLEAR', [var(Name)]), Env, 0) :- !,
    update_env(Name, 0, Env, _).
eval(call('MemCopy', [_, _, _]), _, 0).
eval(call(Name, Args), Env, V) :- !,
    maplist(eval_in_env(Env), Args, ArgVals),
    ( memberchk(program_ast(AST), Env) -> true ; fail ),
    exec_procedure(AST, Name, ArgVals, V).
eval(add(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), V is VA + VB.
eval(mul(A, B), Env, V) :- !, eval(A, Env, VA), eval(B, Env, VB), V is VA * VB.
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
