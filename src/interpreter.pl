%============================================================
% interpreter.pl - Clarion AST Execution Engine
%
% Main entry points, initialization, statement execution,
% procedure calls, and control flow execution.
%
% Supporting modules:
%   interpreter_state.pl    - State management, variables
%   interpreter_eval.pl     - Expression evaluation
%   interpreter_builtins.pl - Built-in functions, file I/O
%   interpreter_classes.pl  - Class/instance management
%   interpreter_control.pl  - Control flow helpers
%============================================================

:- module(interpreter, [
    run_file/1,
    run_ast/1,
    run_ast/2,
    exec_statements/4,
    exec_call/5
]).

:- use_module(parser).
:- use_module(interpreter_state).
:- use_module(interpreter_eval).
:- use_module(interpreter_builtins).
:- use_module(interpreter_classes).
:- use_module(interpreter_control).

:- discontiguous exec_statement/4.

%------------------------------------------------------------
% Main Entry Points
%------------------------------------------------------------

run_file(FileName) :-
    format("Loading: ~w~n", [FileName]),
    parser:parse_file(FileName, AST),
    format("Executing...~n~n", []),
    run_ast(AST).

run_ast(AST) :-
    run_ast(AST, _FinalState).

run_ast(program(_, GlobalDecls, code(Statements), Procedures), FinalState) :-
    empty_state(InitState),
    init_procedures(Procedures, InitState, State1),
    init_globals(GlobalDecls, State1, State2),
    exec_statements(Statements, State2, FinalState, _Control).

% Support legacy 3-argument AST form
run_ast(program(_, code(Statements), Procedures), FinalState) :-
    empty_state(InitState),
    init_procedures(Procedures, InitState, State1),
    exec_statements(Statements, State1, FinalState, _Control).

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

