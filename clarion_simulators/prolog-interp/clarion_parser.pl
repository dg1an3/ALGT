% clarion_parser.pl — DCG grammar for Clarion syntax → AST
%
% Parses Clarion .clw source text into an AST suitable for
% interpretation by clarion_interpreter.pl.
%
% Changes from v1:
%   1. Line continuation '|' stripped in ws — allows multi-line procedure
%      signatures like  procedure(arg1,  |
%                                 arg2)
%   2. MEMBER('filename') — optional filename accepted in MEMBER declaration
%   3. Expanded type system: SHORT, BYTE, ULONG, REAL, DATE, TIME,
%      STRING(n), PDECIMAL(p,s), LIKE(field), and user_type(Name) catch-all
%   4. Variable attribute chain on global/local/field declarations:
%        THREAD, EXTERNAL, STATIC, DLL(mode), OVER(target), NAME('x'), PRE(x)
%      AST nodes updated: global/4, local/4, field/3
%   (bonus) EQUATE(val) top-level declarations → equate(Name, Val)
%   (bonus) INCLUDE('file') top-level declarations → include(File)
%   (bonus) QUEUE blocks at top-level and as local vars → queue(Name, Pre, Fields)
%   (bonus) Qualified identifiers: A:B and A::B

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
%   Group/Queue declarations (both go in Groups list):
%     group(Name, Prefix, Fields)
%     queue(Name, Prefix, Fields)
%
%   Global declarations (go in Globals list):
%     global(Name, Type, InitVal, Attrs)     — Attrs: [thread,external,dll(M),over(T),...]
%     equate(Name, Val)                      — Name EQUATE(Val)
%     include(File)                          — INCLUDE('file')
%     array(Name, Type, Size)
%
%   Map entries:
%     map_entry(Name, Params, RetType, Attrs)
%     module_entry(ModName, Entries)
%
%   Procedures:
%     procedure(Name, Params, ReturnType, Locals, Body)
%       Locals = [local(Name, Type, InitVal, Attrs), ...]
%                 or queue(Name, Pre, Fields)
%
%   Fields (in FILE RECORD, GROUP, QUEUE):
%     field(Name, Type, Attrs)
%
%   Types: long, short, byte, ulong, real, date, time,
%          string(N), cstring(N), cstring, pdecimal(P,S),
%          like(FieldName), user_type(Name)
%
%   Variable attributes: thread, external, static, dll(Mode),
%                        over(Target), name(N), pre(P)

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

% MEMBER('file') or MEMBER() form (DLLs / member files)
program(program(Files, Groups, Globals, MapEntries, Procs)) -->
    ws, kw("MEMBER"), ws, "(", ws, member_file(_), ws, ")", ws,
    top_decls(Files, Groups, Globals), ws,
    map_block(MapEntries), ws,
    procedures(Procs), ws.

% PROGRAM form (EXE with inline CODE — globals after MAP)
program(program(Files, Groups, Globals, MapEntries, [MainProc])) -->
    ws, kw("PROGRAM"), ws,
    map_block(MapEntries), ws,
    top_decls(Files, Groups, Globals), ws,
    kw("CODE"), ws,
    statements(Body), ws,
    { MainProc = procedure('_main', [], void, [], Body) }.

% PROGRAM form with globals before MAP (Mosaiq-style — no CODE section)
program(program(Files, Groups, Globals, MapEntries, [])) -->
    ws, kw("PROGRAM"), ws,
    top_decls(Files, Groups, Globals), ws,
    map_block(MapEntries), ws.

%% Optional filename in MEMBER declaration

member_file(File) --> "'", qchars(Cs), "'", { atom_codes(File, Cs) }, !.
member_file(none) --> [].

%% ==========================================================================
%% Top-level declarations
%% ==========================================================================

top_decls(Files, Groups, Globals) -->
    top_decl_items(Items),
    { partition_decls(Items, Files, Groups, Globals) }.

top_decl_items([I|Is]) --> top_decl_item(I), !, ws, top_decl_items(Is).
top_decl_items([]) --> [].

% INCLUDE('file') or INCLUDE('file','scope')
top_decl_item(include(File)) -->
    kw("INCLUDE"), ws, "(", ws, "'", qchars(Cs), "'", ws,
    ( ",", ws, "'", qchars(_), "'" ; [] ), ws,
    ")",
    { atom_codes(File, Cs) }.

