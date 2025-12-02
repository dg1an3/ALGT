%============================================================
% interpreter.pl - Clarion AST Execution Engine
%
% Executes Clarion programs from their AST representation.
% Supports: variables, expressions, control flow, procedures,
%           file I/O operations
%============================================================

:- module(interpreter, [
    run_file/1,
    run_ast/1,
    run_ast/2
]).

:- use_module(parser).

:- discontiguous builtin_call/5.

%------------------------------------------------------------
% State Management
%
% State is represented as: state(Vars, Procs, Output, Files, ErrorCode, Classes, Self)
%   Vars      = list of var(Name, Value) pairs
%   Procs     = list of procedure definitions from AST
%   Output    = accumulated output (for testing/capture)
%   Files     = list of file_state(...) for open files
%   ErrorCode = last error code (0 = success)
%   Classes   = list of class definitions from AST
%   Self      = current self context: none | self_context(VarName, ClassName, ParentClass)
%
% Instance values are stored as: instance(ClassName, Properties)
%   Properties = list of prop(Name, Value) pairs
%
% file_state(Name, Prefix, Keys, Fields, Records, RecordBuffer, Position, IsOpen)
%   Name         = file name atom
%   Prefix       = field prefix (e.g., 'Cust')
%   Keys         = list of key(KeyName, FieldList)
%   Fields       = list of field(Name, Type, Size)
%   Records      = list of record data (list of field values)
%   RecordBuffer = current record buffer (list of field values)
%   Position     = current position in file (0-based, -1 = before first)
%   IsOpen       = true/false
%------------------------------------------------------------

empty_state(state([], [], [], [], 0, [], none)).

% State accessors
get_vars(state(Vars, _, _, _, _, _, _), Vars).
get_procs(state(_, Procs, _, _, _, _, _), Procs).
get_output(state(_, _, Out, _, _, _, _), Out).
get_files(state(_, _, _, Files, _, _, _), Files).
get_error(state(_, _, _, _, Err, _, _), Err).
get_classes(state(_, _, _, _, _, Classes, _), Classes).
get_self(state(_, _, _, _, _, _, Self), Self).

% Get variable value from state
% Handles both regular variables and prefixed file fields (Prefix:Field)
get_var(Name, State, Value) :-
    ( parse_prefixed_name(Name, Prefix, FieldName)
    -> get_prefixed_var(Prefix, FieldName, State, Value)
    ;  get_vars(State, Vars),
       member(var(Name, Value), Vars)
    ), !.
get_var(Name, _, _) :-
    format(user_error, "Error: Undefined variable '~w'~n", [Name]),
    fail.

% Set variable value in state
% Handles both regular variables and prefixed file fields (Prefix:Field)
set_var(Name, Value, StateIn, StateOut) :-
    ( parse_prefixed_name(Name, Prefix, FieldName)
    -> set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut)
    ;  StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self),
       ( select(var(Name, _), Vars, RestVars)
       -> NewVars = [var(Name, Value)|RestVars]
       ;  NewVars = [var(Name, Value)|Vars]
       ),
       StateOut = state(NewVars, Procs, Out, Files, Err, Classes, Self)
    ).

% Parse a prefixed name like 'Cust:CustomerID' into prefix and field
parse_prefixed_name(Name, Prefix, FieldName) :-
    atom(Name),
    atom_string(Name, NameStr),
    sub_string(NameStr, Before, 1, After, ":"),
    Before > 0, After > 0,
    sub_string(NameStr, 0, Before, _, PrefixStr),
    ColonPos is Before + 1,
    sub_string(NameStr, ColonPos, After, 0, FieldStr),
    atom_string(Prefix, PrefixStr),
    atom_string(FieldName, FieldStr).

% Get value of prefixed variable (file field)
get_prefixed_var(Prefix, FieldName, State, Value) :-
    find_file_by_prefix(Prefix, State, FileState),
    ( FieldName = 'Record'
    -> FileState = file_state(_, _, _, _, _, Value, _, _)  % Return whole buffer
    ;  get_buffer_field(FieldName, FileState, Value)
    ).

% Set value of prefixed variable (file field)
set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut) :-
    find_file_by_prefix(Prefix, StateIn, FileState),
    FileState = file_state(FileName, _, _, _, _, _, _, _),
    ( FieldName = 'Record'
    -> % Can't directly set whole record this way
       StateOut = StateIn
    ;  set_buffer_field(FieldName, Value, FileState, NewFileState),
       set_file_state(FileName, NewFileState, StateIn, StateOut)
    ).