init_procedures([], State, State).
init_procedures([Proc|Procs], state(Vars, ExistingProcs, Out, Files, Err, Classes, Self), FinalState) :-
    init_procedures(Procs, state(Vars, [Proc|ExistingProcs], Out, Files, Err, Classes, Self), FinalState).

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
init_globals([queue(Name, Fields)|Rest], StateIn, StateOut) :-
    create_empty_buffer(Fields, Buffer),
    FileState = file_state(Name, '', [], Fields, [], Buffer, -1, true),
    set_file_state(Name, FileState, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([_|Rest], StateIn, StateOut) :-
    init_globals(Rest, StateIn, StateOut).

init_group(Name, Fields, StateIn, StateOut) :-
    create_group_value(Fields, GroupValue),
    set_var(Name, group_val(Fields, GroupValue), StateIn, StateOut).

create_group_value([], []).
create_group_value([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_group_value(Rest, Values).

init_file(Name, Attrs, Contents, StateIn, StateOut) :-
    ( member(pre(Prefix), Attrs) -> true ; Prefix = '' ),
    extract_keys(Contents, Keys),
    extract_record_fields(Contents, Fields),
    create_empty_buffer(Fields, Buffer),
    FileState = file_state(Name, Prefix, Keys, Fields, [], Buffer, -1, false),
    set_file_state(Name, FileState, StateIn, StateOut).

extract_keys([], []).
extract_keys([key(KeyName, KeyFields, _)|Rest], [key(KeyName, KeyFields)|Keys]) :-
    extract_keys(Rest, Keys).
extract_keys([_|Rest], Keys) :-
    extract_keys(Rest, Keys).

extract_record_fields([], []).
extract_record_fields([record(Fields)|_], Fields) :- !.
extract_record_fields([_|Rest], Fields) :-
    extract_record_fields(Rest, Fields).

%------------------------------------------------------------
% Statement Execution
%------------------------------------------------------------

exec_statements([], State, State, normal).
exec_statements([Stmt|Stmts], StateIn, StateOut, Control) :-
    exec_statement(Stmt, StateIn, State1, StmtControl),
    ( StmtControl = normal
    -> exec_statements(Stmts, State1, StateOut, Control)
    ;  StateOut = State1, Control = StmtControl
    ).

%------------------------------------------------------------
% Statement Handlers
%------------------------------------------------------------

% Procedure/function call
exec_statement(call(Name, Args), StateIn, StateOut, normal) :-
    exec_call(Name, Args, StateIn, StateOut, _Result).

% Assignment
exec_statement(assign(VarName, Expr), StateIn, StateOut, normal) :-
    eval_full_expr(Expr, StateIn, Value),
    set_var(VarName, Value, StateIn, StateOut).

% Method call (as statement)
exec_statement(method_call(ObjName, MethodName, Args), StateIn, StateOut, normal) :-
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, _Result).

% SELF assignment
exec_statement(self_assign(PropName, Expr), StateIn, StateOut, normal) :-
    eval_full_expr(Expr, StateIn, Value),
    get_self(StateIn, self_context(VarName, _, _)),
    get_var(VarName, StateIn, Instance),
    set_instance_prop(PropName, Value, Instance, NewInstance),
    set_var(VarName, NewInstance, StateIn, StateOut).

% PARENT method call
exec_statement(parent_call(MethodName, Args), StateIn, StateOut, normal) :-
    exec_parent_call(MethodName, Args, StateIn, StateOut, _Result).

% GROUP/instance member assignment
exec_statement(member_assign(VarName, FieldName, Expr), StateIn, StateOut, normal) :-
    ( get_file_state(VarName, StateIn, FileState) ->
        eval_full_expr(Expr, StateIn, Value),
        set_buffer_field(FieldName, Value, FileState, NewFileState),
        set_file_state(VarName, NewFileState, StateIn, StateOut)
    ;
        eval_full_expr(Expr, StateIn, Value),
        get_var(VarName, StateIn, GroupVal),
        ( GroupVal = group_val(Fields, Values)
        -> set_group_field(FieldName, Value, Fields, Values, NewValues),
           set_var(VarName, group_val(Fields, NewValues), StateIn, StateOut)
        ; GroupVal = instance(_, _)
        -> set_instance_prop(FieldName, Value, GroupVal, NewInstance),
           set_var(VarName, NewInstance, StateIn, StateOut)
        ;  format(user_error, "Error: ~w is not a GROUP, instance or QUEUE~n", [VarName]),
           StateOut = StateIn
        )
    ).

% Array assignment
exec_statement(array_assign(ArrayName, IndexExpr, Expr), StateIn, StateOut, normal) :-
    eval_full_expr(IndexExpr, StateIn, Index),
    eval_full_expr(Expr, StateIn, Value),
    get_var(ArrayName, StateIn, ArrayVal),
    ( ArrayVal = array(Elements)
    -> Idx is Index - 1,
       set_array_element(Idx, Value, Elements, NewElements),
       set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ;  set_var(ArrayName, Value, StateIn, StateOut)
    ).

exec_statement(assign_add(VarName, Expr), StateIn, StateOut, normal) :-
    eval_full_expr(Expr, StateIn, Val),
    get_var(VarName, StateIn, CurrentVal),
    NewVal is CurrentVal + Val,
    set_var(VarName, NewVal, StateIn, StateOut).

% Return statements
exec_statement(return, State, State, return).
exec_statement(return(Expr), StateIn, StateIn, return(Value)) :-
    eval_full_expr(Expr, StateIn, Value).

% IF statement (4-arg form with ELSIF)
exec_statement(if(Cond, ThenStmts, ElsifClauses, ElseStmts), StateIn, StateOut, Control) :-
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_elsifs(ElsifClauses, ElseStmts, StateIn, StateOut, Control)
    ).

% IF statement (3-arg legacy form)
exec_statement(if(Cond, ThenStmts, ElseStmts), StateIn, StateOut, Control) :-
    \+ is_list(ElseStmts),
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_statements(ElseStmts, StateIn, StateOut, Control)
    ).

% Loop statements
exec_statement(loop(Body), StateIn, StateOut, Control) :-
    exec_loop_infinite(Body, StateIn, StateOut, Control).
exec_statement(loop_to(Var, FromExpr, ToExpr, Body), StateIn, StateOut, Control) :-
    eval_full_expr(FromExpr, StateIn, From),
    eval_full_expr(ToExpr, StateIn, To),
    set_var(Var, From, StateIn, State1),
    exec_loop_to(Var, To, Body, State1, StateOut, Control).
exec_statement(loop_while(Cond, Body), StateIn, StateOut, Control) :-
    exec_loop_while(Cond, Body, StateIn, StateOut, Control).
exec_statement(loop_until(Cond, Body), StateIn, StateOut, Control) :-
    exec_loop_until(Cond, Body, StateIn, StateOut, Control).

% BREAK and CYCLE
exec_statement(break, State, State, break).
exec_statement(cycle, State, State, cycle).

% CASE statement
exec_statement(case(Expr, Cases, ElseStmts), StateIn, StateOut, Control) :-
    eval_full_expr(Expr, StateIn, Value),
    exec_case(Value, Cases, ElseStmts, StateIn, StateOut, Control).

