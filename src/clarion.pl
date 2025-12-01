%============================================================
% clarion.pl - Main entry point for Clarion analyzer
%============================================================

:- module(clarion, [
    analyze_file/1,
    analyze_file/2,
    parse_file/2,
    tokenize_file/2,
    print_ast/1
]).

:- use_module(lexer).
:- use_module(parser).

%------------------------------------------------------------
% analyze_file(+FileName)
% Parse and display analysis of a Clarion file
%------------------------------------------------------------
analyze_file(FileName) :-
    analyze_file(FileName, AST),
    print_ast(AST).

%------------------------------------------------------------
% analyze_file(+FileName, -AST)
% Parse a Clarion file and return the AST
%------------------------------------------------------------
analyze_file(FileName, AST) :-
    format("Parsing: ~w~n", [FileName]),
    parser:parse_file(FileName, AST),
    format("Parse successful!~n", []).

%------------------------------------------------------------
% print_ast(+AST)
% Pretty print the AST
%------------------------------------------------------------
print_ast(AST) :-
    format("~n=== Abstract Syntax Tree ===~n~n", []),
    print_ast(AST, 0).

print_ast(program(Map, Code, Procedures), Indent) :-
    print_indent(Indent),
    format("PROGRAM~n", []),
    Indent1 is Indent + 2,
    print_ast(Map, Indent1),
    print_ast(Code, Indent1),
    print_procedures(Procedures, Indent1).

print_ast(map(Declarations), Indent) :-
    print_indent(Indent),
    format("MAP~n", []),
    Indent1 is Indent + 2,
    maplist(print_declaration(Indent1), Declarations).

print_ast(code(Statements), Indent) :-
    print_indent(Indent),
    format("CODE~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Statements).

print_declaration(Indent, proc_decl(Name, Type)) :-
    print_indent(Indent),
    format("~w: ~w~n", [Name, Type]).

print_declaration(Indent, proc_decl(Name, function, ReturnType)) :-
    print_indent(Indent),
    format("~w: function -> ~w~n", [Name, ReturnType]).

print_procedures([], _).
print_procedures([Proc|Procs], Indent) :-
    print_procedure(Proc, Indent),
    print_procedures(Procs, Indent).

print_procedure(procedure(Name, _Params, _LocalVars, code(Statements)), Indent) :-
    print_indent(Indent),
    format("PROCEDURE ~w~n", [Name]),
    Indent1 is Indent + 2,
    print_indent(Indent1),
    format("CODE~n", []),
    Indent2 is Indent1 + 2,
    maplist(print_statement(Indent2), Statements).

print_statement(Indent, call(Name, Args)) :-
    print_indent(Indent),
    format("CALL ~w(", [Name]),
    print_args(Args),
    format(")~n", []).

print_statement(Indent, return) :-
    print_indent(Indent),
    format("RETURN~n", []).

print_statement(Indent, assign(Var, Expr)) :-
    print_indent(Indent),
    format("~w = ", [Var]),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, if(Cond, Then, Else)) :-
    print_indent(Indent),
    format("IF ", []),
    print_expr(Cond),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Then),
    ( Else \= []
    -> print_indent(Indent),
       format("ELSE~n", []),
       maplist(print_statement(Indent1), Else)
    ;  true
    ),
    print_indent(Indent),
    format("END~n", []).

print_statement(Indent, loop(Body)) :-
    print_indent(Indent),
    format("LOOP~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Body),
    print_indent(Indent),
    format("END~n", []).

print_args([]).
print_args([Arg]) :-
    print_expr(Arg).
print_args([Arg|Args]) :-
    Args \= [],
    print_expr(Arg),
    format(", ", []),
    print_args(Args).

print_expr(string(S)) :-
    format("'~w'", [S]).
print_expr(number(N)) :-
    format("~w", [N]).
print_expr(var(Name)) :-
    format("~w", [Name]).
print_expr(call(Name, Args)) :-
    format("~w(", [Name]),
    print_args(Args),
    format(")", []).
print_expr(binop(Op, Left, Right)) :-
    format("(", []),
    print_expr(Left),
    format(" ~w ", [Op]),
    print_expr(Right),
    format(")", []).

print_indent(0) :- !.
print_indent(N) :-
    N > 0,
    format(" ", []),
    N1 is N - 1,
    print_indent(N1).
