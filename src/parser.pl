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
    !,  % Cut to prevent backtracking into tokenizer on parse failure
    parse(Tokens, AST).

%------------------------------------------------------------
% parse(+Tokens, -AST)
% Parse token list into AST
%------------------------------------------------------------
parse(Tokens, AST) :-
    phrase(program(AST), Tokens),
    !.  % Cut to prevent backtracking into alternative parses

%------------------------------------------------------------
% end_keyword - matches END or . (period)
% Clarion allows period as shorthand for END
%------------------------------------------------------------
end_keyword --> [keyword('END')].
end_keyword --> [dot].

%------------------------------------------------------------
% Program structure
% program ::= 'PROGRAM' map_section global_declarations code_section procedure_defs
%------------------------------------------------------------
program(program(Map, GlobalDecls, MainCode, Procedures)) -->
    [keyword('PROGRAM')],
    map_section(Map),
    global_declarations(GlobalDecls),
    code_section(MainCode),
    procedure_definitions(Procedures).

%------------------------------------------------------------
% Global declarations (between MAP and CODE)
% Handles CLASS, GROUP, QUEUE, FILE, and variable declarations
%------------------------------------------------------------
global_declarations([Decl|Decls]) -->
    global_declaration(Decl),
    !,
    global_declarations(Decls).
global_declarations([]) --> [].

% CLASS declaration
global_declaration(class(Name, Parent, Attrs, Members)) -->
    [identifier(Name)],
    [keyword('CLASS')],
    optional_parent_class(Parent),
    class_attributes(Attrs),
    class_members(Members),
    end_keyword.

% GROUP declaration
global_declaration(group(Name, Members)) -->
    [identifier(Name)],
    [keyword('GROUP')],
    skip_attributes,
    group_members(Members),
    end_keyword.

% QUEUE declaration
global_declaration(queue(Name, Members)) -->
    [identifier(Name)],
    [keyword('QUEUE')],
    skip_attributes,
    queue_members(Members),
    end_keyword.

% FILE declaration
global_declaration(file(Name, Contents)) -->
    [identifier(Name)],
    [keyword('FILE')],
    skip_attributes,
    file_contents(Contents),
    end_keyword.

% REPORT declaration
global_declaration(report(Name, Bands)) -->
    [identifier(Name)],
    [keyword('REPORT')],
    skip_attributes,
    report_bands(Bands),
    end_keyword.