% EQUATE declaration: Name EQUATE(val)
top_decl_item(equate(Name, Val)) -->
    ident(Name), ws, kw("EQUATE"), ws, "(", ws, equate_val(Val), ws, ")".

% FILE declaration
top_decl_item(file(Name, Prefix, Attrs, Fields)) -->
    ident(Name), ws, kw("FILE"), ws, !,
    file_attrs(Attrs0, Prefix), ws,
    key_decls(_Keys), ws,
    record_block(Fields), ws,
    kw("END"),
    { exclude_pre(Attrs0, Attrs) }.

% GROUP declaration
top_decl_item(group(Name, Prefix, Fields)) -->
    ident(Name), ws, kw("GROUP"), ws, !,
    group_attrs(Prefix), ws,
    field_list(Fields), ws,
    kw("END").

% QUEUE declaration
top_decl_item(queue(Name, Prefix, Fields)) -->
    ident(Name), ws, kw("QUEUE"), ws, !,
    queue_attrs(Prefix), ws,
    field_list(Fields), ws,
    kw("END").

% WINDOW declaration
top_decl_item(window(Name, Title, Attrs, Controls)) -->
    ident(Name), ws, kw("WINDOW"), ws, !,
    "(", ws, "'", qchars(TCs), "'", ws, ")", ws,
    window_attrs(Attrs), ws,
    control_list(Controls), ws,
    kw("END"),
    { atom_codes(Title, TCs) }.

% Array declaration: Name TYPE,DIM(n)
top_decl_item(array(Name, Type, Size)) -->
    ident(Name), ws, type(Type), ws,
    ",", ws, kw("DIM"), ws, "(", ws, number(Size), ws, ")".

% Global variable: Name TYPE[(Init)] [,attrs...]
top_decl_item(global(Name, Type, Init, Attrs)) -->
    ident(Name), ws, type(Type), ws,
    var_init(Init), ws,
    var_attrs(Attrs).

%% EQUATE value: number, string, or identifier (including keywords like TRUE/FALSE)

equate_val(N) --> number(N), !.
equate_val(S) --> "'", qchars(Cs), "'", !, { atom_codes(S, Cs) }.
equate_val(V) --> word(V).

%% ==========================================================================
%% Variable init and attribute chain
%% ==========================================================================

% Optional initial value in parentheses
var_init(S) --> "(", ws, "'", qchars(Cs), "'", ws, ")", !, { atom_codes(S, Cs) }.
var_init(N) --> "(", ws, number(N), ws, ")", !.
var_init(0) --> [].

% Comma-separated attribute list
var_attrs([A|As]) --> ",", ws, var_attr(A), !, ws, var_attrs(As).
var_attrs([]) --> [].

