% clarion.pl — DCG grammar for Clarion syntax + AST interpreter
%
% Two cleanly separated layers:
%   1. DCG grammar:  source text --> AST
%   2. Interpreter:  AST --> results

:- module(clarion, [
    parse_clarion/2,
    exec_procedure/4
]).

:- set_prolog_flag(double_quotes, codes).

%% ==========================================================================
%% AST definition
%% ==========================================================================
%
%   program(Procedures)
%
%   procedure(Name, Params, ReturnType, Body)
%     Params  = [param(Name, Type), ...]
%     Body    = [Statement, ...]
%
%   Statements:
%     return(Expr)
%     assign(Var, Expr)
%
%   Expressions:
%     lit(Number)
%     var(Name)
%     add(Left, Right)
%     mul(Left, Right)

%% ==========================================================================
%% DCG grammar — parses Clarion source (character codes) directly into AST
%% ==========================================================================

parse_clarion(Source, AST) :-
    ( atom(Source) -> atom_codes(Source, Codes)
    ; string_to_list(Source, Codes)
    ),
    phrase(program(AST), Codes).

% --- Top-level program structure ---

%   MEMBER()
%   MAP ... END
%   procedure*
program(program(Procs)) -->
    ws, kw("MEMBER"), ws, "(", ws, ")", ws,
    map_block, ws,
    procedures(Procs), ws.

% --- MAP block (parsed for validation, discarded from AST) ---

map_block -->
    kw("MAP"), ws,
    map_entries, ws,
    kw("END").

map_entries --> map_entry, !, ws, map_entries.
map_entries --> [].

%   MathAdd(LONG a, LONG b),LONG,C,NAME('MathAdd'),EXPORT
map_entry -->
    ident(_), ws, "(", ws, param_list(_), ws, ")", ws,
    ",", ws, type(_), ws,
    map_attrs.

map_attrs --> ",", ws, kw("C"),      ws, !, map_attrs.
map_attrs --> ",", ws, kw("NAME"),   ws, "(", ws, quoted_string, ws, ")", ws, !, map_attrs.
map_attrs --> ",", ws, kw("EXPORT"), ws, !, map_attrs.
map_attrs --> [].

quoted_string --> "'", quoted_chars, "'".
quoted_chars --> [C], { C \= 0'' }, !, quoted_chars.
quoted_chars --> [].

% --- Procedure definitions ---

procedures([P|Ps]) --> procedure(P), !, ws, procedures(Ps).
procedures([]) --> [].

%   Name PROCEDURE(LONG a, LONG b)
%     CODE
%     statements...
procedure(procedure(Name, Params, RetType, Body)) -->
    ident(Name), ws,
    kw("PROCEDURE"), ws, "(", ws, param_list(Params), ws, ")", ws,
    return_type(RetType), ws,
    kw("CODE"), ws,
    statements(Body).

return_type(RetType) --> ",", ws, type(RetType), ws.
return_type(void) --> [].

% --- Parameters ---

param_list([P|Ps]) --> param(P), ws, param_list_rest(Ps).
param_list([]) --> [].

param_list_rest([P|Ps]) --> ",", ws, param(P), ws, param_list_rest(Ps).
param_list_rest([]) --> [].

param(param(Name, Type)) --> type(Type), ws, ident(Name).

% --- Types ---

type(long) --> kw("LONG").

% --- Statements ---

statements([S|Ss]) --> statement(S), !, ws, statements(Ss).
statements([]) --> [].

statement(return(Expr)) -->
    kw("RETURN"), ws, "(", ws, expr(Expr), ws, ")".

statement(assign(Var, Expr)) -->
    ident(Var), ws, "=", ws, expr(Expr).

% --- Expressions (precedence: additive > multiplicative > primary) ---

expr(E) --> add_expr(E).

add_expr(E) --> mul_expr(L), ws, add_rest(L, E).
add_rest(L, E)  --> "+", ws, mul_expr(R), ws, add_rest(add(L, R), E).
add_rest(E, E)  --> [].

mul_expr(E) --> primary(L), ws, mul_rest(L, E).
mul_rest(L, E)  --> "*", ws, primary(R), ws, mul_rest(mul(L, R), E).
mul_rest(E, E)  --> [].

primary(lit(N))    --> number(N), !.
primary(var(Name)) --> ident(Name), !.
primary(E)         --> "(", ws, expr(E), ws, ")".

% --- Lexical rules ---

% Case-insensitive keyword match (must not be followed by ident char)
kw([]) --> \+ ( [C], { ident_cont(C) } ).
kw([]) --> [].  % at end of input
kw([K|Ks]) --> [C], { to_upper(C, U), to_upper(K, U) }, kw(Ks).

to_upper(C, U) :- C >= 0'a, C =< 0'z, !, U is C - 32.
to_upper(C, C).

% Identifier: [a-zA-Z_][a-zA-Z0-9_]*  (must not be a keyword)
ident(Name) -->
    [C], { ident_start(C) },
    ident_rest(Cs),
    { atom_codes(Name, [C|Cs]),
      \+ is_keyword(Name) }.

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
               'LONG','C','NAME','EXPORT']).

% Integer literal
number(N) --> digit(D), digits(Ds), { number_codes(N, [D|Ds]) }.

digit(D) --> [D], { D >= 0'0, D =< 0'9 }.
digits([D|Ds]) --> digit(D), !, digits(Ds).
digits([]) --> [].

% Whitespace and comments
ws --> [C], { C =< 32 }, !, ws.        % space, tab, CR, LF
ws --> "!", comment_body, !, ws.        % ! comment to end of line
ws --> [].

comment_body --> "\n", !.
comment_body --> [_], !, comment_body.
comment_body --> [].

%% ==========================================================================
%% Interpreter — executes the AST
%% ==========================================================================

% exec_procedure(+AST, +ProcName, +ArgValues, -Result)
exec_procedure(program(Procs), ProcName, ArgValues, Result) :-
    memberchk(procedure(ProcName, Params, _RetType, Body), Procs),
    bind_params(Params, ArgValues, Env),
    exec_body(Body, Env, Result).

bind_params([], [], []).
bind_params([param(Name, _)|Ps], [V|Vs], [Name=V|Es]) :-
    bind_params(Ps, Vs, Es).

% Execute statements until a RETURN is reached
exec_body([return(Expr)|_], Env, Result) :-
    eval(Expr, Env, Result).
exec_body([assign(Var, Expr)|Rest], Env, Result) :-
    eval(Expr, Env, Val),
    exec_body(Rest, [Var=Val|Env], Result).
exec_body([_|Rest], Env, Result) :-
    exec_body(Rest, Env, Result).

% eval(+Expr, +Env, -Value)
eval(lit(N), _, N).
eval(var(Name), Env, V) :- memberchk(Name=V, Env).
eval(add(A, B), Env, V) :- eval(A, Env, VA), eval(B, Env, VB), V is VA + VB.
eval(mul(A, B), Env, V) :- eval(A, Env, VA), eval(B, Env, VB), V is VA * VB.