% Simple variable declaration (e.g., CustomerName STRING(50))
global_declaration(var(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    skip_attributes.

%------------------------------------------------------------
% CLASS support
%------------------------------------------------------------
optional_parent_class(Parent) -->
    [lparen],
    [identifier(Parent)],
    [rparen].
optional_parent_class(none) --> [].

class_attributes(Attrs) -->
    [comma],
    class_attr_list(Attrs).
class_attributes([]) --> [].

class_attr_list([Attr|Attrs]) -->
    class_attr(Attr),
    class_attr_rest(Attrs).

class_attr_rest([Attr|Attrs]) -->
    [comma],
    class_attr(Attr),
    class_attr_rest(Attrs).
class_attr_rest([]) --> [].

class_attr(type) --> [keyword('TYPE')].
class_attr(module(M)) --> [keyword('MODULE')], [lparen], [string(M)], [rparen].
class_attr(Attr) --> [identifier(Attr)].

class_members([Member|Members]) -->
    class_member(Member),
    !,
    class_members(Members).
class_members([]) --> [].

% Class property (data member)
class_member(property(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    \+ [keyword('PROCEDURE')],
    skip_attributes.

% Class method declaration
class_member(method(Name, Params, RetType, Attrs)) -->
    [identifier(Name)],
    [keyword('PROCEDURE')],
    optional_method_params(Params),
    method_return_type(RetType),
    method_attributes(Attrs).

optional_method_params(Params) -->
    [lparen],
    method_param_list(Params),
    [rparen].
optional_method_params([]) --> [].

method_param_list([Param|Params]) -->
    method_param(Param),
    method_param_rest(Params).
method_param_list([]) --> [].

method_param_rest([Param|Params]) -->
    [comma],
    method_param(Param),
    method_param_rest(Params).
method_param_rest([]) --> [].

method_param(param(Type, Name)) -->
    data_type(Type),
    [identifier(Name)].

method_return_type(RetType) -->
    [comma],
    data_type(RetType),
    \+ [keyword('VIRTUAL')].
method_return_type(none) --> [].

method_attributes([Attr|Attrs]) -->
    [comma],
    method_attr(Attr),
    method_attr_rest(Attrs).
method_attributes([]) --> [].

method_attr_rest([Attr|Attrs]) -->
    [comma],
    method_attr(Attr),
    method_attr_rest(Attrs).
method_attr_rest([]) --> [].

method_attr(virtual) --> [keyword('VIRTUAL')].
method_attr(derived) --> [keyword('DERIVED')].
method_attr(private) --> [keyword('PRIVATE')].
method_attr(protected) --> [keyword('PROTECTED')].
method_attr(Attr) --> [identifier(Attr)].

%------------------------------------------------------------
% GROUP/QUEUE members
%------------------------------------------------------------
group_members([Member|Members]) -->
    group_member(Member),
    !,
    group_members(Members).
group_members([]) --> [].

group_member(field(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    skip_attributes.

queue_members(Members) --> group_members(Members).

%------------------------------------------------------------
% FILE contents
%------------------------------------------------------------
file_contents([Item|Items]) -->
    file_item(Item),
    !,
    file_contents(Items).
file_contents([]) --> [].

file_item(key(Name, Fields, Attrs)) -->
    [identifier(Name)],
    [keyword('KEY')],
    [lparen],
    field_list(Fields),
    [rparen],
    skip_attributes.

% Record with optional label (e.g., "Record RECORD" where first Record is a label)
file_item(record(Members)) -->
    [keyword('RECORD')],  % handles both "RECORD" alone and "Record RECORD" (first becomes keyword)
    optional_record_keyword,
    skip_attributes,
    record_members(Members),
    end_keyword.

% If there's another RECORD keyword, consume it (happens when label "Record" parsed as keyword)
optional_record_keyword --> [keyword('RECORD')], !.
optional_record_keyword --> [].

file_item(field(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    skip_attributes.

record_members([Member|Members]) -->
    record_member(Member),
    !,
    record_members(Members).
record_members([]) --> [].

record_member(field(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    skip_attributes.

field_list([Field|Fields]) -->
    [identifier(Field)],
    field_list_rest(Fields).
field_list([]) --> [].

field_list_rest([Field|Fields]) -->
    [comma],
    [identifier(Field)],
    field_list_rest(Fields).
field_list_rest([]) --> [].

%------------------------------------------------------------
% REPORT bands
%------------------------------------------------------------
report_bands([Band|Bands]) -->
    report_band(Band),
    !,
    report_bands(Bands).
report_bands([]) --> [].

% HEADER band
report_band(header(Controls)) -->
    [keyword('HEADER')],
    skip_attributes,
    report_controls(Controls),
    end_keyword.

% FOOTER band
report_band(footer(Controls)) -->
    [keyword('FOOTER')],
    skip_attributes,
    report_controls(Controls),
    end_keyword.

% DETAIL band
report_band(detail(Controls)) -->
    [keyword('DETAIL')],
    skip_attributes,
    report_controls(Controls),
    end_keyword.

% BREAK band (contains nested HEADER/FOOTER)
report_band(break(Expr, Bands)) -->
    [keyword('BREAK')],
    [lparen],
    expression(Expr),
    [rparen],
    report_bands(Bands),
    end_keyword.

% Report controls (STRING, BOX, etc.)
report_controls([Control|Controls]) -->
    report_control(Control),
    !,
    report_controls(Controls).
report_controls([]) --> [].

% STRING control (handles both regular text and picture formats via expression)
report_control(string_control(Text)) -->
    [keyword('STRING')],
    [lparen],
    expression(Text),
    [rparen],
    skip_attributes.

% BOX control
report_control(box_control) -->
    [keyword('BOX')],
    skip_attributes.

%------------------------------------------------------------
% WINDOW controls
%------------------------------------------------------------
window_controls([Control|Controls]) -->
    window_control(Control),
    !,
    window_controls(Controls).
window_controls([]) --> [].

% PROMPT control
window_control(prompt_control(Text)) -->
    [keyword('PROMPT')],
    [lparen],
    expression(Text),
    [rparen],
    skip_attributes.

% ENTRY control
window_control(entry_control(Format)) -->
    [keyword('ENTRY')],
    [lparen],
    expression(Format),
    [rparen],
    skip_attributes.

% BUTTON control
window_control(button_control(Text)) -->
    [keyword('BUTTON')],
    [lparen],
    expression(Text),
    [rparen],
    skip_attributes.

% SPIN control
window_control(spin_control(Format)) -->
    [keyword('SPIN')],
    [lparen],
    expression(Format),
    [rparen],
    skip_attributes.

% STRING control (in window)
window_control(string_control(Text)) -->
    [keyword('STRING')],
    [lparen],
    expression(Text),
    [rparen],
    skip_attributes.

%------------------------------------------------------------
% Data types
%------------------------------------------------------------
data_type('STRING') --> [keyword('STRING')].
data_type('LONG') --> [keyword('LONG')].
data_type('SHORT') --> [keyword('SHORT')].
data_type('BYTE') --> [keyword('BYTE')].
data_type('DECIMAL') --> [keyword('DECIMAL')].
data_type('DATE') --> [keyword('DATE')].
data_type('TIME') --> [keyword('TIME')].
data_type('REAL') --> [keyword('REAL')].
data_type('SREAL') --> [keyword('SREAL')].
data_type('CSTRING') --> [keyword('CSTRING')].
data_type('PSTRING') --> [keyword('PSTRING')].
data_type(custom(Name)) --> [identifier(Name)].

optional_size(size(N)) -->
    [lparen],
    [number(N)],
    [rparen].
optional_size(size(P, D)) -->
    [lparen],
    [number(P)],
    [comma],
    [number(D)],
    [rparen].
% Initial value: BYTE(FALSE), BYTE(TRUE), BYTE(0)
optional_size(init(true)) -->
    [lparen],
    [keyword('TRUE')],
    [rparen].
optional_size(init(false)) -->
    [lparen],
    [keyword('FALSE')],
    [rparen].
optional_size(none) --> [].

%------------------------------------------------------------
% Skip arbitrary attributes (comma-separated identifiers)
%------------------------------------------------------------
skip_attributes -->
    [comma],
    skip_one_attr,
    !,
    skip_attributes.
skip_attributes --> [].

% Skip attribute keywords (but NOT structural keywords like CODE, END, etc.)
skip_one_attr --> [keyword(K)], { \+ structural_keyword(K) }.
skip_one_attr --> [identifier(_)], [lparen], skip_parens_content, [rparen].
skip_one_attr --> [identifier(_)].

% Keywords that should NOT be consumed as attributes
structural_keyword('CODE').
structural_keyword('END').
structural_keyword('PROGRAM').
structural_keyword('MAP').
structural_keyword('PROCEDURE').
structural_keyword('FUNCTION').
structural_keyword('ROUTINE').
structural_keyword('CLASS').
structural_keyword('GROUP').
structural_keyword('QUEUE').
structural_keyword('FILE').
structural_keyword('RECORD').
structural_keyword('KEY').
structural_keyword('IF').
structural_keyword('ELSIF').
structural_keyword('ELSE').
structural_keyword('LOOP').
structural_keyword('CASE').
structural_keyword('RETURN').
structural_keyword('REPORT').
structural_keyword('HEADER').
structural_keyword('FOOTER').
structural_keyword('DETAIL').
structural_keyword('BREAK').
structural_keyword('WINDOW').
structural_keyword('ACCEPT').
structural_keyword('PROMPT').
structural_keyword('ENTRY').
structural_keyword('BUTTON').
structural_keyword('SPIN').

% Skip content inside parentheses, handling nested parens
% Stop when we see the closing rparen (without consuming it)
skip_parens_content --> [lparen], !, skip_parens_content, [rparen], skip_parens_content.
skip_parens_content --> [rparen], { fail }.  % Fail on rparen - caller will consume it
skip_parens_content --> [T], { T \= rparen }, !, skip_parens_content.
skip_parens_content --> [].

%------------------------------------------------------------
% MAP section
% map_section ::= 'MAP' procedure_declarations 'END'
%------------------------------------------------------------
map_section(map(Declarations)) -->
    [keyword('MAP')],
    procedure_declarations(Declarations),
    end_keyword.

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

% Method implementation: ClassName.MethodName PROCEDURE
procedure_definition(method_impl(ClassName, MethodName, Params, LocalVars, code(Code))) -->
    [identifier(ClassName)],
    [dot],
    [identifier(MethodName)],
    [keyword('PROCEDURE')],
    optional_procedure_params(Params),
    local_declarations(LocalVars),
    [keyword('CODE')],
    statements(Code).

% Regular procedure: ProcName PROCEDURE
procedure_definition(procedure(Name, Params, LocalVars, code(Code))) -->
    [identifier(Name)],
    [keyword('PROCEDURE')],
    optional_procedure_params(Params),
    local_declarations(LocalVars),
    [keyword('CODE')],
    statements(Code).

% Routine definition: RoutineName ROUTINE
procedure_definition(routine(Name, Statements)) -->
    [identifier(Name)],
    [keyword('ROUTINE')],
    routine_body(Statements).

routine_body([exit]) --> [keyword('EXIT')].
routine_body(Statements) -->
    statements(Statements).

optional_procedure_params([]) --> [].
optional_procedure_params(Params) -->
    [lparen],
    proc_parameter_list(Params),
    [rparen].

proc_parameter_list([Param|Params]) -->
    proc_parameter(Param),
    proc_param_rest(Params).
proc_parameter_list([]) --> [].

proc_param_rest([Param|Params]) -->
    [comma],
    proc_parameter(Param),
    proc_param_rest(Params).
proc_param_rest([]) --> [].

proc_parameter(param(Type, Name)) -->
    data_type(Type),
    [identifier(Name)].

local_declarations([Decl|Decls]) -->
    local_declaration(Decl),
    !,
    local_declarations(Decls).
local_declarations([]) --> [].

local_declaration(local_var(Name, Type, Size)) -->
    [identifier(Name)],
    data_type(Type),
    optional_size(Size),
    skip_attributes.

% Local REPORT declaration
local_declaration(report(Name, Bands)) -->
    [identifier(Name)],
    [keyword('REPORT')],
    skip_attributes,
    report_bands(Bands),
    end_keyword.

% Local WINDOW declaration (handles both "Window WINDOW(...)" and "WINDOW WINDOW(...)")
local_declaration(window(Name, Title, Controls)) -->
    [identifier(Name)],
    [keyword('WINDOW')],
    [lparen],
    expression(Title),
    [rparen],
    skip_attributes,
    window_controls(Controls),
    end_keyword.

local_declaration(window(window, Title, Controls)) -->
    [keyword('WINDOW')],
    [keyword('WINDOW')],
    [lparen],
    expression(Title),
    [rparen],
    skip_attributes,
    window_controls(Controls),
    end_keyword.

%------------------------------------------------------------
% Statements
%------------------------------------------------------------
statements(Stmts, In, Out) :-
    statements_acc([], Stmts, In, Out).

statements_acc(Acc, Stmts, In, Out) :-
    % Check for procedure boundary using lookahead
    ( at_procedure_boundary(In)
    -> reverse(Acc, Stmts), Out = In
    ; ( phrase(statement(Stmt), In, Rest)
      -> statements_acc([Stmt|Acc], Stmts, Rest, Out)
      ; reverse(Acc, Stmts), Out = In
      )
    ).

% Check if we're at a procedure/method/routine boundary (lookahead, doesn't consume)
at_procedure_boundary([identifier(_), dot, identifier(_), keyword('PROCEDURE')|_]).
at_procedure_boundary([identifier(_), keyword('PROCEDURE')|_]).
at_procedure_boundary([identifier(_), keyword('ROUTINE')|_]).

% RETURN with expression (but not if followed by a procedure boundary)
statement(return(Expr)) -->
    [keyword('RETURN')],
    \+ at_end_of_procedure,
    expression(Expr).

% RETURN without expression
statement(return) -->
    [keyword('RETURN')].

% Check if we're at the end of a procedure (next is a procedure definition)
at_end_of_procedure, [T1, T2, T3, T4] -->
    [T1, T2, T3, T4],
    { at_procedure_boundary([T1, T2, T3, T4]) }.
at_end_of_procedure --> \+ [_].

% DO routine_name
statement(do(Name)) -->
    [keyword('DO')],
    [identifier(Name)].

% Method call: Object.Method(Args)
statement(method_call(Obj, Method, Args)) -->
    [identifier(Obj)],
    [dot],
    [identifier(Method)],
    [lparen],
    argument_list(Args),
    [rparen].

% Assignment to method/property: Object.Property = Expr
% (must come before member_access to handle Obj.Member = Expr)
statement(member_assign(Obj, Member, Expr)) -->
    [identifier(Obj)],
    [dot],
    [identifier(Member)],
    [op('=')],
    expression(Expr).

% Method call without parens (property access or no-arg method): Object.Property
statement(member_access(Obj, Member)) -->
    [identifier(Obj)],
    [dot],
    [identifier(Member)],
    \+ [lparen],
    \+ [op('=')].

% Regular function call
statement(call(Name, Args)) -->
    [identifier(Name)],
    [lparen],
    argument_list(Args),
    [rparen].

% Assignment to SELF.Property
statement(self_assign(Member, Expr)) -->
    [keyword('SELF')],
    [dot],
    [identifier(Member)],
    [op('=')],
    expression(Expr).

% Assignment to PARENT.Method call
statement(parent_call(Method, Args)) -->
    [keyword('PARENT')],
    [dot],
    [identifier(Method)],
    [lparen],
    argument_list(Args),
    [rparen].

% Array subscript assignment: Array[Index] = Expr
statement(array_assign(Array, Index, Expr)) -->
    [identifier(Array)],
    [lbracket],
    expression(Index),
    [rbracket],
    [op('=')],
    expression(Expr).

% Property assignment: Var{PROP:Name} = Expr
statement(prop_assign(Var, Prop, Expr)) -->
    [identifier(Var)],
    [lbrace],
    [identifier(Prop)],
    [rbrace],
    [op('=')],
    expression(Expr).

% Control property assignment: ?Control{PROP:Name} = Expr
statement(control_prop_assign(Control, Prop, Expr)) -->
    [question],
    [identifier(Control)],
    [lbrace],
    [identifier(Prop)],
    [rbrace],
    [op('=')],
    expression(Expr).

% Regular assignment
statement(assign(Var, Expr)) -->
    [identifier(Var)],
    [op('=')],
    expression(Expr).

% Compound assignment: Var += Expr
statement(assign_add(Var, Expr)) -->
    [identifier(Var)],
    [op('+=')],
    expression(Expr).

statement(if(Cond, Then, ElsIfs, Else)) -->
    [keyword('IF')],
    expression(Cond),
    optional_then,
    statements(Then),
    elsif_clauses(ElsIfs),
    else_clause(Else),
    end_keyword.

% LOOP with counter: LOOP Var = From TO To
statement(loop_to(Var, From, To, Body)) -->
    [keyword('LOOP')],
    [identifier(Var)],
    [op('=')],
    expression(From),
    [keyword('TO')],
    expression(To),
    statements(Body),
    end_keyword.

% LOOP WHILE
statement(loop_while(Cond, Body)) -->
    [keyword('LOOP')],
    [keyword('WHILE')],
    expression(Cond),
    statements(Body),
    end_keyword.

% LOOP UNTIL
statement(loop_until(Cond, Body)) -->
    [keyword('LOOP')],
    [keyword('UNTIL')],
    expression(Cond),
    statements(Body),
    end_keyword.

% Simple infinite LOOP
statement(loop(Body)) -->
    [keyword('LOOP')],
    statements(Body),
    end_keyword.

% BREAK
statement(break) -->
    [keyword('BREAK')].

% CYCLE (continue)
statement(cycle) -->
    [keyword('CYCLE')].

% EXIT (for routines)
statement(exit) -->
    [keyword('EXIT')].

% PRINT statement (for reports)
statement(print(Arg)) -->
    [keyword('PRINT')],
    [lparen],
    expression(Arg),
    [rparen].

% CASE statement
statement(case(Expr, Cases, Else)) -->
    [keyword('CASE')],
    expression(Expr),
    case_branches(Cases),
    case_else(Else),
    end_keyword.

% ACCEPT loop (window event loop)
statement(accept(Body)) -->
    [keyword('ACCEPT')],
    statements(Body),
    end_keyword.

% SELECT statement (focus control)
statement(select(Arg)) -->
    [keyword('SELECT')],
    [lparen],
    expression(Arg),
    [rparen].

% BEEP statement
statement(beep) -->
    [keyword('BEEP')].

% DISPLAY statement
statement(display) -->
    [keyword('DISPLAY')].

%------------------------------------------------------------
% IF statement
%------------------------------------------------------------
optional_then --> [keyword('THEN')].
optional_then --> [].

elsif_clauses([elsif(Cond, Stmts)|Rest]) -->
    [keyword('ELSIF')],
    expression(Cond),
    optional_then,
    statements(Stmts),
    elsif_clauses(Rest).
elsif_clauses([]) --> [].

else_clause(Else) -->
    [keyword('ELSE')],
    statements(Else).
else_clause([]) --> [].

%------------------------------------------------------------
% CASE statement branches
%------------------------------------------------------------
case_branches([case_of(Value, Stmts)|Rest]) -->
    [keyword('OF')],
    expression(Value),
    statements(Stmts),
    case_branches(Rest).
case_branches([]) --> [].

case_else(Else) -->
    [keyword('ELSE')],
    statements(Else).
case_else([]) --> [].

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

primary(String) -->
    [string(S1)],
    adjacent_strings(S1, String).

% Handle adjacent strings (implicit concatenation in Clarion)
adjacent_strings(Acc, Result) -->
    [string(S)],
    !,
    { atom_concat(Acc, S, NewAcc) },
    adjacent_strings(NewAcc, Result).
adjacent_strings(Acc, string(Acc)) --> [].

primary(number(N)) -->
    [number(N)].

% Negative number
primary(neg(N)) -->
    [op('-')],
    [number(N)].

% NOT operator (logical negation)
primary(not(Expr)) -->
    [keyword('NOT')],
    primary(Expr).

% SELF.Property
primary(self_access(Member)) -->
    [keyword('SELF')],
    [dot],
    [identifier(Member)].

% Method call: Obj.Method(Args)
primary(method_call(Obj, Method, Args)) -->
    [identifier(Obj)],
    [dot],
    [identifier(Method)],
    [lparen],
    argument_list(Args),
    [rparen].

% Property access: Obj.Property (no parens)
primary(member_access(Obj, Member)) -->
    [identifier(Obj)],
    [dot],
    [identifier(Member)],
    \+ [lparen].

% Function call with args
primary(call(Name, Args)) -->
    [identifier(Name)],
    [lparen],
    argument_list(Args),
    [rparen].

% Keyword used as function (DATE, TIME, etc.)
primary(call(Name, Args)) -->
    [keyword(Name)],
    { \+ structural_keyword(Name) },
    [lparen],
    argument_list(Args),
    [rparen].

% Simple variable
primary(var(Name)) -->
    [identifier(Name)].

% WINDOW keyword used as variable (common pattern in Clarion)
primary(var('WINDOW')) -->
    [keyword('WINDOW')].

% Picture format specifier: @D2, @N10.2, @n$12.2, etc.
primary(picture(Name)) -->
    [at],
    [identifier(Name)].

% Picture format with currency: @n$12.2
primary(picture(Pic)) -->
    [at],
    [identifier(Base)],
    [dollar],
    [number(Num)],
    { atom_concat(Base, '$', Tmp),
      atom_number(NumAtom, Num),
      atom_concat(Tmp, NumAtom, Pic) }.

% Picture format with decimal: @n12.2 (tokenizes as @n12 . 2)
primary(picture(Pic)) -->
    [at],
    [identifier(Base)],
    [dot],
    [number(Frac)],
    { atom_number(FracAtom, Frac),
      atom_concat(Base, '.', Tmp),
      atom_concat(Tmp, FracAtom, Pic) }.

% Control reference: ?ControlName
primary(control_ref(Name)) -->
    [question],
    [identifier(Name)].

% Boolean literals
primary(true) --> [keyword('TRUE')].
primary(false) --> [keyword('FALSE')].

% Parenthesized expression
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
