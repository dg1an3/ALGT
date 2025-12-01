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

print_ast(program(Map, GlobalDecls, Code, Procedures), Indent) :-
    print_indent(Indent),
    format("PROGRAM~n", []),
    Indent1 is Indent + 2,
    print_ast(Map, Indent1),
    print_global_declarations(GlobalDecls, Indent1),
    print_ast(Code, Indent1),
    print_procedures(Procedures, Indent1).

% Support legacy 3-argument form for backwards compatibility
print_ast(program(Map, Code, Procedures), Indent) :-
    \+ is_list(Code),  % Code is code(...) not a list
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

%------------------------------------------------------------
% Print global declarations (CLASS, GROUP, QUEUE, FILE, variables)
%------------------------------------------------------------
print_global_declarations([], _).
print_global_declarations([Decl|Decls], Indent) :-
    print_global_decl(Decl, Indent),
    print_global_declarations(Decls, Indent).

print_global_decl(class(Name, Parent, Attrs, Members), Indent) :-
    print_indent(Indent),
    format("CLASS ~w", [Name]),
    ( Parent \= none -> format("(~w)", [Parent]) ; true ),
    ( Attrs \= [] -> format(" [~w]", [Attrs]) ; true ),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_class_member(Indent1), Members).

print_global_decl(group(Name, Members), Indent) :-
    print_indent(Indent),
    format("GROUP ~w~n", [Name]),
    Indent1 is Indent + 2,
    maplist(print_field(Indent1), Members).

print_global_decl(queue(Name, Members), Indent) :-
    print_indent(Indent),
    format("QUEUE ~w~n", [Name]),
    Indent1 is Indent + 2,
    maplist(print_field(Indent1), Members).

print_global_decl(file(Name, Contents), Indent) :-
    print_indent(Indent),
    format("FILE ~w~n", [Name]),
    Indent1 is Indent + 2,
    maplist(print_file_item(Indent1), Contents).

print_global_decl(var(Name, Type, Size), Indent) :-
    print_indent(Indent),
    format("~w: ~w", [Name, Type]),
    ( Size = size(N) -> format("(~w)", [N])
    ; Size = size(P,D) -> format("(~w,~w)", [P,D])
    ; true ),
    format("~n", []).

print_class_member(Indent, property(Name, Type, Size)) :-
    print_indent(Indent),
    format("~w: ~w", [Name, Type]),
    ( Size = size(N) -> format("(~w)", [N])
    ; Size = size(P,D) -> format("(~w,~w)", [P,D])
    ; true ),
    format("~n", []).

print_class_member(Indent, method(Name, Params, RetType, Attrs)) :-
    print_indent(Indent),
    format("METHOD ~w(", [Name]),
    print_params(Params),
    format(")", []),
    ( RetType \= none -> format(" -> ~w", [RetType]) ; true ),
    ( Attrs \= [] -> format(" [~w]", [Attrs]) ; true ),
    format("~n", []).

print_params([]).
print_params([param(Type, Name)]) :-
    format("~w ~w", [Type, Name]).
print_params([param(Type, Name)|Rest]) :-
    Rest \= [],
    format("~w ~w, ", [Type, Name]),
    print_params(Rest).

print_field(Indent, field(Name, Type, Size)) :-
    print_indent(Indent),
    format("~w: ~w", [Name, Type]),
    ( Size = size(N) -> format("(~w)", [N])
    ; Size = size(P,D) -> format("(~w,~w)", [P,D])
    ; true ),
    format("~n", []).

print_file_item(Indent, key(Name, Fields, _Attrs)) :-
    print_indent(Indent),
    format("KEY ~w(~w)~n", [Name, Fields]).

print_file_item(Indent, record(Members)) :-
    print_indent(Indent),
    format("RECORD~n", []),
    Indent1 is Indent + 2,
    maplist(print_field(Indent1), Members).

print_file_item(Indent, field(Name, Type, Size)) :-
    print_field(Indent, field(Name, Type, Size)).

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

print_procedure(method_impl(ClassName, MethodName, _Params, _LocalVars, code(Statements)), Indent) :-
    print_indent(Indent),
    format("METHOD ~w.~w~n", [ClassName, MethodName]),
    Indent1 is Indent + 2,
    print_indent(Indent1),
    format("CODE~n", []),
    Indent2 is Indent1 + 2,
    maplist(print_statement(Indent2), Statements).

print_procedure(routine(Name, Statements), Indent) :-
    print_indent(Indent),
    format("ROUTINE ~w~n", [Name]),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Statements).

% Catch-all for unknown procedure types
print_procedure(Proc, Indent) :-
    print_indent(Indent),
    format("/* Unknown procedure: ~w */~n", [Proc]).

print_statement(Indent, call(Name, Args)) :-
    print_indent(Indent),
    format("CALL ~w(", [Name]),
    print_args(Args),
    format(")~n", []).

print_statement(Indent, method_call(Obj, Method, Args)) :-
    print_indent(Indent),
    format("~w.~w(", [Obj, Method]),
    print_args(Args),
    format(")~n", []).

print_statement(Indent, member_access(Obj, Member)) :-
    print_indent(Indent),
    format("~w.~w~n", [Obj, Member]).

print_statement(Indent, return) :-
    print_indent(Indent),
    format("RETURN~n", []).

print_statement(Indent, return(Expr)) :-
    print_indent(Indent),
    format("RETURN ", []),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, do(Name)) :-
    print_indent(Indent),
    format("DO ~w~n", [Name]).

