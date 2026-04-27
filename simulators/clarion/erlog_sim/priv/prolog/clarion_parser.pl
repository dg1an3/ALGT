%% ============================================================
%% clarion_parser.pl — DCG grammar for Clarion syntax → AST
%%
%% Adapted for Erlog (Prolog-in-Erlang). Differences from SWI version:
%%   - No module declarations
%%   - No SWI dicts
%%   - Uses atom_codes/2 and number_codes/2 (ISO standard)
%%   - Custom helpers replace sub_string, string_concat, etc.
%%   - double_quotes treated as codes explicitly
%%
%% Called from Elixir via :erlog.prove/2
%% ============================================================

%% ==========================================================================
%% Entry point — called from Elixir
%% ==========================================================================

parse_clarion(Source, AST) :-
    atom(Source),
    atom_codes(Source, Codes),
    phrase(program(AST), Codes, []).

parse_clarion_codes(Codes, AST) :-
    phrase(program(AST), Codes, []).

%% ==========================================================================
%% Compatibility helpers (replace SWI-specific predicates)
%% ==========================================================================

%% atom_string equivalent using atom_codes
atom_to_codes(A, Codes) :- atom_codes(A, Codes).
codes_to_atom(Codes, A) :- atom_codes(A, Codes).

%% Uppercase a single character code
upcase_code(C, U) :-
    C >= 97, C =< 122, !, U is C - 32.
upcase_code(C, C).

%% Downcase a single character code
downcase_code(C, L) :-
    C >= 65, C =< 90, !, L is C + 32.
downcase_code(C, C).

%% Uppercase a list of codes
upcase_codes([], []).
upcase_codes([C|Cs], [U|Us]) :- upcase_code(C, U), upcase_codes(Cs, Us).

%% Number from codes
codes_to_number(Codes, N) :- number_codes(N, Codes).

%% Check if code is a digit
is_digit(C) :- C >= 48, C =< 57.

%% Check if code is alpha
is_alpha(C) :- C >= 65, C =< 90, !.   % A-Z
is_alpha(C) :- C >= 97, C =< 122, !.  % a-z
is_alpha(95).                          % underscore

%% Check if code is alphanumeric
is_alnum(C) :- is_alpha(C), !.
is_alnum(C) :- is_digit(C).

%% ==========================================================================
%% Generic DCG combinators
%% ==========================================================================

%% star(+Goal, -List)// — zero or more Goal
star(Goal, [X|Xs]) --> call(Goal, X), !, ws, star(Goal, Xs).
star(_, []) --> [].

%% comma_list(+Goal, -List)// — comma-separated list
comma_list(Goal, [X|Xs]) --> call(Goal, X), ws, comma_list_rest(Goal, Xs).
comma_list(_, []) --> [].

comma_list_rest(Goal, [X|Xs]) --> [44], ws, call(Goal, X), ws, comma_list_rest(Goal, Xs).
comma_list_rest(_, []) --> [].

%% ==========================================================================
%% Whitespace and newlines
%% ==========================================================================

%% ws — optional whitespace (spaces, tabs, comments, line continuations)
ws --> [32], !, ws.      % space
ws --> [9], !, ws.       % tab
ws --> [13], !, ws.      % CR
ws --> [10], !, ws.      % LF
ws --> [33], !, line_comment.  % ! comment
ws --> [].

%% Non-newline whitespace
ws_nonnl --> [32], !, ws_nonnl.
ws_nonnl --> [9], !, ws_nonnl.
ws_nonnl --> [].

%% Line comment — consume until newline
line_comment --> [10], !.
line_comment --> [13], !, line_comment.
line_comment --> [_], !, line_comment.
line_comment --> [].

%% Newline
nl --> [13, 10], !.
nl --> [10].
nl --> [13].

%% Optional newlines
opt_nl --> nl, !, ws.
opt_nl --> [].

%% ==========================================================================
%% Top-level: MEMBER or PROGRAM
%% ==========================================================================

program(program(Files, Groups, Globals, MapEntries, Procs)) -->
    ws, member_kw, ws,
    top_decls(Files, Groups, Globals),
    ws, map_section(MapEntries), ws,
    procedures(Procs), ws.

program(program([], [], [], MapEntries, [MainProc|Procs])) -->
    ws, program_kw, ws,
    opt_program_name, ws,
    map_section_opt(MapEntries), ws,
    global_decls_opt(Globals), ws,
    code_kw, ws,
    statements(Body), ws,
    procedures(Procs), ws,
    { MainProc = procedure('_main', [], void, Globals, Body) }.