% DO routine call
exec_statement(do(RoutineName), StateIn, StateOut, Control) :-
    exec_routine(RoutineName, StateIn, StateOut, Control).

% EXIT (from routine)
exec_statement(exit, State, State, exit).

% ACCEPT loop
exec_statement(accept(Body), StateIn, StateOut, Control) :-
    exec_accept_loop(Body, StateIn, StateOut, Control, open_window).

% Window/Control operations (no-ops for non-GUI)
exec_statement(control_prop_assign(_, _, _), State, State, normal).
exec_statement(select(_), State, State, normal).
exec_statement(beep, State, State, normal).
exec_statement(display, State, State, normal).

% Catch-all
exec_statement(Stmt, State, State, normal) :-
    format(user_error, "Warning: Unimplemented statement: ~w~n", [Stmt]).

%------------------------------------------------------------
% Expression Evaluation (extended)
%------------------------------------------------------------

% Full expression evaluation that handles calls and method calls
eval_full_expr(call(Name, Args), StateIn, Result) :- !,
    exec_call(Name, Args, StateIn, _, Result).
eval_full_expr(method_call(ObjName, MethodName, Args), StateIn, Result) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, _, Result).
eval_full_expr(self_access(PropName), State, Value) :- !,
    get_self(State, self_context(VarName, _, _)),
    get_var(VarName, State, Instance),
    get_instance_prop(PropName, Instance, Value).
eval_full_expr(member_access(ObjName, PropName), State, Value) :- !,
    get_var(ObjName, State, Instance),
    ( Instance = instance(_, _)
    -> get_instance_prop(PropName, Instance, Value)
    ; Instance = group_val(Fields, Values)
    -> get_group_field(PropName, Fields, Values, Value)
    ;  format(user_error, "Error: ~w is not an object~n", [ObjName]),
       Value = 0
    ).
eval_full_expr(Expr, State, Value) :-
    eval_expr(Expr, State, Value).

%------------------------------------------------------------
% ELSIF Handling
%------------------------------------------------------------