print_statement(Indent, assign(Var, Expr)) :-
    print_indent(Indent),
    format("~w = ", [Var]),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, array_assign(Array, Index, Expr)) :-
    print_indent(Indent),
    format("~w[", [Array]),
    print_expr(Index),
    format("] = ", []),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, member_assign(Obj, Member, Expr)) :-
    print_indent(Indent),
    format("~w.~w = ", [Obj, Member]),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, self_assign(Member, Expr)) :-
    print_indent(Indent),
    format("SELF.~w = ", [Member]),
    print_expr(Expr),
    format("~n", []).

print_statement(Indent, parent_call(Method, Args)) :-
    print_indent(Indent),
    format("PARENT.~w(", [Method]),
    print_args(Args),
    format(")~n", []).

print_statement(Indent, assign_add(Var, Expr)) :-
    print_indent(Indent),
    format("~w += ", [Var]),
    print_expr(Expr),
    format("~n", []).

% IF with ELSIF support (4-arg form)
print_statement(Indent, if(Cond, Then, ElsIfs, Else)) :-
    print_indent(Indent),
    format("IF ", []),
    print_expr(Cond),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Then),
    print_elsif_clauses(Indent, ElsIfs),
    ( Else \= []
    -> print_indent(Indent),
       format("ELSE~n", []),
       maplist(print_statement(Indent1), Else)
    ;  true
    ),
    print_indent(Indent),
    format("END~n", []).

% Legacy IF without ELSIF (3-arg form)
print_statement(Indent, if(Cond, Then, Else)) :-
    \+ is_list(Else),  % Disambiguate from 4-arg version
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

print_elsif_clauses(_, []).
print_elsif_clauses(Indent, [elsif(Cond, Stmts)|Rest]) :-
    print_indent(Indent),
    format("ELSIF ", []),
    print_expr(Cond),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Stmts),
    print_elsif_clauses(Indent, Rest).

print_statement(Indent, loop(Body)) :-
    print_indent(Indent),
    format("LOOP~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Body),
    print_indent(Indent),
    format("END~n", []).

print_statement(Indent, loop_to(Var, From, To, Body)) :-
    print_indent(Indent),
    format("LOOP ~w = ", [Var]),
    print_expr(From),
    format(" TO ", []),
    print_expr(To),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Body),
    print_indent(Indent),
    format("END~n", []).

print_statement(Indent, loop_while(Cond, Body)) :-
    print_indent(Indent),
    format("LOOP WHILE ", []),
    print_expr(Cond),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Body),
    print_indent(Indent),
    format("END~n", []).

print_statement(Indent, loop_until(Cond, Body)) :-
    print_indent(Indent),
    format("LOOP UNTIL ", []),
    print_expr(Cond),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Body),
    print_indent(Indent),
    format("END~n", []).

print_statement(Indent, break) :-
    print_indent(Indent),
    format("BREAK~n", []).

print_statement(Indent, cycle) :-
    print_indent(Indent),
    format("CYCLE~n", []).

print_statement(Indent, exit) :-
    print_indent(Indent),
    format("EXIT~n", []).

print_statement(Indent, case(Expr, Cases, Else)) :-
    print_indent(Indent),
    format("CASE ", []),
    print_expr(Expr),
    format("~n", []),
    Indent1 is Indent + 2,
    print_case_branches(Indent1, Cases),
    ( Else \= []
    -> print_indent(Indent1),
       format("ELSE~n", []),
       Indent2 is Indent1 + 2,
       maplist(print_statement(Indent2), Else)
    ;  true
    ),
    print_indent(Indent),
    format("END~n", []).

print_case_branches(_, []).
print_case_branches(Indent, [case_of(Value, Stmts)|Rest]) :-
    print_indent(Indent),
    format("OF ", []),
    print_expr(Value),
    format("~n", []),
    Indent1 is Indent + 2,
    maplist(print_statement(Indent1), Stmts),
    print_case_branches(Indent, Rest).

% Catch-all for unknown statements
print_statement(Indent, Stmt) :-
    print_indent(Indent),
    format("/* Unknown: ~w */~n", [Stmt]).

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
print_expr(neg(N)) :-
    format("-~w", [N]).
print_expr(not(Expr)) :-
    format("NOT ", []),
    print_expr(Expr).
print_expr(var(Name)) :-
    format("~w", [Name]).
print_expr(true) :-
    format("TRUE", []).
print_expr(false) :-
    format("FALSE", []).
print_expr(picture(Name)) :-
    format("@~w", [Name]).
print_expr(call(Name, Args)) :-
    format("~w(", [Name]),
    print_args(Args),
    format(")", []).
print_expr(method_call(Obj, Method, Args)) :-
    format("~w.~w(", [Obj, Method]),
    print_args(Args),
    format(")", []).
print_expr(member_access(Obj, Member)) :-
    format("~w.~w", [Obj, Member]).
print_expr(self_access(Member)) :-
    format("SELF.~w", [Member]).
print_expr(binop(Op, Left, Right)) :-
    format("(", []),
    print_expr(Left),
    format(" ~w ", [Op]),
    print_expr(Right),
    format(")", []).
% Catch-all for unknown expressions
print_expr(Expr) :-
    format("/*~w*/", [Expr]).

print_indent(0) :- !.
print_indent(N) :-
    N > 0,
    format(" ", []),
    N1 is N - 1,
    print_indent(N1).