member_kw --> kw("MEMBER"), ws, [40], ws, [41].  % MEMBER()
member_kw --> kw("MEMBER").

program_kw --> kw("PROGRAM").
code_kw --> kw("CODE").

opt_program_name --> ident(_), !.
opt_program_name --> [].

%% ==========================================================================
%% Keywords (case-insensitive matching)
%% ==========================================================================

kw(Expected) --> kw_chars(Chars), { upcase_codes(Chars, Upper), Expected = Upper }.

kw_chars([C|Cs]) --> [C], { is_alpha(C) }, kw_chars_rest(Cs).
kw_chars_rest([C|Cs]) --> [C], { is_alnum(C) }, !, kw_chars_rest(Cs).
kw_chars_rest([]) --> [].

%% ==========================================================================
%% MAP section
%% ==========================================================================

map_section(Entries) -->
    kw("MAP"), ws,
    map_entries(Entries),
    ws, kw("END"), ws.

map_section_opt(Entries) --> map_section(Entries), !.
map_section_opt([]) --> [].

map_entries([E|Es]) --> map_entry(E), !, ws, map_entries(Es).
map_entries([]) --> [].

map_entry(module_entry(ModName, SubEntries)) -->
    kw("MODULE"), ws, [40], ws, quoted_string(ModName), ws, [41], ws,
    map_entries(SubEntries),
    ws, kw("END"), ws.

map_entry(map_entry(Name, Params, RetType, Attrs)) -->
    ident(Name), ws,
    kw("PROCEDURE"), ws,
    map_params_opt(Params), ws,
    map_ret_opt(RetType), ws,
    map_attrs(Attrs), ws.

map_entry(map_entry(Name, Params, RetType, Attrs)) -->
    ident(Name), ws, [40], ws,
    comma_list(param_decl, Params), ws, [41], ws,
    map_ret_opt(RetType), ws,
    map_attrs(Attrs), ws.

map_params_opt(Params) --> [40], ws, comma_list(param_decl, Params), ws, [41], !.
map_params_opt([]) --> [].

map_ret_opt(RetType) --> [44], ws, type_name(RetType), !.
map_ret_opt(void) --> [].

map_attrs([A|As]) --> [44], ws, map_attr(A), !, map_attrs(As).
map_attrs([]) --> [].

map_attr(name(Name)) --> kw("NAME"), ws, [40], ws, quoted_string(Name), ws, [41].
map_attr(export) --> kw("EXPORT").
map_attr(c_conv) --> [67], { true }.  % 'C'

%% ==========================================================================
%% Top-level declarations (FILES, GROUPS, GLOBALS)
%% ==========================================================================

top_decls(Files, Groups, Globals) -->
    top_decl_items(Items),
    { separate_decls(Items, Files, Groups, Globals) }.

top_decl_items([I|Is]) --> top_decl_item(I), !, ws, top_decl_items(Is).
top_decl_items([]) --> [].

top_decl_item(file(Name, Prefix, Attrs, Contents)) -->
    ident(Name), ws, kw("FILE"), ws,
    file_attrs(Prefix, Attrs), ws,
    file_contents(Contents),
    ws, kw("END"), ws.

top_decl_item(group(Name, Prefix, Fields)) -->
    ident(Name), ws, kw("GROUP"), ws,
    group_prefix_opt(Prefix), ws,
    group_fields(Fields),
    ws, kw("END"), ws.

top_decl_item(equate(Name, Value)) -->
    ident(Name), ws, kw("EQUATE"), ws, [40], ws, expr(Value), ws, [41], ws.

top_decl_item(global(Name, Type, Init)) -->
    ident(Name), ws, type_name(Type), ws, global_init(Init), ws.

global_init(Init) --> [40], ws, expr(Init), ws, [41], !.
global_init(none) --> [].

global_decls_opt(Globals) --> top_decl_items(Items),
    { separate_decls(Items, _, _, Globals) }.

separate_decls([], [], [], []).
separate_decls([file(N,P,A,C)|Rest], [file(N,P,A,C)|Fs], Gs, Vs) :-
    separate_decls(Rest, Fs, Gs, Vs).
separate_decls([group(N,P,Flds)|Rest], Fs, [group(N,P,Flds)|Gs], Vs) :-
    separate_decls(Rest, Fs, Gs, Vs).
