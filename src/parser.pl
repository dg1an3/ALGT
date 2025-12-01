%============================================================
% parser.pl - Clarion Parser (DCG)
% Parses tokens into an AST
%============================================================

:- module(parser, [
    parse/2,
    parse_file/2
]).

:- use_module(lexer).

%------------------------------------------------------------
% parse_file(+FileName, -AST)
% Parse a Clarion source file into an AST
%------------------------------------------------------------
parse_file(FileName, AST) :-
    tokenize_file(FileName, Tokens),
    parse(Tokens, AST).

%------------------------------------------------------------
% parse(+Tokens, -AST)
% Parse token list into AST
%------------------------------------------------------------
parse(Tokens, AST) :-
    phrase(program(AST), Tokens).

%------------------------------------------------------------
% Program structure
% program ::= 'PROGRAM' map_section code_section procedure_defs
%------------------------------------------------------------
program(program(Map, MainCode, Procedures)) -->
    [keyword('PROGRAM')],
    map_section(Map),
    code_section(MainCode),
    procedure_definitions(Procedures).

%------------------------------------------------------------
% MAP section
% map_section ::= 'MAP' procedure_declarations 'END'
%------------------------------------------------------------
map_section(map(Declarations)) -->
    [keyword('MAP')],
    procedure_declarations(Declarations),
    [keyword('END')].

procedure_declarations([Decl|Decls]) -->
    procedure_declaration(Decl),
    !,
    procedure_declarations(Decls).
procedure_declarations([]) --> [].

procedure_declaration(proc_decl(Name, procedure)) -->
    [identifier(Name)],
    [keyword('PROCEDURE')].

procedure_declaration(proc_decl(Name, function, ReturnType)) -->
    [identifier(Name)],
    [keyword('FUNCTION')],
    [lparen],
    optional_params(_Params),
    [rparen],
    [comma],
    return_type(ReturnType).

optional_params([]) --> [].
% TODO: parameter parsing

return_type(Type) -->
    [identifier(Type)].
return_type(Type) -->
    [keyword(Type)].

%------------------------------------------------------------
% CODE section (main program code)
% code_section ::= 'CODE' statements
%------------------------------------------------------------
code_section(code(Statements)) -->
    [keyword('CODE')],
    statements(Statements).

%------------------------------------------------------------
% Procedure definitions
%------------------------------------------------------------
procedure_definitions([Proc|Procs]) -->
    procedure_definition(Proc),
    !,
    procedure_definitions(Procs).
procedure_definitions([]) --> [].

procedure_definition(procedure(Name, Params, LocalVars, code(Code))) -->
    [identifier(Name)],
    [keyword('PROCEDURE')],
    optional_procedure_params(Params),
    local_declarations(LocalVars),
    [keyword('CODE')],
    statements(Code).

optional_procedure_params([]) --> [].
optional_procedure_params(Params) -->
    [lparen],
    parameter_list(Params),
    [rparen].

parameter_list([]) --> [].
% TODO: full parameter parsing

local_declarations([]) --> [].
% TODO: local variable declarations

%------------------------------------------------------------
% Statements
%------------------------------------------------------------
statements([Stmt|Stmts]) -->
    statement(Stmt),
    !,
    statements(Stmts).
statements([]) --> [].

statement(return) -->
    [keyword('RETURN')].

statement(call(Name, Args)) -->
    [identifier(Name)],
    [lparen],
    argument_list(Args),
    [rparen].

statement(assign(Var, Expr)) -->
    [identifier(Var)],
    [op('=')],
    expression(Expr).

statement(if(Cond, Then, Else)) -->
    [keyword('IF')],
    expression(Cond),
    optional_then,
    statements(Then),
    else_clause(Else),
    [keyword('END')].

statement(loop(Body)) -->
    [keyword('LOOP')],
    statements(Body),
    [keyword('END')].

statement(loop_to(Var, From, To, Body)) -->
    [keyword('LOOP')],
    [identifier(Var)],
    [op('=')],
    expression(From),
    [keyword('TO')],
    expression(To),
    statements(Body),
    [keyword('END')].

%------------------------------------------------------------
% IF statement
%------------------------------------------------------------
optional_then --> [keyword('THEN')].
optional_then --> [].

else_clause(Else) -->
    [keyword('ELSE')],
    statements(Else).
else_clause([]) --> [].

%------------------------------------------------------------
% LOOP statement
%------------------------------------------------------------

%------------------------------------------------------------
% Argument list
%------------------------------------------------------------
argument_list([Arg|Args]) -->
    expression(Arg),
    more_arguments(Args).
argument_list([]) --> [].

more_arguments([Arg|Args]) -->
    [comma],
    expression(Arg),
    more_arguments(Args).
more_arguments([]) --> [].

%------------------------------------------------------------
% Expressions
%------------------------------------------------------------
expression(Expr) -->
    primary(Left),
    expression_rest(Left, Expr).

expression_rest(Left, Expr) -->
    binary_op(Op),
    primary(Right),
    expression_rest(binop(Op, Left, Right), Expr).
expression_rest(Expr, Expr) --> [].

primary(string(S)) -->
    [string(S)].

primary(number(N)) -->
    [number(N)].

primary(var(Name)) -->
    [identifier(Name)].

primary(call(Name, Args)) -->
    [identifier(Name)],
    [lparen],
    argument_list(Args),
    [rparen].

primary(Expr) -->
    [lparen],
    expression(Expr),
    [rparen].

%------------------------------------------------------------
% Binary operators
%------------------------------------------------------------
binary_op(Op) --> [op(Op)].
binary_op(and) --> [keyword('AND')].
binary_op(or) --> [keyword('OR')].