% Find file by its prefix
find_file_by_prefix(Prefix, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(_, Prefix, _, _, _, _, _, _), !.

% Also try to match file name directly (for ByID, ByName key references)
find_file_by_key_prefix(Prefix, KeyName, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(_, Prefix, Keys, _, _, _, _, _),
    member(key(KeyName, _), Keys), !.

% Set error code
set_error(ErrCode, state(Vars, Procs, Out, Files, _, Classes, Self),
                   state(Vars, Procs, Out, Files, ErrCode, Classes, Self)).

% Set self context
set_self(NewSelf, state(Vars, Procs, Out, Files, Err, Classes, _),
                  state(Vars, Procs, Out, Files, Err, Classes, NewSelf)).

% Get procedure definition from state
get_proc(Name, State, Proc) :-
    get_procs(State, Procs),
    member(Proc, Procs),
    Proc = procedure(Name, _, _, _), !.
get_proc(Name, _, _) :-
    format(user_error, "Error: Undefined procedure '~w'~n", [Name]),
    fail.

% Add output to state
add_output(Text, state(Vars, Procs, Out, Files, Err, Classes, Self),
                 state(Vars, Procs, [Text|Out], Files, Err, Classes, Self)).

% Get accumulated output (in correct order)
get_output_list(State, Output) :-
    get_output(State, Out),
    reverse(Out, Output).

%------------------------------------------------------------
% File State Management
%------------------------------------------------------------

% Get file state by name
get_file_state(Name, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(Name, _, _, _, _, _, _, _), !.

% Update file state
set_file_state(Name, NewFileState,
               state(Vars, Procs, Out, Files, Err, Classes, Self),
               state(Vars, Procs, Out, NewFiles, Err, Classes, Self)) :-
    NewFileState = file_state(Name, _, _, _, _, _, _, _),
    ( select(file_state(Name, _, _, _, _, _, _, _), Files, RestFiles)
    -> NewFiles = [NewFileState|RestFiles]
    ;  NewFiles = [NewFileState|Files]
    ).

% Get record buffer field value
get_buffer_field(FieldName, file_state(_, _, _, Fields, _, Buffer, _, _), Value) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Buffer, Value), !.
get_buffer_field(FieldName, _, _) :-
    format(user_error, "Error: Unknown field '~w'~n", [FieldName]),
    fail.

% Set record buffer field value
set_buffer_field(FieldName, Value,
                 file_state(Name, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
                 file_state(Name, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open)) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    replace_nth0(Index, Buffer, Value, NewBuffer), !.

% Replace element at index in list
replace_nth0(0, [_|T], X, [X|T]) :- !.
replace_nth0(N, [H|T], X, [H|R]) :-
    N > 0,
    N1 is N - 1,
    replace_nth0(N1, T, X, R).

%------------------------------------------------------------
% Main Entry Points
%------------------------------------------------------------

% Run a Clarion file by filename
run_file(FileName) :-
    format("Loading: ~w~n", [FileName]),
    parser:parse_file(FileName, AST),
    format("Executing...~n~n", []),
    run_ast(AST).

% Run an AST (prints output to stdout)
run_ast(AST) :-
    run_ast(AST, _FinalState).

% Run an AST and return final state
run_ast(program(_, GlobalDecls, code(Statements), Procedures), FinalState) :-
    empty_state(InitState),
    % Initialize state with procedures and global variables
    init_procedures(Procedures, InitState, State1),
    init_globals(GlobalDecls, State1, State2),
    % Execute main code section
    exec_statements(Statements, State2, FinalState, _Control).

% Support legacy 3-argument AST form
run_ast(program(_, code(Statements), Procedures), FinalState) :-
    empty_state(InitState),
    init_procedures(Procedures, InitState, State1),
    exec_statements(Statements, State1, FinalState, _Control).

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

% Load procedure definitions into state
init_procedures([], State, State).
init_procedures([Proc|Procs], state(Vars, ExistingProcs, Out, Files, Err, Classes, Self), FinalState) :-
    init_procedures(Procs, state(Vars, [Proc|ExistingProcs], Out, Files, Err, Classes, Self), FinalState).

% Initialize global declarations (variables, files, and classes)
init_globals([], State, State).
init_globals([var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, SizeSpec, DefaultVal),
    set_var(Name, DefaultVal, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([file(Name, Attrs, Contents)|Rest], StateIn, StateOut) :-
    init_file(Name, Attrs, Contents, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([class(Name, Parent, Attrs, Members)|Rest], StateIn, StateOut) :-
    init_class(Name, Parent, Attrs, Members, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([group(Name, Fields)|Rest], StateIn, StateOut) :-
    init_group(Name, Fields, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([_|Rest], StateIn, StateOut) :-
    % Skip other declarations (queues, arrays, etc. for now)
    init_globals(Rest, StateIn, StateOut).

% Initialize a GROUP as a compound variable
init_group(Name, Fields, StateIn, StateOut) :-
    create_group_value(Fields, GroupValue),
    set_var(Name, group_val(Fields, GroupValue), StateIn, StateOut).

% Create default values for group fields
create_group_value([], []).
create_group_value([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_group_value(Rest, Values).

% Set a field value in a GROUP
set_group_field(FieldName, Value, Fields, Values, NewValues) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    replace_nth0(Index, Values, Value, NewValues), !.
set_group_field(FieldName, _, _, Values, Values) :-
    format(user_error, "Error: Unknown GROUP field '~w'~n", [FieldName]).

% Get a field value from a GROUP
get_group_field(FieldName, Fields, Values, Value) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Values, Value), !.
get_group_field(FieldName, _, _, 0) :-
    format(user_error, "Error: Unknown GROUP field '~w'~n", [FieldName]).

% Set an element in an array (0-based index)
set_array_element(0, Value, [_|Rest], [Value|Rest]) :- !.
set_array_element(Idx, Value, [H|T], [H|NewT]) :-
    Idx > 0,
    Idx1 is Idx - 1,
    set_array_element(Idx1, Value, T, NewT).
set_array_element(Idx, Value, [], NewList) :-
    % Extend array if needed
    Idx >= 0,
    length(Padding, Idx),
    maplist(=(0), Padding),
    append(Padding, [Value], NewList).

% Get an element from an array (0-based index)
get_array_element(0, [H|_], H) :- !.
get_array_element(Idx, [_|T], Value) :-
    Idx > 0,
    Idx1 is Idx - 1,
    get_array_element(Idx1, T, Value).
get_array_element(_, [], 0).  % Out of bounds returns 0

% Initialize a class definition
init_class(Name, Parent, Attrs, Members, StateIn, StateOut) :-
    StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self),
    ClassDef = class_def(Name, Parent, Attrs, Members),
    StateOut = state(Vars, Procs, Out, Files, Err, [ClassDef|Classes], Self).

% Initialize a file declaration
init_file(Name, Attrs, Contents, StateIn, StateOut) :-
    % Extract prefix from attributes (PRE(xxx))
    ( member(pre(Prefix), Attrs) -> true ; Prefix = '' ),
    % Extract keys and fields from contents
    extract_keys(Contents, Keys),
    extract_record_fields(Contents, Fields),
    % Create empty record buffer with default values
    create_empty_buffer(Fields, Buffer),
    % Create file state (not open initially)
    FileState = file_state(Name, Prefix, Keys, Fields, [], Buffer, -1, false),
    set_file_state(Name, FileState, StateIn, StateOut).

% Extract key definitions from file contents
extract_keys([], []).
extract_keys([key(KeyName, KeyFields, _)|Rest], [key(KeyName, KeyFields)|Keys]) :-
    extract_keys(Rest, Keys).
extract_keys([_|Rest], Keys) :-
    extract_keys(Rest, Keys).

% Extract record fields from file contents
extract_record_fields([], []).
extract_record_fields([record(Fields)|_], Fields) :- !.
extract_record_fields([_|Rest], Fields) :-
    extract_record_fields(Rest, Fields).

% Create empty buffer with default values for each field
create_empty_buffer([], []).
create_empty_buffer([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_empty_buffer(Rest, Values).

% Default values by type
default_value('STRING', _, "").
default_value('CSTRING', _, "").
default_value('PSTRING', _, "").
default_value('LONG', _, 0).
default_value('SHORT', _, 0).
default_value('BYTE', _, 0).
default_value('DECIMAL', _, 0).
default_value('REAL', _, 0.0).
default_value('SREAL', _, 0.0).
default_value('DATE', _, 0).
default_value('TIME', _, 0).
default_value(_, _, 0).  % Default for unknown types

%------------------------------------------------------------
% Statement Execution
%
% exec_statements(+Stmts, +StateIn, -StateOut, -Control)
% Control = normal | return | return(Value) | break | cycle
%------------------------------------------------------------

exec_statements([], State, State, normal).
exec_statements([Stmt|Stmts], StateIn, StateOut, Control) :-
    exec_statement(Stmt, StateIn, State1, StmtControl),
    ( StmtControl = normal
    -> exec_statements(Stmts, State1, StateOut, Control)
    ;  StateOut = State1, Control = StmtControl
    ).

%------------------------------------------------------------
% Individual Statement Handlers
%------------------------------------------------------------

% Procedure/function call (as statement)
exec_statement(call(Name, Args), StateIn, StateOut, normal) :-
    exec_call(Name, Args, StateIn, StateOut, _Result).

% Assignment
exec_statement(assign(VarName, Expr), StateIn, StateOut, normal) :-
    eval_expr(Expr, StateIn, Value),
    set_var(VarName, Value, StateIn, StateOut).

% Method call (as statement)
exec_statement(method_call(ObjName, MethodName, Args), StateIn, StateOut, normal) :-
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, _Result).

% SELF assignment (inside method)
exec_statement(self_assign(PropName, Expr), StateIn, StateOut, normal) :-
    eval_expr(Expr, StateIn, Value),
    get_self(StateIn, self_context(VarName, _, _)),
    get_var(VarName, StateIn, Instance),
    set_instance_prop(PropName, Value, Instance, NewInstance),
    set_var(VarName, NewInstance, StateIn, StateOut).

% PARENT method call
exec_statement(parent_call(MethodName, Args), StateIn, StateOut, normal) :-
    exec_parent_call(MethodName, Args, StateIn, StateOut, _Result).

% GROUP member assignment: GroupName.FieldName = Value
exec_statement(member_assign(GroupName, FieldName, Expr), StateIn, StateOut, normal) :-
    eval_expr(Expr, StateIn, Value),
    get_var(GroupName, StateIn, GroupVal),
    ( GroupVal = group_val(Fields, Values)
    -> set_group_field(FieldName, Value, Fields, Values, NewValues),
       set_var(GroupName, group_val(Fields, NewValues), StateIn, StateOut)
    ; GroupVal = instance(_, _)
    -> % It's a class instance, use instance property setter
       set_instance_prop(FieldName, Value, GroupVal, NewInstance),
       set_var(GroupName, NewInstance, StateIn, StateOut)
    ;  format(user_error, "Error: ~w is not a GROUP or instance~n", [GroupName]),
       StateOut = StateIn
    ).

% Array assignment: ArrayName[Index] = Value
exec_statement(array_assign(ArrayName, IndexExpr, Expr), StateIn, StateOut, normal) :-
    eval_expr(IndexExpr, StateIn, Index),
    eval_expr(Expr, StateIn, Value),
    get_var(ArrayName, StateIn, ArrayVal),
    ( ArrayVal = array(Elements)
    -> Idx is Index - 1,  % Clarion arrays are 1-based
       set_array_element(Idx, Value, Elements, NewElements),
       set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ;  % If not already an array, create one
       set_var(ArrayName, Value, StateIn, StateOut)  % Simple fallback
    ).

exec_statement(assign_add(VarName, Expr), StateIn, StateOut, normal) :-
    eval_expr(Expr, StateIn, Val),
    get_var(VarName, StateIn, CurrentVal),
    NewVal is CurrentVal + Val,
    set_var(VarName, NewVal, StateIn, StateOut).

% Return (no value)
exec_statement(return, State, State, return).

% Return with value
exec_statement(return(Expr), StateIn, StateIn, return(Value)) :-
    eval_expr(Expr, StateIn, Value).

% IF statement (4-arg form with ELSIF)
exec_statement(if(Cond, ThenStmts, ElsifClauses, ElseStmts), StateIn, StateOut, Control) :-
    eval_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_elsifs(ElsifClauses, ElseStmts, StateIn, StateOut, Control)
    ).

% IF statement (3-arg legacy form)
exec_statement(if(Cond, ThenStmts, ElseStmts), StateIn, StateOut, Control) :-
    \+ is_list(ElseStmts),  % Disambiguate
    eval_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_statements(ElseStmts, StateIn, StateOut, Control)
    ).

% LOOP (infinite - must break)
exec_statement(loop(Body), StateIn, StateOut, Control) :-
    exec_loop_infinite(Body, StateIn, StateOut, Control).

% LOOP TO (counted)
exec_statement(loop_to(Var, FromExpr, ToExpr, Body), StateIn, StateOut, Control) :-
    eval_expr(FromExpr, StateIn, From),
    eval_expr(ToExpr, StateIn, To),
    set_var(Var, From, StateIn, State1),
    exec_loop_to(Var, To, Body, State1, StateOut, Control).

% LOOP WHILE
exec_statement(loop_while(Cond, Body), StateIn, StateOut, Control) :-
    exec_loop_while(Cond, Body, StateIn, StateOut, Control).

% LOOP UNTIL
exec_statement(loop_until(Cond, Body), StateIn, StateOut, Control) :-
    exec_loop_until(Cond, Body, StateIn, StateOut, Control).

% BREAK
exec_statement(break, State, State, break).

% CYCLE
exec_statement(cycle, State, State, cycle).

% CASE statement
exec_statement(case(Expr, Cases, ElseStmts), StateIn, StateOut, Control) :-
    eval_expr(Expr, StateIn, Value),
    exec_case(Value, Cases, ElseStmts, StateIn, StateOut, Control).

% DO routine call
exec_statement(do(RoutineName), StateIn, StateOut, Control) :-
    exec_routine(RoutineName, StateIn, StateOut, Control).

% EXIT (from routine)
exec_statement(exit, State, State, exit).

% Catch-all for unimplemented statements
exec_statement(Stmt, State, State, normal) :-
    format(user_error, "Warning: Unimplemented statement: ~w~n", [Stmt]).

%------------------------------------------------------------
% ELSIF handling
%------------------------------------------------------------

exec_elsifs([], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_elsifs([elsif(Cond, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control) :-
    eval_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(Stmts, StateIn, StateOut, Control)
    ;  exec_elsifs(Rest, ElseStmts, StateIn, StateOut, Control)
    ).

%------------------------------------------------------------
% Loop Execution
%------------------------------------------------------------

exec_loop_infinite(Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break -> StateOut = State1, Control = normal
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; % BodyControl = normal or cycle
      exec_loop_infinite(Body, State1, StateOut, Control)
    ).

exec_loop_to(Var, To, Body, StateIn, StateOut, Control) :-
    get_var(Var, StateIn, Current),
    ( Current > To
    -> StateOut = StateIn, Control = normal
    ;  exec_statements(Body, StateIn, State1, BodyControl),
       ( BodyControl = break -> StateOut = State1, Control = normal
       ; BodyControl = return -> StateOut = State1, Control = return
       ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
       ; Next is Current + 1,
         set_var(Var, Next, State1, State2),
         exec_loop_to(Var, To, Body, State2, StateOut, Control)
       )
    ).

exec_loop_while(Cond, Body, StateIn, StateOut, Control) :-
    eval_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(Body, StateIn, State1, BodyControl),
       ( BodyControl = break -> StateOut = State1, Control = normal
       ; BodyControl = return -> StateOut = State1, Control = return
       ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
       ; exec_loop_while(Cond, Body, State1, StateOut, Control)
       )
    ;  StateOut = StateIn, Control = normal
    ).

exec_loop_until(Cond, Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break -> StateOut = State1, Control = normal
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; eval_expr(Cond, State1, CondVal),
      ( is_truthy(CondVal)
      -> StateOut = State1, Control = normal
      ;  exec_loop_until(Cond, Body, State1, StateOut, Control)
      )
    ).

%------------------------------------------------------------
% CASE Execution
%------------------------------------------------------------

exec_case(_, [], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_case(Value, [case_of(CaseVal, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control) :-
    eval_expr(CaseVal, StateIn, MatchVal),
    ( Value = MatchVal
    -> exec_statements(Stmts, StateIn, StateOut, Control)
    ;  exec_case(Value, Rest, ElseStmts, StateIn, StateOut, Control)
    ).

%------------------------------------------------------------
% Routine Execution
%------------------------------------------------------------

% Get routine definition from state
get_routine(Name, State, Routine) :-
    get_procs(State, Procs),
    member(Routine, Procs),
    Routine = routine(Name, _), !.
get_routine(Name, _, _) :-
    format(user_error, "Error: Undefined routine '~w'~n", [Name]),
    fail.

% Execute a routine (local GOSUB-like call)
exec_routine(Name, StateIn, StateOut, Control) :-
    get_routine(Name, StateIn, routine(Name, Body)),
    exec_statements(Body, StateIn, StateOut, RoutineControl),
    % EXIT in routine just means normal return from routine
    ( RoutineControl = exit -> Control = normal ; Control = RoutineControl ).

%------------------------------------------------------------
% Procedure/Function Calls
%------------------------------------------------------------

exec_call(Name, Args, StateIn, StateOut, Result) :-
    % First check for built-in functions
    ( builtin_call(Name, Args, StateIn, StateOut, Result)
    -> true
    ; % User-defined procedure
      get_proc(Name, StateIn, procedure(Name, Params, LocalVars, code(Body))),
      % Evaluate arguments
      eval_args(Args, StateIn, ArgVals),
      % Set up local scope with parameters
      bind_params(Params, ArgVals, StateIn, State1),
      init_locals(LocalVars, State1, State2),
      % Execute procedure body
      exec_statements(Body, State2, State3, Control),
      % Extract return value if any
      ( Control = return(V) -> Result = V ; Result = none ),
      % Restore outer scope (keep output, files, error, classes changes)
      StateIn = state(OuterVars, Procs, _, _, _, _, _),
      State3 = state(_, _, NewOut, NewFiles, NewErr, NewClasses, _),
      StateOut = state(OuterVars, Procs, NewOut, NewFiles, NewErr, NewClasses, none)
    ).

eval_args([], _, []).
eval_args([Arg|Args], State, [Val|Vals]) :-
    eval_expr(Arg, State, Val),
    eval_args(Args, State, Vals).

bind_params([], [], State, State).
bind_params([param(_, Name)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
bind_params([], [_|_], State, State).  % More args than params - ignore extras
bind_params([_|_], [], State, State).  % More params than args - leave unbound

init_locals([], State, State).
init_locals([var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, custom(ClassName), _)|Rest], StateIn, StateOut) :-
    % Create a class instance
    create_instance(ClassName, StateIn, Instance),
    set_var(Name, Instance, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    Type \= custom(_),
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).

%------------------------------------------------------------
% Class Instance Management
%------------------------------------------------------------

% Create a new instance of a class with default property values
create_instance(ClassName, State, instance(ClassName, Props)) :-
    get_class_def(ClassName, State, class_def(ClassName, Parent, _, Members)),
    % Get inherited properties from parent
    ( Parent \= none
    -> get_inherited_props(Parent, State, InheritedProps)
    ;  InheritedProps = []
    ),
    % Get own properties
    get_class_props(Members, OwnProps),
    append(InheritedProps, OwnProps, Props).

% Get class definition by name
get_class_def(ClassName, State, ClassDef) :-
    get_classes(State, Classes),
    member(ClassDef, Classes),
    ClassDef = class_def(ClassName, _, _, _), !.
get_class_def(ClassName, _, _) :-
    format(user_error, "Error: Undefined class '~w'~n", [ClassName]),
    fail.

% Get inherited properties from parent class chain
get_inherited_props(none, _, []) :- !.
get_inherited_props(ParentName, State, AllProps) :-
    get_class_def(ParentName, State, class_def(ParentName, GrandParent, _, Members)),
    get_class_props(Members, ParentProps),
    get_inherited_props(GrandParent, State, GrandProps),
    append(GrandProps, ParentProps, AllProps).

% Extract property definitions from class members
get_class_props([], []).
get_class_props([property(Name, Type, Size)|Rest], [prop(Name, Default)|Props]) :-
    default_value(Type, Size, Default),
    get_class_props(Rest, Props).
get_class_props([method(_, _, _, _)|Rest], Props) :-
    get_class_props(Rest, Props).

% Get property value from instance
get_instance_prop(PropName, instance(_, Props), Value) :-
    member(prop(PropName, Value), Props), !.
get_instance_prop(PropName, _, _) :-
    format(user_error, "Error: Unknown property '~w'~n", [PropName]),
    fail.

% Set property value in instance, returns new instance
set_instance_prop(PropName, Value, instance(Class, Props), instance(Class, NewProps)) :-
    ( select(prop(PropName, _), Props, RestProps)
    -> NewProps = [prop(PropName, Value)|RestProps]
    ;  NewProps = [prop(PropName, Value)|Props]
    ).

%------------------------------------------------------------
% Method Call Execution
%------------------------------------------------------------

% Execute a method call: ObjName.MethodName(Args)
exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, Result) :-
    % Get the instance
    get_var(ObjName, StateIn, Instance),
    Instance = instance(ClassName, _),
    % Find the method implementation (check class hierarchy)
    find_method_impl(ClassName, MethodName, StateIn, MethodImpl),
    MethodImpl = method_impl(ImplClass, MethodName, Params, LocalVars, code(Body)),
    % Evaluate arguments
    eval_args(Args, StateIn, ArgVals),
    % Set up method context with SELF
    get_class_def(ClassName, StateIn, class_def(ClassName, ParentClass, _, _)),
    set_self(self_context(ObjName, ImplClass, ParentClass), StateIn, State1),
    % Bind parameters
    bind_params(Params, ArgVals, State1, State2),
    % Initialize local variables
    init_locals(LocalVars, State2, State3),
    % Execute method body
    exec_statements(Body, State3, State4, Control),
    % Extract return value
    ( Control = return(V) -> Result = V ; Result = none ),
    % Restore state (keep instance changes, clear self context)
    State4 = state(_, Procs, NewOut, NewFiles, NewErr, NewClasses, _),
    StateIn = state(_, _, _, _, _, _, _),
    % Get updated instance from State4
    get_var(ObjName, State4, UpdatedInstance),
    set_var(ObjName, UpdatedInstance, StateIn, State5),
    State5 = state(Vars5, _, _, _, _, _, _),
    StateOut = state(Vars5, Procs, NewOut, NewFiles, NewErr, NewClasses, none).

% Execute a PARENT method call
exec_parent_call(MethodName, Args, StateIn, StateOut, Result) :-
    get_self(StateIn, self_context(ObjName, CurrentClass, _)),
    % Get the parent class of current implementation class
    get_class_def(CurrentClass, StateIn, class_def(CurrentClass, ParentClass, _, _)),
    ( ParentClass \= none
    -> % Find method in parent
       find_method_impl(ParentClass, MethodName, StateIn, MethodImpl),
       MethodImpl = method_impl(ImplClass, MethodName, Params, LocalVars, code(Body)),
       % Evaluate arguments
       eval_args(Args, StateIn, ArgVals),
       % Update self context to parent's parent for nested PARENT calls
       get_class_def(ImplClass, StateIn, class_def(ImplClass, GrandParent, _, _)),
       set_self(self_context(ObjName, ImplClass, GrandParent), StateIn, State1),
       % Bind parameters and locals
       bind_params(Params, ArgVals, State1, State2),
       init_locals(LocalVars, State2, State3),
       % Execute
       exec_statements(Body, State3, State4, Control),
       ( Control = return(V) -> Result = V ; Result = none ),
       % Restore self context
       get_self(StateIn, OrigSelf),
       set_self(OrigSelf, State4, StateOut)
    ;  format(user_error, "Error: No parent class for PARENT call~n", []),
       StateOut = StateIn, Result = none
    ).

% Find method implementation in class hierarchy
find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    get_procs(State, Procs),
    member(MethodImpl, Procs),
    MethodImpl = method_impl(ClassName, MethodName, _, _, _), !.
find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    % Not in this class, try parent
    get_class_def(ClassName, State, class_def(ClassName, ParentClass, _, _)),
    ParentClass \= none,
    find_method_impl(ParentClass, MethodName, State, MethodImpl).
find_method_impl(ClassName, MethodName, _, _) :-
    format(user_error, "Error: Method '~w.~w' not found~n", [ClassName, MethodName]),
    fail.

%------------------------------------------------------------
% Built-in Functions
%------------------------------------------------------------

% MESSAGE(text) or MESSAGE(text, title)
builtin_call('MESSAGE', Args, StateIn, StateOut, none) :-
    ( Args = [TextExpr]
    -> eval_expr(TextExpr, StateIn, Text),
       format("MESSAGE: ~w~n", [Text])
    ; Args = [TextExpr, TitleExpr]
    -> eval_expr(TextExpr, StateIn, Text),
       eval_expr(TitleExpr, StateIn, Title),
       format("MESSAGE [~w]: ~w~n", [Title, Text])
    ; Args = [TextExpr, TitleExpr | _Rest]
    -> eval_expr(TextExpr, StateIn, Text),
       eval_expr(TitleExpr, StateIn, Title),
       format("MESSAGE [~w]: ~w~n", [Title, Text])
    ),
    add_output(message(Text), StateIn, StateOut).

% CLIP(string) - remove trailing spaces
builtin_call('CLIP', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_string(Str, S) ; S = Str ),
    string_codes(S, Codes),
    reverse(Codes, Rev),
    drop_spaces(Rev, TrimmedRev),
    reverse(TrimmedRev, Trimmed),
    string_codes(Result, Trimmed).

drop_spaces([32|Rest], Result) :- !, drop_spaces(Rest, Result).
drop_spaces(List, List).

% LEN(string) - string length
builtin_call('LEN', [Expr], StateIn, StateIn, Len) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_length(Str, Len) ; string_length(Str, Len) ).

% CHR(code) - character from code
builtin_call('CHR', [Expr], StateIn, StateIn, Char) :-
    eval_expr(Expr, StateIn, Code),
    char_code(Char, Code).

% VAL(char) - code from character
builtin_call('VAL', [Expr], StateIn, StateIn, Code) :-
    eval_expr(Expr, StateIn, Char),
    ( atom(Char) -> atom_codes(Char, [Code|_]) ; string_codes(Char, [Code|_]) ).

% TODAY() - current date (returns 0 for now, would need real date math)
builtin_call('TODAY', [], StateIn, StateIn, 0).

% CLOCK() - current time (returns 0 for now)
builtin_call('CLOCK', [], StateIn, StateIn, 0).

% FORMAT(value, picture) - Format a value according to picture
builtin_call('FORMAT', [ValueExpr, PictureExpr], StateIn, StateIn, Result) :-
    eval_expr(ValueExpr, StateIn, Value),
    eval_expr(PictureExpr, StateIn, Picture),
    format_value(Value, Picture, Result).

% Format a value according to a picture specification
format_value(Value, picture(Pic), Result) :-
    format_with_picture(Value, Pic, Result), !.
format_value(Value, Pic, Result) :-
    atom(Pic),
    format_with_picture(Value, Pic, Result), !.
format_value(Value, _, Result) :-
    to_string(Value, Result).

% Format with specific picture codes
format_with_picture(Value, 'D2', Result) :-
    % @D2 = MM/DD/YY format (simplified - just return value as string for now)
    to_string(Value, Result).
format_with_picture(Value, 'D1', Result) :-
    % @D1 = MM/DD/YYYY format
    to_string(Value, Result).
format_with_picture(Value, Pic, Result) :-
    % Handle numeric pictures like N10.2
    atom_codes(Pic, [78|_]),  % Starts with 'N'
    to_string(Value, Result).
format_with_picture(Value, _, Result) :-
    to_string(Value, Result).

%------------------------------------------------------------
% File I/O Built-in Functions
%------------------------------------------------------------

% CREATE(file) - Create a file (in-memory, always succeeds)
builtin_call('CREATE', [var(FileName)], StateIn, StateOut, none) :-
    set_error(0, StateIn, StateOut),
    format("  [CREATE ~w]~n", [FileName]).

% OPEN(file) - Open a file
builtin_call('OPEN', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, _),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, -1, true),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [OPEN ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)  % File not found
    ).

% CLOSE(file) - Close a file
builtin_call('CLOSE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, _),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, false),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [CLOSE ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% CLEAR(record) - Clear record buffer to default values
builtin_call('CLEAR', [var(RecordRef)], StateIn, StateOut, none) :-
    % Parse the record reference (e.g., Cust:Record)
    ( parse_prefixed_name(RecordRef, Prefix, 'Record')
    -> find_file_by_prefix(Prefix, StateIn, FileState),
       FileState = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
       create_empty_buffer(Fields, NewBuffer),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open),
       set_file_state(FileName, NewFileState, StateIn, StateOut)
    ;  StateOut = StateIn
    ).

% EMPTY(file) - Delete all records from file
builtin_call('EMPTY', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, _, Buffer, _, Open),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, [], Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [EMPTY ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% ADD(file) - Add current buffer as new record
builtin_call('ADD', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       % Append buffer as new record
       append(Records, [Buffer], NewRecords),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [ADD to ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% GET(file, key) - Get record by key
builtin_call('GET', [var(FileName), var(KeyRef)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       % Parse key reference (e.g., Cust:ByID)
       ( parse_prefixed_name(KeyRef, Prefix, KeyName)
       -> true
       ; KeyName = KeyRef
       ),
       % Find the key definition
       ( member(key(KeyName, KeyFields), Keys)
       -> % Get key field values from buffer
          get_key_values(KeyFields, Prefix, Fields, Buffer, SearchValues),
          % Search for matching record
          ( find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Records, 0, FoundRecord, FoundPos)
          -> NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, FoundRecord, FoundPos, Open),
             set_file_state(FileName, NewFileState, StateIn, State1),
             set_error(0, State1, StateOut)
          ;  set_error(33, StateIn, StateOut)  % Record not found
          )
       ;  set_error(47, StateIn, StateOut)  % Invalid key
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% PUT(file) - Update current record
builtin_call('PUT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
       length(Records, NumRecords),
       ( Pos >= 0, Pos < NumRecords
       -> replace_nth0(Pos, Records, Buffer, NewRecords),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, Pos, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut),
          format("  [PUT to ~w at position ~w]~n", [FileName, Pos])
       ;  set_error(33, StateIn, StateOut)  % No current record
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% DELETE(file) - Delete current record
builtin_call('DELETE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
       ( Pos >= 0
       -> delete_nth0(Pos, Records, NewRecords),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, -1, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut),
          format("  [DELETE from ~w at position ~w]~n", [FileName, Pos])
       ;  set_error(33, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% SET(file) or SET(key) - Set file position to beginning
builtin_call('SET', [var(Ref)], StateIn, StateOut, none) :-
    % Could be file name or key reference
    ( get_file_state(Ref, StateIn, FileState)
    -> % Direct file reference
       FileState = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, _, Open),
       NewFileState = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, -1, Open),
       set_file_state(Ref, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut)
    ; parse_prefixed_name(Ref, Prefix, KeyName)
    -> % Key reference like Cust:ByName
       find_file_by_prefix(Prefix, StateIn, FileState),
       FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       % For now, just reset position (would sort by key in full implementation)
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut)
    ;  set_error(2, StateIn, StateOut)
    ).

% NEXT(file) - Read next record
builtin_call('NEXT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
       NextPos is Pos + 1,
       length(Records, NumRecords),
       ( NextPos < NumRecords
       -> nth0(NextPos, Records, NewBuffer),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, NextPos, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut)
       ;  set_error(33, StateIn, StateOut)  % End of file
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% RECORDS(file) - Get number of records
builtin_call('RECORDS', [var(FileName)], StateIn, StateIn, Count) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(_, _, _, _, Records, _, _, _),
       length(Records, Count)
    ;  Count = 0
    ).

% ERRORCODE() - Get last error code
builtin_call('ERRORCODE', [], StateIn, StateIn, ErrCode) :-
    get_error(StateIn, ErrCode).

% ERROR() - Get error message for last error
builtin_call('ERROR', [], StateIn, StateIn, ErrMsg) :-
    get_error(StateIn, ErrCode),
    error_message(ErrCode, ErrMsg).

% Error messages
error_message(0, "").
error_message(2, "File not found").
error_message(33, "Record not found").
error_message(47, "Invalid key").
error_message(_, "Unknown error").

%------------------------------------------------------------
% File I/O Helper Functions
%------------------------------------------------------------

% Get key field values from buffer
get_key_values([], _, _, _, []).
get_key_values([KeyFieldRef|Rest], Prefix, Fields, Buffer, [Value|Values]) :-
    % KeyFieldRef is like 'Cust:CustomerID'
    ( parse_prefixed_name(KeyFieldRef, Prefix, FieldName)
    -> true
    ; FieldName = KeyFieldRef
    ),
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Buffer, Value),
    get_key_values(Rest, Prefix, Fields, Buffer, Values).

% Find record matching key values
find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [Record|_], Pos, Record, Pos) :-
    get_key_values(KeyFields, Prefix, Fields, Record, RecordValues),
    SearchValues = RecordValues, !.
find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [_|Rest], Pos, FoundRecord, FoundPos) :-
    NextPos is Pos + 1,
    find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Rest, NextPos, FoundRecord, FoundPos).

% Delete element at index from list
delete_nth0(0, [_|T], T) :- !.
delete_nth0(N, [H|T], [H|R]) :-
    N > 0,
    N1 is N - 1,
    delete_nth0(N1, T, R).

%------------------------------------------------------------
% Expression Evaluation
%------------------------------------------------------------

eval_expr(string(S), _, S).
eval_expr(number(N), _, N).
eval_expr(neg(N), _, Result) :- Result is -N.
eval_expr(true, _, 1).
eval_expr(false, _, 0).

eval_expr(var(Name), State, Value) :-
    get_var(Name, State, Value).

eval_expr(call(Name, Args), StateIn, Result) :-
    exec_call(Name, Args, StateIn, _, Result).

% Method call as expression (returns value)
eval_expr(method_call(ObjName, MethodName, Args), StateIn, Result) :-
    exec_method_call(ObjName, MethodName, Args, StateIn, _, Result).

% SELF property access (inside method)
eval_expr(self_access(PropName), State, Value) :-
    get_self(State, self_context(VarName, _, _)),
    get_var(VarName, State, Instance),
    get_instance_prop(PropName, Instance, Value).

% Member access: Obj.Property
eval_expr(member_access(ObjName, PropName), State, Value) :-
    get_var(ObjName, State, Instance),
    ( Instance = instance(_, _)
    -> get_instance_prop(PropName, Instance, Value)
    ;  format(user_error, "Error: ~w is not an object~n", [ObjName]),
       Value = 0
    ).

eval_expr(binop(Op, Left, Right), State, Result) :-
    eval_expr(Left, State, LVal),
    eval_expr(Right, State, RVal),
    eval_binop(Op, LVal, RVal, Result).

eval_expr(not(Expr), State, Result) :-
    eval_expr(Expr, State, Val),
    ( is_truthy(Val) -> Result = 0 ; Result = 1 ).

% Catch-all for unhandled expressions
eval_expr(Expr, _, 0) :-
    format(user_error, "Warning: Unhandled expression: ~w~n", [Expr]).

%------------------------------------------------------------
% Binary Operators
%------------------------------------------------------------

% Arithmetic
eval_binop('+', L, R, Result) :-
    ( (number(L), number(R))
    -> Result is L + R
    ;  % String concatenation
       to_string(L, LS), to_string(R, RS),
       string_concat(LS, RS, Result)
    ).
eval_binop('-', L, R, Result) :- Result is L - R.
eval_binop('*', L, R, Result) :- Result is L * R.
eval_binop('/', L, R, Result) :- R \= 0, Result is L / R.
eval_binop('%', L, R, Result) :- R \= 0, Result is L mod R.

% String concatenation
eval_binop('&', L, R, Result) :-
    to_string(L, LS), to_string(R, RS),
    string_concat(LS, RS, Result).

% Comparison
eval_binop('=', L, R, Result) :- ( L = R -> Result = 1 ; Result = 0 ).
eval_binop('<>', L, R, Result) :- ( L \= R -> Result = 1 ; Result = 0 ).
eval_binop('<', L, R, Result) :- ( L < R -> Result = 1 ; Result = 0 ).
eval_binop('>', L, R, Result) :- ( L > R -> Result = 1 ; Result = 0 ).
eval_binop('<=', L, R, Result) :- ( L =< R -> Result = 1 ; Result = 0 ).
eval_binop('>=', L, R, Result) :- ( L >= R -> Result = 1 ; Result = 0 ).

% Logical
eval_binop('AND', L, R, Result) :-
    ( (is_truthy(L), is_truthy(R)) -> Result = 1 ; Result = 0 ).
eval_binop('OR', L, R, Result) :-
    ( (is_truthy(L) ; is_truthy(R)) -> Result = 1 ; Result = 0 ).

%------------------------------------------------------------
% Helper Predicates
%------------------------------------------------------------

is_truthy(1) :- !.
is_truthy(N) :- number(N), N \= 0.
is_truthy(S) :- string(S), S \= "".
is_truthy(A) :- atom(A), A \= ''.

to_string(S, S) :- string(S), !.
to_string(A, S) :- atom(A), !, atom_string(A, S).
to_string(N, S) :- number(N), number_string(N, S).

:- use_module(library(plunit)).


:- begin_tests(interpreter).

test(run_example_files) :-
    interpreter_test_files(Files),
    forall(member(File, Files),
           assertion(run_file(File))).

:- end_tests(interpreter).