separate_decls([Item|Rest], Fs, Gs, [Item|Vs]) :-
    separate_decls(Rest, Fs, Gs, Vs).

%% ==========================================================================
%% FILE declarations
%% ==========================================================================

file_attrs(Prefix, Attrs) -->
    [44], ws, kw("DRIVER"), ws, [40], ws, quoted_string(_Driver), ws, [41], ws,
    file_attr_rest(Prefix, Attrs).
file_attrs(none, []) --> [].

file_attr_rest(Prefix, Attrs) -->
    [44], ws, kw("PRE"), ws, [40], ws, ident(Prefix), ws, [41], ws,
    file_attr_rest2(Attrs).
file_attr_rest(none, []) --> [].

file_attr_rest2([A|As]) --> [44], ws, file_single_attr(A), !, file_attr_rest2(As).
file_attr_rest2([]) --> [].

file_single_attr(create) --> kw("CREATE").
file_single_attr(reclaim) --> kw("RECLAIM").

file_contents([C|Cs]) --> file_content_item(C), !, ws, file_contents(Cs).
file_contents([]) --> [].

file_content_item(key(Name, Fields, Attrs)) -->
    ident(Name), ws, kw("KEY"), ws, [40], ws,
    comma_list(ident, Fields), ws, [41], ws,
    key_attrs(Attrs), ws.

file_content_item(record(Fields)) -->
    kw("RECORD"), ws,
    record_fields(Fields),
    ws, kw("END"), ws.

key_attrs([A|As]) --> [44], ws, key_attr(A), !, key_attrs(As).
key_attrs([]) --> [].

key_attr(primary) --> kw("PRIMARY").
key_attr(nocase) --> kw("NOCASE").
key_attr(unique) --> kw("UNIQUE").

record_fields([F|Fs]) --> record_field(F), !, ws, record_fields(Fs).
record_fields([]) --> [].

record_field(field(Name, Type, Size)) -->
    ident(Name), ws, type_with_size(Type, Size), ws.

%% ==========================================================================
%% GROUP declarations
%% ==========================================================================

group_prefix_opt(Prefix) --> [44], ws, kw("PRE"), ws, [40], ws, ident(Prefix), ws, [41].
group_prefix_opt(none) --> [].

group_fields(Fields) --> record_fields(Fields).

%% ==========================================================================
%% Types
%% ==========================================================================

type_name(Type) --> kw_type(Type).

kw_type(long) --> kw("LONG").
kw_type(short) --> kw("SHORT").
kw_type(byte) --> kw("BYTE").
kw_type(real) --> kw("REAL").
kw_type(sreal) --> kw("SREAL").
kw_type(date) --> kw("DATE").
kw_type(time) --> kw("TIME").
kw_type(decimal) --> kw("DECIMAL").
kw_type(pdecimal) --> kw("PDECIMAL").
kw_type(string) --> kw("STRING").
kw_type(cstring) --> kw("CSTRING").
kw_type(pstring) --> kw("PSTRING").

type_with_size(Type, Size) -->
    type_name(Type), ws, [40], ws, integer(Size), ws, [41], !.
type_with_size(Type, none) -->
    type_name(Type).

%% Pointer type: *CSTRING
type_with_size(ref(Type), Size) -->
    [42], ws, type_with_size(Type, Size).

%% ==========================================================================
%% Procedures
%% ==========================================================================

procedures([P|Ps]) --> procedure_def(P), !, ws, procedures(Ps).
procedures([]) --> [].

procedure_def(procedure(Name, Params, RetType, Locals, Body)) -->
    ident(Name), ws, kw("PROCEDURE"), ws,
    proc_params_opt(Params), ws,
    proc_ret_opt(RetType), ws,
    local_decls(Locals), ws,
    code_kw, ws,
    statements(Body), ws.

proc_params_opt(Params) --> [40], ws, comma_list(param_decl, Params), ws, [41], !.
proc_params_opt([]) --> [].

proc_ret_opt(RetType) --> [44], ws, type_name(RetType), !.
proc_ret_opt(void) --> [].

param_decl(param(Name, Type)) -->
    ident(Name), ws, type_with_size(Type, _Size), ws.

param_decl(param(Name, ref(Type))) -->
    [42], ws, ident(Name), ws, type_with_size(Type, _Size), ws.

%% ==========================================================================
%% Local variable declarations
%% ==========================================================================