exec_elsifs([], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_elsifs([elsif(Cond, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control) :-
    eval_full_expr(Cond, StateIn, CondVal),
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
    ; exec_loop_infinite(Body, State1, StateOut, Control)
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
    eval_full_expr(Cond, StateIn, CondVal),
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
    ; eval_full_expr(Cond, State1, CondVal),
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
    eval_full_expr(CaseVal, StateIn, MatchVal),
    ( Value = MatchVal
    -> exec_statements(Stmts, StateIn, StateOut, Control)
    ;  exec_case(Value, Rest, ElseStmts, StateIn, StateOut, Control)
    ).

%------------------------------------------------------------
% Routine Execution
%------------------------------------------------------------

exec_routine(Name, StateIn, StateOut, Control) :-
    get_routine(Name, StateIn, routine(Name, Body)),
    exec_statements(Body, StateIn, StateOut, RoutineControl),
    ( RoutineControl = exit -> Control = normal ; Control = RoutineControl ).

%------------------------------------------------------------
% ACCEPT Loop Execution
%------------------------------------------------------------

exec_accept_loop(Body, StateIn, StateOut, Control, Phase) :-
    set_event_phase(Phase, StateIn, State1),
    exec_statements(Body, State1, State2, BodyControl),
    ( BodyControl = break
    -> StateOut = State2, Control = normal
    ; BodyControl = cycle
    -> next_phase(Phase, NextPhase),
       ( NextPhase = done
       -> StateOut = State2, Control = normal
       ; exec_accept_loop(Body, State2, StateOut, Control, NextPhase)
       )
    ; next_phase(Phase, NextPhase),
      ( NextPhase = done
      -> StateOut = State2, Control = normal
      ; exec_accept_loop(Body, State2, StateOut, Control, NextPhase)
      )
    ).

%------------------------------------------------------------
% Procedure/Function Calls
%------------------------------------------------------------

exec_call(Name, Args, StateIn, StateOut, Result) :-
    ( builtin_call(Name, Args, StateIn, StateOut, Result)
    -> true
    ; get_proc(Name, StateIn, procedure(Name, Params, LocalVars, code(Body))),
      eval_args(Args, StateIn, ArgVals),
      bind_params(Params, ArgVals, StateIn, State1),
      init_locals(LocalVars, State1, State2),
      exec_statements(Body, State2, State3, Control),
      ( Control = return(V) -> Result = V ; Result = none ),
      StateIn = state(OuterVars, Procs, _, _, _, _, _),
      State3 = state(_, _, NewOut, NewFiles, NewErr, NewClasses, _),
      StateOut = state(OuterVars, Procs, NewOut, NewFiles, NewErr, NewClasses, none)
    ).

eval_args([], _, []).
eval_args([Arg|Args], State, [Val|Vals]) :-
    eval_full_expr(Arg, State, Val),
    eval_args(Args, State, Vals).

bind_params([], [], State, State).
bind_params([param(_, Name)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
bind_params([], [_|_], State, State).
bind_params([_|_], [], State, State).

init_locals([], State, State).
init_locals([var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, custom(ClassName), _)|Rest], StateIn, StateOut) :-
    create_instance(ClassName, StateIn, Instance),
    set_var(Name, Instance, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    Type \= custom(_),
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([window(_, _, _)|Rest], StateIn, StateOut) :-
    init_locals(Rest, StateIn, StateOut).

%------------------------------------------------------------
% Method Call Execution
%------------------------------------------------------------

exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, Result) :-
    get_var(ObjName, StateIn, Instance),
    Instance = instance(ClassName, _),
    find_method_impl(ClassName, MethodName, StateIn, MethodImpl),
    MethodImpl = method_impl(ImplClass, MethodName, Params, LocalVars, code(Body)),
    eval_args(Args, StateIn, ArgVals),
    get_class_def(ClassName, StateIn, class_def(ClassName, ParentClass, _, _)),
    set_self(self_context(ObjName, ImplClass, ParentClass), StateIn, State1),
    bind_params(Params, ArgVals, State1, State2),
    init_locals(LocalVars, State2, State3),
    exec_statements(Body, State3, State4, Control),
    ( Control = return(V) -> Result = V ; Result = none ),
    State4 = state(_, Procs, NewOut, NewFiles, NewErr, NewClasses, _),
    get_var(ObjName, State4, UpdatedInstance),
    set_var(ObjName, UpdatedInstance, StateIn, State5),
    State5 = state(Vars5, _, _, _, _, _, _),
    StateOut = state(Vars5, Procs, NewOut, NewFiles, NewErr, NewClasses, none).

exec_parent_call(MethodName, Args, StateIn, StateOut, Result) :-
    get_self(StateIn, self_context(ObjName, CurrentClass, _)),
    get_class_def(CurrentClass, StateIn, class_def(CurrentClass, ParentClass, _, _)),
    ( ParentClass \= none
    -> find_method_impl(ParentClass, MethodName, StateIn, MethodImpl),
       MethodImpl = method_impl(ImplClass, MethodName, Params, LocalVars, code(Body)),
       eval_args(Args, StateIn, ArgVals),
       get_class_def(ImplClass, StateIn, class_def(ImplClass, GrandParent, _, _)),
       set_self(self_context(ObjName, ImplClass, GrandParent), StateIn, State1),
       bind_params(Params, ArgVals, State1, State2),
       init_locals(LocalVars, State2, State3),
       exec_statements(Body, State3, State4, Control),
       ( Control = return(V) -> Result = V ; Result = none ),
       get_self(StateIn, OrigSelf),
       set_self(OrigSelf, State4, StateOut)
    ;  format(user_error, "Error: No parent class for PARENT call~n", []),
       StateOut = StateIn, Result = none
    ).

%------------------------------------------------------------
% Group Field Helpers
%------------------------------------------------------------

set_group_field(FieldName, Value, Fields, Values, NewValues) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    replace_nth0(Index, Values, Value, NewValues), !.
set_group_field(FieldName, _, _, Values, Values) :-
    format(user_error, "Error: Unknown GROUP field '~w'~n", [FieldName]).

get_group_field(FieldName, Fields, Values, Value) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Values, Value), !.
get_group_field(FieldName, _, _, 0) :-
    format(user_error, "Error: Unknown GROUP field '~w'~n", [FieldName]).

%------------------------------------------------------------
% Array Element Helpers
%------------------------------------------------------------

set_array_element(0, Value, [_|Rest], [Value|Rest]) :- !.
set_array_element(Idx, Value, [H|T], [H|NewT]) :-
    Idx > 0,
    Idx1 is Idx - 1,
    set_array_element(Idx1, Value, T, NewT).
set_array_element(Idx, Value, [], NewList) :-
    Idx >= 0,
    length(Padding, Idx),
    maplist(=(0), Padding),
    append(Padding, [Value], NewList).

%------------------------------------------------------------
% Tests
%------------------------------------------------------------

:- use_module(library(plunit)).

:- begin_tests(interpreter).

test(run_example_files) :-
    interpreter_test_files(Files),
    forall(member(File, Files),
           assertion(run_file(File))).

:- end_tests(interpreter).
