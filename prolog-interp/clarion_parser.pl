% clarion_parser.pl — DCG grammar for Clarion syntax → AST
%
% Parses Clarion .clw source text into an AST suitable for
% interpretation by clarion_interpreter.pl.

:- module(clarion_parser, [
    parse_clarion/2,
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
%   Statements: return(Expr), assign(Var, Expr), if(Cond, Then, Else),
%               loop(Body), loop_for(Var, Start, End, Body),
%               case(Expr, Ofs, Else), break
%
%   Expressions: lit(N), var(Name), array_ref(Name, Index),
%                add(A,B), sub(A,B), mul(A,B), div(A,B),
%                eq(A,B), neq(A,B), lt(A,B), lte(A,B), gt(A,B), gte(A,B),
%                call(Name, Args)

%% ==========================================================================
%% Entry point
%% ==========================================================================

parse_clarion(Source, AST) :-
    ( atom(Source) -> atom_codes(Source, Codes)
    ; string_to_list(Source, Codes)
    ),
    phrase(program(AST), Codes).

%% ==========================================================================
%% Top-level structure
%% ==========================================================================

program(program(Files, Groups, Globals, MapEntries, Procs)) -->
    ws, kw("MEMBER"), ws, "(", ws, ")", ws,
    top_decls(Files, Groups, Globals), ws,
    map_block(MapEntries), ws,
    procedures(Procs), ws.

% --- Top-level declarations (FILE, GROUP, global vars) ---

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

%% ==========================================================================
%% MAP block
%% ==========================================================================

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

%% ==========================================================================
%% Procedure definitions
%% ==========================================================================

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

%% ==========================================================================
%% Statements
%% ==========================================================================

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

%% ==========================================================================
%% Expressions
%% ==========================================================================

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

%% ==========================================================================
%% Lexical rules
%% ==========================================================================

% Case-insensitive keyword (must not be followed by ident char)
kw([]) --> \+ ( [C], { ident_cont(C) } ).
kw([]) --> [].
kw([K|Ks]) --> [C], { to_upper(C, U), to_upper(K, U) }, kw(Ks).

to_upper(C, U) :- C >= 0'a, C =< 0'z, !, U is C - 32.
to_upper(C, C).

% Word: any identifier-shaped token (including keywords)
word(Name) -->
    [C], { ident_start(C) },
    ident_rest(Cs),
    { atom_codes(Name, [C|Cs]) }.

% Identifier: word that is not a keyword
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