local_decls([L|Ls]) --> local_decl(L), !, ws, local_decls(Ls).
local_decls([]) --> [].

local_decl(local(Name, Type, Init)) -->
    ident(Name), ws, type_with_size(Type, _Size), ws, local_init(Init), ws.

local_init(Init) --> [40], ws, expr(Init), ws, [41], !.
local_init(none) --> [].

%% ==========================================================================
%% Statements
%% ==========================================================================

statements([S|Ss]) --> ws, statement(S), !, ws, statements(Ss).
statements([]) --> [].

%% RETURN
statement(return(Expr)) --> kw("RETURN"), ws_nonnl, expr(Expr), !.
statement(return) --> kw("RETURN"), !.

%% Assignment: Var = Expr
statement(assign(Name, Expr)) -->
    ident(Name), ws, [61], ws, expr(Expr), !.   % 61 = '='

%% Compound assignment: Var += Expr
statement(assign_add(Name, Expr)) -->
    ident(Name), ws, [43, 61], ws, expr(Expr), !.  % '+='

%% IF/THEN/ELSIF/ELSE/END
statement(if(Cond, Then, Else)) -->
    kw("IF"), ws, expr(Cond), ws,
    opt_then, ws,
    statements(Then), ws,
    else_part(Else),
    ws, kw("END"), !.

opt_then --> kw("THEN"), !.
opt_then --> [].

else_part(Else) --> kw("ELSE"), ws, statements(Else), !.
else_part([]) --> [].

%% LOOP variants
statement(loop(Body)) -->
    kw("LOOP"), ws,
    loop_body(Body),
    ws, kw("END"), !.

statement(loop_for(Var, Start, End, Body)) -->
    kw("LOOP"), ws, ident(Var), ws, [61], ws, expr(Start), ws,
    kw("TO"), ws, expr(End), ws,
    loop_body(Body),
    ws, kw("END"), !.

statement(loop_while(Cond, Body)) -->
    kw("LOOP"), ws, kw("WHILE"), ws, expr(Cond), ws,
    loop_body(Body),
    ws, kw("END"), !.

statement(loop_until(Cond, Body)) -->
    kw("LOOP"), ws, kw("UNTIL"), ws, expr(Cond), ws,
    loop_body(Body),
    ws, kw("END"), !.

loop_body(Body) --> statements(Body).

%% BREAK / CYCLE
statement(break) --> kw("BREAK"), !.
statement(cycle) --> kw("CYCLE"), !.

%% CASE
statement(case(Expr, Cases, Else)) -->
    kw("CASE"), ws, expr(Expr), ws,
    case_branches(Cases), ws,
    case_else(Else),
    ws, kw("END"), !.

case_branches([B|Bs]) --> case_branch(B), !, ws, case_branches(Bs).
case_branches([]) --> [].

case_branch(of(Value, Body)) -->
    kw("OF"), ws, case_value(Value), ws,
    statements(Body), ws.

case_value(range(Start, End)) -->
    expr(Start), ws, kw("TO"), ws, expr(End), !.
case_value(single(V)) --> expr(V).

case_else(Else) --> kw("ELSE"), ws, statements(Else), !.
case_else([]) --> [].

%% ACCEPT loop
statement(accept(Body)) -->
    kw("ACCEPT"), ws,
    statements(Body),
    ws, kw("END"), !.

%% DO routine
statement(do(Name)) --> kw("DO"), ws, ident(Name), !.

%% EXIT
statement(exit) --> kw("EXIT"), !.

%% DISPLAY
statement(display) --> kw("DISPLAY"), !.

%% Procedure call: Name(Args)
statement(call(Name, Args)) -->
    ident(Name), ws, [40], ws,
    comma_list(expr, Args), ws, [41], !.

%% ==========================================================================
%% Expressions (precedence climbing)
%% ==========================================================================

expr(E) --> or_expr(E).

or_expr(E) --> and_expr(L), ws, or_rest(L, E).
or_rest(L, E) --> kw("OR"), ws, and_expr(R), !, ws, or_rest(or(L, R), E).
or_rest(E, E) --> [].

and_expr(E) --> not_expr(L), ws, and_rest(L, E).
and_rest(L, E) --> kw("AND"), ws, not_expr(R), !, ws, and_rest(and(L, R), E).
and_rest(E, E) --> [].