var_attr(thread)       --> kw("THREAD").
var_attr(external)     --> kw("EXTERNAL").
var_attr(static)       --> kw("STATIC").
var_attr(dll(Mode))    --> kw("DLL"), ws, "(", ws, ident(Mode), ws, ")".
var_attr(over(Target)) --> kw("OVER"), ws, "(", ws, ident(Target), ws, ")".
var_attr(name(N))      --> kw("NAME"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
                           { atom_codes(N, Cs) }.
var_attr(pre(P))       --> kw("PRE"), ws, "(", ws, ident(P), ws, ")".

%% ==========================================================================
%% WINDOW attributes and controls
%% ==========================================================================

window_attrs([A|As]) --> ",", ws, window_attr(A), ws, window_attrs(As).
window_attrs([]) --> [].

window_attr(at(X, Y, W, H)) -->
    kw("AT"), ws, "(", ws, opt_number(X), ws, ",", ws, opt_number(Y), ws,
    ",", ws, number(W), ws, ",", ws, number(H), ws, ")".
window_attr(center) --> kw("CENTER").

opt_number(N) --> number(N), !.
opt_number(0) --> [].

control_list([C|Cs]) --> control_decl(C), !, ws, control_list(Cs).
control_list([]) --> [].

control_decl(prompt(Text, Attrs)) -->
    kw("PROMPT"), ws, "(", ws, "'", qchars(TCs), "'", ws, ")", ws,
    control_attrs(Attrs),
    { atom_codes(Text, TCs) }.

control_decl(entry(Format, Attrs, UseVar)) -->
    kw("ENTRY"), ws, "(", ws, format_picture(Format), ws, ")", ws,
    control_attrs_with_use(Attrs, UseVar).

control_decl(button(Text, Attrs, UseRef)) -->
    kw("BUTTON"), ws, "(", ws, "'", qchars(TCs), "'", ws, ")", ws,
    control_attrs_with_use(Attrs, UseRef),
    { atom_codes(Text, TCs) }.

control_decl(string_ctl(Format, Attrs, UseVar)) -->
    kw("STRING"), ws, "(", ws, format_picture(Format), ws, ")", ws,
    control_attrs_with_use(Attrs, UseVar).

control_decl(string_ctl(Text, Attrs, UseVar)) -->
    kw("STRING"), ws, "(", ws, "'", qchars(TCs), "'", ws, ")", ws,
    control_attrs_with_use(Attrs, UseVar),
    { atom_codes(Text, TCs) }.

control_decl(list_ctl(Attrs, UseRef, Drop, Items)) -->
    kw("LIST"), ws,
    control_attrs_with_use(AllAttrs, UseRef),
    { extract_list_attrs(AllAttrs, Drop, Items, Attrs) }.

format_picture(Format) -->
    "@", [T], { T >= 0'a, T =< 0'z ; T >= 0'A, T =< 0'Z },
    digits(Ds), { Ds \= [] },
    { atom_codes(Format, [0'@, T | Ds]) }.

control_attrs([A|As]) --> ",", ws, control_attr(A), ws, control_attrs(As).
control_attrs([]) --> [].

control_attrs_with_use(Attrs, UseRef) -->
    control_attrs(AllAttrs),
    { select(use(UseRef), AllAttrs, Attrs) -> true
    ; Attrs = AllAttrs, UseRef = none
    }.

control_attr(at(X, Y, W, H)) -->
    kw("AT"), ws, "(", ws, number(X), ws, ",", ws, number(Y), ws,
    ",", ws, number(W), ws, ",", ws, number(H), ws, ")".
control_attr(at(X, Y)) -->
    kw("AT"), ws, "(", ws, number(X), ws, ",", ws, number(Y), ws, ")".
control_attr(use(Ref)) -->
    kw("USE"), ws, "(", ws, use_ref(Ref), ws, ")".
control_attr(drop(N)) -->
    kw("DROP"), ws, "(", ws, number(N), ws, ")".
control_attr(from(Items)) -->
    kw("FROM"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(ItemStr, Cs), split_pipe(ItemStr, Items) }.

split_pipe(Atom, Items) :-
    atom_codes(Atom, Codes),
    split_pipe_codes(Codes, Items).
split_pipe_codes([], []) :- !.
split_pipe_codes(Codes, [Item|Rest]) :-
    ( append(Before, [0'||After], Codes) ->
        atom_codes(Item, Before),
        split_pipe_codes(After, Rest)
    ; atom_codes(Item, Codes),
      Rest = []
    ).

extract_list_attrs(AllAttrs, Drop, Items, RestAttrs) :-
    ( select(drop(Drop), AllAttrs, A1) -> true ; Drop = 1, A1 = AllAttrs ),
    ( select(from(Items), A1, RestAttrs) -> true ; Items = [], RestAttrs = A1 ).

use_ref(equate(Name)) --> "?", word(Name).
use_ref(var(Name)) --> ident(Name).

%% ==========================================================================
%% Partition top-level declarations into program/5 slots
%% ==========================================================================

partition_decls([], [], [], []).
partition_decls([file(N,P,A,F)|Is], [file(N,P,A,F)|Fs], Gs, Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([group(N,P,F)|Is], Fs, [group(N,P,F)|Gs], Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([queue(N,P,F)|Is], Fs, [queue(N,P,F)|Gs], Vs) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([global(N,T,I,A)|Is], Fs, Gs, [global(N,T,I,A)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([equate(N,V)|Is], Fs, Gs, [equate(N,V)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([include(F)|Is], Fs2, Gs, [include(F)|Vs]) :-
    partition_decls(Is, Fs2, Gs, Vs).
partition_decls([array(N,T,S)|Is], Fs, Gs, [array(N,T,S)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).
partition_decls([window(N,T,A,C)|Is], Fs, Gs, [window(N,T,A,C)|Vs]) :-
    partition_decls(Is, Fs, Gs, Vs).

%% ==========================================================================
%% FILE attributes
%% ==========================================================================

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
file_attr(owner(Owner), none) -->
    kw("OWNER"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(Owner, Cs) }.
file_attr(pre(Pre), Pre) --> kw("PRE"), ws, "(", ws, ident(Pre), ws, ")".

merge_pre(none, none, none) :- !.
merge_pre(none, P, P) :- !.
merge_pre(P, none, P) :- !.
merge_pre(_, P, P).

exclude_pre([], []).
exclude_pre([pre(_)|As], Bs) :- !, exclude_pre(As, Bs).
exclude_pre([A|As], [A|Bs]) :- exclude_pre(As, Bs).

%% KEY declarations

key_decls([K|Ks]) --> key_decl(K), !, ws, key_decls(Ks).
key_decls([]) --> [].

key_decl(key(Name, Fields, Attrs)) -->
    word(Name), ws, kw("KEY"), ws, "(", ws, key_field_list(Fields), ws, ")", ws,
    key_attrs(Attrs).

key_field_list([F|Fs]) --> ident(F), ws, key_field_rest(Fs).
key_field_list([]) --> [].
key_field_rest([F|Fs]) --> ",", ws, ident(F), ws, key_field_rest(Fs).
key_field_rest([]) --> [].

key_attrs([A|As]) --> ",", ws, key_attr(A), ws, key_attrs(As).
key_attrs([]) --> [].

key_attr(primary) --> kw("PRIMARY").
key_attr(nocase)  --> kw("NOCASE").
key_attr(opt)     --> kw("OPT").
key_attr(dup)     --> kw("DUP").

%% RECORD block

record_block(Fields) -->
    word(_), ws, kw("RECORD"), ws,
    field_list(Fields), ws,
    kw("END").

%% GROUP attributes

group_attrs(Prefix) --> ",", ws, kw("PRE"), ws, "(", ws, ident(Prefix), ws, ")".
group_attrs(none)   --> [].

%% QUEUE attributes

queue_attrs(Pre) -->
    ",", ws, kw("PRE"), ws, "(", ws, queue_pre(Pre), ws, ")", !.
queue_attrs(none) --> [].

queue_pre(Pre) --> ident(Pre), !.
queue_pre(none) --> [].

%% Field list (shared by RECORD, GROUP, QUEUE)

field_list([F|Fs]) --> field_decl(F), !, ws, field_list(Fs).
field_list([]) --> [].

% Nested GROUP inside a field list
field_decl(group(Name, Pre, Fields)) -->
    ident(Name), ws, kw("GROUP"), ws, !,
    group_attrs(Pre), ws,
    field_list(Fields), ws,
    kw("END").

% Regular field — use word (not ident) so keyword-named fields like Name, Date, etc.
% are allowed. Explicitly exclude block-terminating keywords so that END/MAP/CODE
% are never consumed as field names (which would prevent the block from closing).
field_decl(field(Name, Type, Attrs)) -->
    word(Name), { \+ is_block_keyword(Name) }, ws, type(Type), ws,
    var_attrs(Attrs).

is_block_keyword(Name) :-
    upcase_atom(Name, U),
    memberchk(U, ['END','MAP','CODE','PROCEDURE','PROGRAM','MEMBER']).

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

% INCLUDE inside MAP
map_entry_or_module(include(File)) -->
    kw("INCLUDE"), ws, "(", ws, "'", qchars(Cs), "'", ws,
    ( ",", ws, "'", qchars(_), "'" ; [] ), ws,
    ")",
    { atom_codes(File, Cs) }.

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

map_attr(c)       --> kw("C").
map_attr(raw)     --> kw("RAW").
map_attr(pascal)  --> kw("PASCAL").
map_attr(private) --> kw("PRIVATE").
map_attr(export)  --> kw("EXPORT").
map_attr(name(N)) -->
    kw("NAME"), ws, "(", ws, "'", qchars(Cs), "'", ws, ")",
    { atom_codes(N, Cs) }.

map_param_list([P|Ps]) --> map_param(P), ws, map_param_list_rest(Ps).
map_param_list([]) --> [].

map_param_list_rest([P|Ps]) --> ",", ws, map_param(P), ws, map_param_list_rest(Ps).
map_param_list_rest([]) --> [].

map_param(param(Name, ref(Type))) --> "*", ws, type(Type), ws, opt_ident(Name).
map_param(param(Name, Type))      --> type(Type), ws, opt_ident(Name).

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

% Local variables / structures between PROCEDURE line and CODE
local_vars([L|Ls]) --> local_var(L), !, ws, local_vars(Ls).
local_vars([]) --> [].

% QUEUE block as a local variable
local_var(queue(Name, Pre, Fields)) -->
    ident(Name), ws, kw("QUEUE"), ws, !,
    queue_attrs(Pre), ws,
    field_list(Fields), ws,
    kw("END").

% GROUP block as a local variable
local_var(group(Name, Pre, Fields)) -->
    ident(Name), ws, kw("GROUP"), ws, !,
    group_attrs(Pre), ws,
    field_list(Fields), ws,
    kw("END").

% INCLUDE inside procedure locals
local_var(include(File)) -->
    kw("INCLUDE"), ws, "(", ws, "'", qchars(Cs), "'", ws,
    ( ",", ws, "'", qchars(_), "'" ; [] ), ws,
    ")",
    { atom_codes(File, Cs) }.

% Regular local variable
local_var(local(Name, Type, Init, Attrs)) -->
    ident(Name), ws, type(Type), ws,
    var_init(Init), ws,
    var_attrs(Attrs).

%% Procedure parameter list

proc_param_list([P|Ps]) --> proc_param(P), ws, proc_param_list_rest(Ps).
proc_param_list([]) --> [].

proc_param_list_rest([P|Ps]) --> ",", ws, proc_param(P), ws, proc_param_list_rest(Ps).
proc_param_list_rest([]) --> [].

proc_param(param(Name, ref(Type))) --> "*", ws, type(Type), ws, ident(Name).
proc_param(param(Name, Type))      --> type(Type), ws, ident(Name).

%% ==========================================================================
%% Types  (item 3: expanded)
%% ==========================================================================

type(long)           --> kw("LONG").
type(short)          --> kw("SHORT").
type(byte)           --> kw("BYTE").
type(ulong)          --> kw("ULONG").
type(real)           --> kw("REAL").
type(date)           --> kw("DATE").
type(time)           --> kw("TIME").
type(string(Size))   --> kw("STRING"), ws, "(", ws, number(Size), ws, ")".
type(string)         --> kw("STRING").
type(cstring(Size))  --> kw("CSTRING"), ws, "(", ws, number(Size), ws, ")".
type(cstring)        --> kw("CSTRING").
type(pdecimal(P, S)) --> kw("PDECIMAL"), ws, "(", ws, number(P), ws, ",", ws, number(S), ws, ")".
type(like(Field))    --> kw("LIKE"), ws, "(", ws, ident(Field), ws, ")".
% Catch-all for user-defined type names (queue types, class types, etc.)
type(user_type(Name)) --> ident(Name).

%% ==========================================================================
%% Statements
%% ==========================================================================

statements([S|Ss]) --> statement(S), !, ws, statements(Ss).
statements([]) --> [].

statement(if(Cond, [Then], [])) -->
    kw("IF"), ws, expr(Cond), ws, kw("THEN"), ws, statement(Then), ws, ".".

statement(if(Cond, Then, Else)) -->
    kw("IF"), ws, expr(Cond), ws,
    statements(Then), ws,
    if_else(Else), ws,
    kw("END").

statement(loop_for(Var, Start, End, Body)) -->
    kw("LOOP"), ws, ident(Var), ws, "=", ws, expr(Start), ws, kw("TO"), ws, expr(End), ws,
    statements(Body), ws,
    kw("END").

statement(loop(Body)) -->
    kw("LOOP"), ws,
    statements(Body), ws,
    kw("END").

statement(case(Expr, Ofs, Else)) -->
    kw("CASE"), ws, expr(Expr), ws,
    of_blocks(Ofs), ws,
    case_else(Else), ws,
    kw("END").

statement(accept(Body)) -->
    kw("ACCEPT"), ws,
    statements(Body), ws,
    kw("END").

statement(display) --> kw("DISPLAY").
statement(break)   --> kw("BREAK").

statement(return(Expr)) --> kw("RETURN"), ws, expr(Expr).
statement(return(lit(0))) --> kw("RETURN").

statement(assign(array_ref(Name, Index), Expr)) -->
    ident(Name), ws, "[", ws, expr(Index), ws, "]", ws, "=", ws, expr(Expr).

statement(assign(Var, Expr)) -->
    ident(Var), ws, "=", ws, expr(Expr).

statement(assign(Var, add(var(Var), Expr))) -->
    ident(Var), ws, "+=", ws, expr(Expr).

statement(call('DELETE', [var(Name)])) -->
    kw("DELETE"), ws, "(", ws, ident(Name), ws, ")".

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

or_expr(E)  --> and_expr(L), ws, or_rest(L, E).
or_rest(L, or(L, R)) --> kw("OR"), ws, and_expr(R).
or_rest(E, E) --> [].

and_expr(E) --> compare_expr(L), ws, and_rest(L, E).
and_rest(L, and(L, R)) --> kw("AND"), ws, compare_expr(R).
and_rest(E, E) --> [].

compare_expr(E) --> add_expr(L), ws, compare_rest(L, E).
compare_rest(L, eq(L, R))  --> "=",  ws, add_expr(R).
compare_rest(L, neq(L, R)) --> "<>", ws, add_expr(R).
compare_rest(L, lt(L, R))  --> "<",  ws, add_expr(R).
compare_rest(L, lte(L, R)) --> "<=", ws, add_expr(R).
compare_rest(L, gt(L, R))  --> ">",  ws, add_expr(R).
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
primary(equate(Name)) --> "?", word(Name), !.
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

% Identifier: word(s) joined by ':' or '::', excluding pure keywords
% Handles: FLD:Field_Name, NT::THIS_MODULE, plain Name
ident(Name) -->
    word(Part1),
    ( "::", !, word(Part2), { atomic_list_concat([Part1, '::', Part2], Name) }
    ; ":",  !, word(Part2), { atomic_list_concat([Part1, ':',  Part2], Name) }
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
    member(U, [
        % Structure keywords
        'MEMBER','PROGRAM','MAP','END','PROCEDURE','CODE',
        'FILE','RECORD','GROUP','QUEUE','MODULE',
        % Control flow
        'RETURN','IF','THEN','ELSE','LOOP','BREAK','CASE','OF','TO',
        % Types (items 3 additions)
        'LONG','SHORT','BYTE','ULONG','REAL','DATE','TIME',
        'STRING','CSTRING','PDECIMAL','LIKE',
        % Variable attributes (item 4 additions)
        'THREAD','EXTERNAL','STATIC','DLL','OVER',
        % Declaration keywords
        'EQUATE','INCLUDE','DIM',
        % File/MAP attributes
        'DRIVER','CREATE','PRE','KEY','PRIMARY','NOCASE','OPT','DUP',
        'OWNER','NAME','C','RAW','PASCAL','PRIVATE','EXPORT',
        % Builtins used in statements
        'SET','NEXT','OPEN','CLOSE','GET','PUT','ADD','CLEAR',
        'DELETE','ERRORCODE','TODAY','ADDRESS','SIZE','POINTER',
        'AND','OR',
        % Window/GUI keywords
        'WINDOW','ACCEPT','DISPLAY','ACCEPTED',
        'PROMPT','ENTRY','BUTTON','LIST','AT','USE',
        'CENTER','DROP','FROM','CHOICE','SELECT'
    ]).

% Integer literal
number(N) -->
    ( "-", { Sign = [0'-] } ; { Sign = [] } ),
    digit(D), digits(Ds),
    { append(Sign, [D|Ds], Codes), number_codes(N, Codes) }.

digit(D)      --> [D], { D >= 0'0, D =< 0'9 }.
digits([D|Ds]) --> digit(D), !, digits(Ds).
digits([])     --> [].

% Quoted characters (returns code list, handles '' as escaped quote)
qchars([0''|Cs]) --> "''", !, qchars(Cs).
qchars([C|Cs])   --> [C], { C \= 0'' }, !, qchars(Cs).
qchars([])       --> [].

% Whitespace, comments, and line continuation (item 1)
%   '|' at end of logical line = continuation; skip to next line
ws --> [0'|], !, line_tail, ws.
ws --> [C], { C =< 32 }, !, ws.
ws --> "!", comment_body, !, ws.
ws --> [].

% Skip rest of physical line after '|' continuation marker
line_tail --> [0'\n], !.
line_tail --> [_], !, line_tail.
line_tail --> [].

comment_body --> "\n", !.
comment_body --> [_], !, comment_body.
comment_body --> [].