not_expr(not(E)) --> kw("NOT"), ws, not_expr(E), !.
not_expr(E) --> cmp_expr(E).

cmp_expr(E) --> add_expr(L), ws, cmp_rest(L, E).
cmp_rest(L, eq(L, R)) --> [61], ws, add_expr(R), !.        % =
cmp_rest(L, neq(L, R)) --> [60, 62], ws, add_expr(R), !.   % <>
cmp_rest(L, lte(L, R)) --> [60, 61], ws, add_expr(R), !.   % <=
cmp_rest(L, gte(L, R)) --> [62, 61], ws, add_expr(R), !.   % >=
cmp_rest(L, lt(L, R)) --> [60], ws, add_expr(R), !.        % <
cmp_rest(L, gt(L, R)) --> [62], ws, add_expr(R), !.        % >
cmp_rest(E, E) --> [].

add_expr(E) --> mul_expr(L), ws, add_rest(L, E).
add_rest(L, E) --> [43], ws, mul_expr(R), !, ws, add_rest(add(L, R), E).   % +
add_rest(L, E) --> [45], ws, mul_expr(R), !, ws, add_rest(sub(L, R), E).   % -
add_rest(L, E) --> [38], ws, mul_expr(R), !, ws, add_rest(concat(L, R), E). % &
add_rest(E, E) --> [].

mul_expr(E) --> unary_expr(L), ws, mul_rest(L, E).
mul_rest(L, E) --> [42], ws, unary_expr(R), !, ws, mul_rest(mul(L, R), E). % *
mul_rest(L, E) --> [47], ws, unary_expr(R), !, ws, mul_rest(div(L, R), E). % /
mul_rest(L, E) --> [37], ws, unary_expr(R), !, ws, mul_rest(modulo(L, R), E). % %
mul_rest(E, E) --> [].

unary_expr(neg(E)) --> [45], ws, primary(E), !.  % negation
unary_expr(E) --> primary(E).

%% Primary expressions
primary(E) --> [40], ws, expr(E), ws, [41], !.  % (expr)

primary(lit(N)) --> float_lit(N), !.
primary(lit(N)) --> integer(N), !.

primary(equate(Name)) --> [63], ident(Name), !.  % ?Name (equate reference)

primary(call(Name, Args)) -->
    ident(Name), ws, [40], ws,
    comma_list(expr, Args), ws, [41], !.

primary(array_ref(Name, Index)) -->
    ident(Name), ws, [91], ws, expr(Index), ws, [93], !.  % Name[Index]

primary(var(Name)) --> ident(Name), !.

primary(lit(S)) --> quoted_string(S), !.

%% ==========================================================================
%% Lexical elements
%% ==========================================================================

%% Identifier: starts with alpha, continues with alnum or ':'
ident(Name) --> ident_chars([C|Cs]), { is_alpha(C), codes_to_atom([C|Cs], Name) }.

ident_chars([C|Cs]) --> [C], { is_alpha(C) }, !, ident_chars_rest(Cs).
ident_chars_rest([C|Cs]) --> [C], { is_alnum(C) ; C =:= 58 ; C =:= 95 }, !, ident_chars_rest(Cs).
%% 58 = ':', 95 = '_'
ident_chars_rest([]) --> [].

%% Integer literal
integer(N) --> digit_chars([D|Ds]), { codes_to_number([D|Ds], N) }.

digit_chars([D|Ds]) --> [D], { is_digit(D) }, !, digit_chars_rest(Ds).
digit_chars_rest([D|Ds]) --> [D], { is_digit(D) }, !, digit_chars_rest(Ds).
digit_chars_rest([]) --> [].

%% Float literal: digits.digits
float_lit(N) -->
    digit_chars(IntPart), [46], digit_chars(FracPart),
    { append(IntPart, [46|FracPart], AllCodes), codes_to_number(AllCodes, N) }.

%% Quoted string (single quotes)
quoted_string(S) --> [39], string_chars(Codes), [39],
    { codes_to_atom(Codes, S) }.

%% Double-quoted string
quoted_string(S) --> [34], dq_string_chars(Codes), [34],
    { codes_to_atom(Codes, S) }.

string_chars([C|Cs]) --> [C], { C \= 39 }, !, string_chars(Cs).
string_chars([]) --> [].

dq_string_chars([C|Cs]) --> [C], { C \= 34 }, !, dq_string_chars(Cs).
dq_string_chars([]) --> [].

%% append/3 for float parsing
append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).
