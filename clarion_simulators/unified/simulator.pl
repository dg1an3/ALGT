%============================================================
% simulator.pl - Clarion AST Execution Engine
%
% Main entry points, initialization, statement execution,
% procedure calls, and control flow execution.
%
% Supporting modules:
%   simulator_state.pl    - State management, variables
%   simulator_eval.pl     - Expression evaluation
%   simulator_builtins.pl - Built-in functions, file I/O
%   simulator_classes.pl  - Class/instance management
%   simulator_control.pl  - Control flow helpers
%============================================================

:- module(simulator, [
    run_file/1,
    run_file_traced/2,      % run_file_traced(+FileName, -Trace)
    run_ast/1,
    run_ast/2,
    run_ast_traced/2,       % run_ast_traced(+AST, -Trace)
    exec_statements/4,
    exec_call/5,
    init_map_protos/3,      % init_map_protos(+MapDecls, +StateIn, -StateOut)
    init_procedures/3,      % init_procedures(+Procs, +StateIn, -StateOut)
    init_globals/3           % init_globals(+GlobalDecls, +StateIn, -StateOut)
]).

% Note: parser is NOT imported here — the unified system uses
% clarion_parser.pl via ast_bridge.pl instead of the modular parser.
:- use_module(simulator_state).
:- use_module(simulator_eval).
:- use_module(simulator_builtins).
:- use_module(simulator_classes).
:- use_module(simulator_control).
:- use_module(execution_tracer).

:- discontiguous exec_statement/4.

%------------------------------------------------------------
% Main Entry Points
%------------------------------------------------------------

run_file(FileName) :-
    format("Loading: ~w~n", [FileName]),
    ( catch(
        (clarion_parser:parse_file(FileName, SimpleAST),
         ast_bridge:bridge_ast(SimpleAST, AST)),
        _,
        fail
      ) ->
        format("Executing...~n~n", []),
        run_ast(AST)
    ;   format("Error: Could not parse ~w~n", [FileName])
    ).

%% run_file_traced(+FileName, -Trace) is det.
%
% Run a Clarion file with execution tracing enabled.
% Returns a Trace dict containing execution events and graph.

run_file_traced(FileName, Trace) :-
    format("Loading: ~w~n", [FileName]),
    clarion_parser:parse_file(FileName, SimpleAST),
    ast_bridge:bridge_ast(SimpleAST, AST),
    format("Executing with tracing...~n~n", []),
    run_ast_traced(AST, Trace).

run_ast(AST) :-
    run_ast(AST, _FinalState).

run_ast(program(map(MapDecls), GlobalDecls, code(Statements), Procedures), FinalState) :-
    empty_state(InitState),
    init_map_protos(MapDecls, InitState, State0),
    init_procedures(Procedures, State0, State1),
    init_globals(GlobalDecls, State1, State2),
    exec_statements(Statements, State2, FinalState, _Control).

% Legacy form without map
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

%% run_ast_traced(+AST, -Trace) is det.
%
% Execute AST with tracing enabled.
% Returns a Trace containing:
%   - events: List of trace events
%   - graph: Execution graph (PyTorch-style DAG)
%   - duration: Execution time
%   - summary: Statistics

run_ast_traced(AST, Trace) :-
    start_trace,
    ( run_ast(AST, _FinalState)
    -> true
    ;  true  % Continue even if execution fails
    ),
    get_execution_graph(Graph),
    stop_trace(BaseTrace),
    Trace = BaseTrace.put(graph, Graph).

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

%------------------------------------------------------------
% MAP Prototype Initialization
%------------------------------------------------------------

init_map_protos(MapDecls, StateIn, StateOut) :-
    set_var('__MAP_PROTOS__', MapDecls, StateIn, StateOut).

init_procedures([], State, State).
init_procedures([Proc|Procs], state(Vars, ExistingProcs, Out, Files, Err, Classes, Self, UI, Cont), FinalState) :-
    init_procedures(Procs, state(Vars, [Proc|ExistingProcs], Out, Files, Err, Classes, Self, UI, Cont), FinalState).

init_globals([], State, State).
init_globals([var(Name, _Type, init(InitVal))|Rest], StateIn, StateOut) :-
    InitVal \= none, !,
    set_var(Name, InitVal, StateIn, State1),
    init_globals(Rest, State1, StateOut).
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
init_globals([group(Name, Prefix, Fields)|Rest], StateIn, StateOut) :-
    init_group(Name, Prefix, Fields, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([group(Name, Fields)|Rest], StateIn, StateOut) :-
    init_group(Name, '', Fields, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([queue(Name, Fields)|Rest], StateIn, StateOut) :-
    create_empty_buffer(Fields, Buffer),
    FileState = file_state(Name, '', [], Fields, [], Buffer, -1, true),
    set_file_state(Name, FileState, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([window(_Name, _Title, _Attrs, Controls)|Rest], StateIn, StateOut) :-
    assign_equates(Controls, 1, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([_|Rest], StateIn, StateOut) :-
    init_globals(Rest, StateIn, StateOut).

%------------------------------------------------------------
% Equate Assignment (WINDOW controls -> equate numbers)
%------------------------------------------------------------

assign_equates([], _, State, State).
assign_equates([Control|Cs], N, StateIn, StateOut) :-
    ( control_equate_name(Control, EqName) ->
        set_var(equate(EqName), N, StateIn, State1),
        N1 is N + 1,
        assign_equates(Cs, N1, State1, StateOut)
    ;   assign_equates(Cs, N, StateIn, StateOut)
    ).

control_equate_name(button(_, _, equate(Name)), Name).
control_equate_name(entry(_, _, equate(Name)), Name).
control_equate_name(list_ctl(_, equate(Name), _, _), Name).
control_equate_name(string_ctl(_, _, equate(Name)), Name).
control_equate_name(prompt(_, _, equate(Name)), Name).

init_group(Name, Prefix, Fields, StateIn, StateOut) :-
    create_group_value(Fields, GroupValue),
    set_var(Name, group_val(Prefix, Fields, GroupValue), StateIn, State1),
    % Also register prefix -> group name mapping if prefix is non-empty
    ( Prefix \= '' ->
        set_var(group_prefix(Prefix), Name, State1, StateOut)
    ;   StateOut = State1
    ).

create_group_value([], []).
create_group_value([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_group_value(Rest, Values).

init_file(Name, Attrs, Contents, StateIn, StateOut) :-
    ( member(pre(Prefix), Attrs) -> true ; Prefix = '' ),
    ( member(driver(Driver), Attrs) -> true ; Driver = memory ),
    extract_keys(Contents, Keys),
    extract_record_fields(Contents, Fields),
    create_empty_buffer(Fields, Buffer),
    FileState = file_state(Name, Prefix, Keys, Fields, [], Buffer, -1, false),
    set_file_state(Name, FileState, StateIn, State1),
    set_var(file_driver(Name), Driver, State1, StateOut).

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
exec_statement(call(Name, Args), StateIn, StateOut, normal) :- !,
    exec_call(Name, Args, StateIn, StateOut, _Result).

% Assignment (with tracing)
exec_statement(assign(VarName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Value),
    % Trace: record the assignment
    ( is_tracing
    -> ( get_var(VarName, StateIn, OldValue) -> true ; OldValue = undefined ),
       trace_var_assign(VarName, OldValue, Value),
       % Build graph node for assignment
       graph_node_for_assignment(VarName, Value, Expr, NodeId),
       % Track data dependencies from expression variables
       trace_expr_reads(Expr, StateIn, NodeId)
    ;  true
    ),
    set_var(VarName, Value, StateIn, StateOut).

% Method call (as statement)
exec_statement(method_call(ObjName, MethodName, Args), StateIn, StateOut, normal) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, _Result).

% SELF assignment
exec_statement(self_assign(PropName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Value),
    get_self(StateIn, self_context(VarName, _, _)),
    get_var(VarName, StateIn, Instance),
    set_instance_prop(PropName, Value, Instance, NewInstance),
    set_var(VarName, NewInstance, StateIn, StateOut).

% PARENT method call
exec_statement(parent_call(MethodName, Args), StateIn, StateOut, normal) :- !,
    exec_parent_call(MethodName, Args, StateIn, StateOut, _Result).

% GROUP/instance member assignment
exec_statement(member_assign(VarName, FieldName, Expr), StateIn, StateOut, normal) :- !,
    ( get_file_state(VarName, StateIn, FileState) ->
        eval_full_expr(Expr, StateIn, Value),
        set_buffer_field(FieldName, Value, FileState, NewFileState),
        set_file_state(VarName, NewFileState, StateIn, StateOut)
    ;
        eval_full_expr(Expr, StateIn, Value),
        get_var(VarName, StateIn, GroupVal),
        ( GroupVal = group_val(Pfx, Fields, Values)
        -> set_group_field(FieldName, Value, Fields, Values, NewValues),
           set_var(VarName, group_val(Pfx, Fields, NewValues), StateIn, StateOut)
        ; GroupVal = group_val(Fields, Values)
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
exec_statement(array_assign(ArrayName, IndexExpr, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(IndexExpr, StateIn, Index),
    eval_full_expr(Expr, StateIn, Value),
    get_var(ArrayName, StateIn, ArrayVal),
    ( ArrayVal = array(Elements)
    -> Idx is Index - 1,
       set_array_element(Idx, Value, Elements, NewElements),
       set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ;  set_var(ArrayName, Value, StateIn, StateOut)
    ).

exec_statement(assign_add(VarName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Val),
    get_var(VarName, StateIn, CurrentVal),
    NewVal is CurrentVal + Val,
    set_var(VarName, NewVal, StateIn, StateOut).

% Return statements
exec_statement(return, State, State, return) :- !.
exec_statement(return(Expr), StateIn, StateIn, return(Value)) :- !,
    eval_full_expr(Expr, StateIn, Value).

% IF statement (4-arg form with ELSIF) - with tracing
exec_statement(if(Cond, ThenStmts, ElsifClauses, ElseStmts), StateIn, StateOut, Control) :- !,
    eval_full_expr(Cond, StateIn, CondVal),
    IsTruthy = is_truthy(CondVal),
    ( call(IsTruthy) -> BranchTaken = true ; BranchTaken = false ),
    % Trace: record the branch decision
    ( is_tracing
    -> trace_branch(if, Cond, CondVal, BranchTaken),
       graph_node_for_branch(Cond, BranchTaken, NodeId),
       trace_condition_vars(Cond, NodeId)
    ;  true
    ),
    ( BranchTaken = true
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_elsifs(ElsifClauses, ElseStmts, StateIn, StateOut, Control)
    ).

% IF statement (3-arg legacy form) - with tracing
exec_statement(if(Cond, ThenStmts, ElseStmts), StateIn, StateOut, Control) :- !,
    \+ is_list(ElseStmts),
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal) -> BranchTaken = true ; BranchTaken = false ),
    % Trace: record the branch decision
    ( is_tracing
    -> trace_branch(if, Cond, CondVal, BranchTaken),
       graph_node_for_branch(Cond, BranchTaken, NodeId),
       trace_condition_vars(Cond, NodeId)
    ;  true
    ),
    ( BranchTaken = true
    -> exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;  exec_statements(ElseStmts, StateIn, StateOut, Control)
    ).

% Loop statements - with tracing
exec_statement(loop(Body), StateIn, StateOut, Control) :- !,
    ( is_tracing
    -> trace_loop_start(infinite, info{})
    ;  true
    ),
    exec_loop_infinite(Body, StateIn, StateOut, Control),
    ( is_tracing
    -> trace_loop_end(infinite, Control)
    ;  true
    ).

exec_statement(loop_to(Var, FromExpr, ToExpr, Body), StateIn, StateOut, Control) :- !,
    eval_full_expr(FromExpr, StateIn, From),
    eval_full_expr(ToExpr, StateIn, To),
    ( is_tracing
    -> trace_loop_start(loop_to, info{var: Var, from: From, to: To}),
       add_graph_node(loop, loop{type: loop_to, var: Var, from: From, to: To}, _)
    ;  true
    ),
    set_var(Var, From, StateIn, State1),
    exec_loop_to(Var, To, Body, State1, StateOut, Control),
    ( is_tracing
    -> trace_loop_end(loop_to, Control)
    ;  true
    ).

exec_statement(loop_while(Cond, Body), StateIn, StateOut, Control) :- !,
    ( is_tracing
    -> trace_loop_start(loop_while, info{condition: Cond}),
       add_graph_node(loop, loop{type: loop_while, condition: Cond}, _)
    ;  true
    ),
    exec_loop_while(Cond, Body, StateIn, StateOut, Control),
    ( is_tracing
    -> trace_loop_end(loop_while, Control)
    ;  true
    ).

exec_statement(loop_until(Cond, Body), StateIn, StateOut, Control) :- !,
    ( is_tracing
    -> trace_loop_start(loop_until, info{condition: Cond}),
       add_graph_node(loop, loop{type: loop_until, condition: Cond}, _)
    ;  true
    ),
    exec_loop_until(Cond, Body, StateIn, StateOut, Control),
    ( is_tracing
    -> trace_loop_end(loop_until, Control)
    ;  true
    ).

% BREAK and CYCLE
exec_statement(break, State, State, break) :- !.
exec_statement(cycle, State, State, cycle) :- !.

% CASE statement - with tracing
exec_statement(case(Expr, Cases, ElseStmts), StateIn, StateOut, Control) :- !,
    eval_full_expr(Expr, StateIn, Value),
    ( is_tracing
    -> add_graph_node(branch, branch{type: case, expr: Expr, value: Value}, NodeId),
       trace_expr_reads(Expr, StateIn, NodeId)
    ;  true
    ),
    exec_case_traced(Value, Cases, ElseStmts, StateIn, StateOut, Control, 0).

% DO routine call
exec_statement(do(RoutineName), StateIn, StateOut, Control) :- !,
    exec_routine(RoutineName, StateIn, StateOut, Control).

% EXIT (from routine)
exec_statement(exit, State, State, exit) :- !.

% ACCEPT loop
exec_statement(accept(Body), StateIn, StateOut, Control) :- !,
    exec_accept_loop(Body, StateIn, StateOut, Control, open_window).

% Window/Control operations (no-ops for non-GUI)
exec_statement(control_prop_assign(_, _, _), State, State, normal) :- !.
exec_statement(select(_), State, State, normal) :- !.
exec_statement(beep, State, State, normal) :- !.
exec_statement(display, State, State, normal) :- !.

% Catch-all
exec_statement(Stmt, State, State, normal) :-
    format(user_error, "Warning: Unimplemented statement: ~w~n", [Stmt]).

%------------------------------------------------------------
% Expression Evaluation (extended)
%------------------------------------------------------------

% Full expression evaluation that handles calls and method calls
% Binop must use eval_full_expr for sub-expressions (they may contain calls)
eval_full_expr(binop(Op, Left, Right), State, Result) :- !,
    eval_full_expr(Left, State, LVal),
    eval_full_expr(Right, State, RVal),
    eval_binop(Op, LVal, RVal, Result).
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
    ; Instance = group_val(_, Fields, Values)
    -> get_group_field(PropName, Fields, Values, Value)
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

% Traced version of exec_case that records which branch was taken
exec_case_traced(_, [], ElseStmts, StateIn, StateOut, Control, Index) :-
    ( is_tracing
    -> trace_case_match(else, else, Index)
    ;  true
    ),
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_case_traced(Value, [case_of(range(StartExpr, EndExpr), Stmts)|Rest], ElseStmts, StateIn, StateOut, Control, Index) :- !,
    eval_full_expr(StartExpr, StateIn, StartVal),
    eval_full_expr(EndExpr, StateIn, EndVal),
    ( number(Value), Value >= StartVal, Value =< EndVal
    -> ( is_tracing
       -> trace_case_match(Value, range(StartVal, EndVal), Index)
       ;  true
       ),
       exec_statements(Stmts, StateIn, StateOut, Control)
    ;  NextIndex is Index + 1,
       exec_case_traced(Value, Rest, ElseStmts, StateIn, StateOut, Control, NextIndex)
    ).
exec_case_traced(Value, [case_of(CaseVal, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control, Index) :-
    eval_full_expr(CaseVal, StateIn, MatchVal),
    ( Value = MatchVal
    -> ( is_tracing
       -> trace_case_match(Value, MatchVal, Index)
       ;  true
       ),
       exec_statements(Stmts, StateIn, StateOut, Control)
    ;  NextIndex is Index + 1,
       exec_case_traced(Value, Rest, ElseStmts, StateIn, StateOut, Control, NextIndex)
    ).

%------------------------------------------------------------
% Routine Execution
%------------------------------------------------------------

exec_routine(Name, StateIn, StateOut, Control) :-
    get_routine(Name, StateIn, routine(Name, Body)),
    exec_statements(Body, StateIn, StateOut, RoutineControl),
    ( RoutineControl = exit -> Control = normal ; Control = RoutineControl ).

%------------------------------------------------------------
% ACCEPT Loop Execution (event-driven)
%------------------------------------------------------------
% Consumes events from the UI state's event queue:
%   Integer       — button press (equate number), sets ACCEPTED(), runs body
%   set(Var, Val) — field entry, updates variable, does NOT run body
%   choice(Name, Index) — list selection, updates list choice
% BREAK inside the body ends the accept loop.
% When the event queue is empty, the loop exits.

exec_accept_loop(Body, StateIn, StateOut, Control, _Phase) :-
    get_ui_state(StateIn, UIState),
    ( is_dict(UIState), get_dict(event_queue, UIState, [Event|RestEvents]) ->
        put_dict(event_queue, UIState, RestEvents, NewUI),
        set_ui_state(NewUI, StateIn, State1),
        ( Event = set(VarName, Value) ->
            % Field entry event — update variable, don't run body
            set_var(VarName, Value, State1, State2),
            exec_accept_loop(Body, State2, StateOut, Control, accepted)
        ; Event = choice(EqName, Index) ->
            % List selection event — store as __CHOICE__EqName
            atom_concat('__CHOICE__', EqName, ChoiceKey),
            set_var(ChoiceKey, Index, State1, State2),
            exec_accept_loop(Body, State2, StateOut, Control, accepted)
        ;   % Button press event — set __ACCEPTED__ and run body
            set_var('__ACCEPTED__', Event, State1, State2),
            exec_statements(Body, State2, State3, BodyControl),
            ( BodyControl = break
            -> StateOut = State3, Control = normal
            ; BodyControl = return(V)
            -> StateOut = State3, Control = return(V)
            ; exec_accept_loop(Body, State3, StateOut, Control, accepted)
            )
        )
    ;   % No more events — exit accept loop
        StateOut = StateIn, Control = normal
    ).

%------------------------------------------------------------
% Procedure/Function Calls
%------------------------------------------------------------

exec_call(Name, Args, StateIn, StateOut, Result) :-
    ( builtin_call(Name, Args, StateIn, StateOut, Result)
    -> true
    ; is_external_proc(Name, StateIn)
    -> % External MODULE procedure — execute as stub
       exec_external_stub(Name, Args, StateIn, StateOut, Result)
    ; ( get_proc(Name, StateIn, procedure(_, Params, LocalVars, code(Body)))
      -> true
      ; throw(error(undefined_procedure(Name), context(exec_call/5, 'Undefined procedure')))
      ),
      eval_args(Args, StateIn, ArgVals),
      % Trace: procedure entry
      ( is_tracing
      -> trace_proc_enter(Name, ArgVals),
         add_graph_node(call, call{name: Name, args: ArgVals}, _CallNodeId)
      ;  true
      ),
      bind_params(Params, ArgVals, StateIn, State1),
      init_locals(LocalVars, State1, State2),
      exec_statements(Body, State2, State3, Control),
      ( Control = return(V) -> Result = V ; Result = none ),
      % Trace: procedure exit
      ( is_tracing
      -> trace_proc_exit(Name, Result),
         add_graph_node(return, return{name: Name, value: Result}, _RetNodeId)
      ;  true
      ),
      % Merge globals back: keep callee's values for vars that existed in caller,
      % discard local-only vars (params and locals)
      StateIn = state(OuterVars, Procs, _, _, _, _, _, UI, Cont),
      State3 = state(InnerVars, _, NewOut, NewFiles, NewErr, NewClasses, _, _, _),
      param_names(Params, ParamNames),
      local_names(LocalVars, LocalNames),
      merge_globals(OuterVars, InnerVars, ParamNames, LocalNames, MergedVars),
      StateOut = state(MergedVars, Procs, NewOut, NewFiles, NewErr, NewClasses, none, UI, Cont)
    ).

%------------------------------------------------------------
% External Procedure Stubs (MODULE declarations)
%------------------------------------------------------------

%% exec_external_stub(+Name, +Args, +StateIn, -StateOut, -Result)
%
% External MODULE procedures are not implemented in the simulator.
% Returns a default value based on the MAP return type and logs the call.

exec_external_stub(Name, Args, StateIn, StateOut, Result) :-
    eval_args(Args, StateIn, ArgVals),
    % Look up the MAP prototype for return type info
    ( get_map_proto(Name, StateIn, Proto)
    -> ( Proto = external_proc(_, ModName, _, RetType, _)
       -> true
       ; Proto = map_proto(_, _, RetType, _), ModName = local
       )
    ;  RetType = void, ModName = unknown
    ),
    % Default return value based on return type
    ( RetType = void -> Result = none
    ; member(RetType, ['LONG', 'SHORT', 'BYTE', 'DECIMAL', 'PDECIMAL', 'DATE', 'TIME'])
      -> Result = 0
    ; member(RetType, ['REAL', 'SREAL']) -> Result = 0.0
    ; member(RetType, ['STRING', 'CSTRING', 'PSTRING']) -> Result = ""
    ; Result = 0
    ),
    % Trace if enabled
    ( is_tracing
    -> trace_proc_enter(Name, ArgVals),
       add_graph_node(call, call{type: external, name: Name, module: ModName, args: ArgVals}, _),
       trace_proc_exit(Name, Result),
       add_graph_node(return, return{type: external, name: Name, value: Result}, _)
    ;  true
    ),
    format("  [EXTERNAL ~w:~w(~w) -> ~w]~n", [ModName, Name, ArgVals, Result]),
    StateOut = StateIn.

%% merge_globals(+OuterVars, +InnerVars, +ParamNames, +LocalNames, -MergedVars)
% For each outer var, pick its value from inner vars (if updated), otherwise keep outer value.
merge_globals([], _, _, _, []).
merge_globals([var(Name, _OldVal)|Rest], InnerVars, ParamNames, LocalNames, [var(Name, NewVal)|MergedRest]) :-
    member(var(Name, NewVal), InnerVars), !,
    merge_globals(Rest, InnerVars, ParamNames, LocalNames, MergedRest).
merge_globals([Var|Rest], InnerVars, ParamNames, LocalNames, [Var|MergedRest]) :-
    merge_globals(Rest, InnerVars, ParamNames, LocalNames, MergedRest).

param_names([], []).
param_names([param(_, Name)|Rest], [Name|Names]) :- param_names(Rest, Names).
param_names([param(_, Name, _, _)|Rest], [Name|Names]) :- param_names(Rest, Names).

local_names([], []).
local_names([local_var(Name, _, _)|Rest], [Name|Names]) :- local_names(Rest, Names).
local_names([var(Name, _, _)|Rest], [Name|Names]) :- local_names(Rest, Names).
local_names([_|Rest], Names) :- local_names(Rest, Names).

eval_args([], _, []).
eval_args([Arg|Args], State, [Val|Vals]) :-
    eval_full_expr(Arg, State, Val),
    eval_args(Args, State, Vals).

bind_params([], [], State, State).
% Required parameter with value provided
bind_params([param(_, Name)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
% Optional parameter with value provided
bind_params([param(_, Name, optional, _)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
% Optional parameter without value - use default
bind_params([param(Type, Name, optional, Default)|Params], [], StateIn, StateOut) :-
    ( Default = none
    -> default_value(Type, none, Val)
    ;  eval_full_expr(Default, StateIn, Val)
    ),
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, [], State1, StateOut).
% Extra args - ignore
bind_params([], [_|_], State, State).
% Missing required args - use type defaults
bind_params([param(Type, Name)|Params], [], StateIn, StateOut) :-
    default_value(Type, none, Val),
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, [], State1, StateOut).

init_locals([], State, State).
init_locals([var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, custom(ClassName), _)|Rest], StateIn, StateOut) :-
    create_instance(ClassName, StateIn, Instance),
    set_var(Name, Instance, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, Type, init(InitVal))|Rest], StateIn, StateOut) :-
    Type \= custom(_), InitVal \= none, !,
    set_var(Name, InitVal, StateIn, State1),
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
    % Trace: method entry
    ( is_tracing
    -> trace_method_enter(ObjName, MethodName, ArgVals),
       add_graph_node(call, call{type: method, object: ObjName, method: MethodName, args: ArgVals}, _)
    ;  true
    ),
    get_class_def(ClassName, StateIn, class_def(ClassName, ParentClass, _, _)),
    set_self(self_context(ObjName, ImplClass, ParentClass), StateIn, State1),
    bind_params(Params, ArgVals, State1, State2),
    init_locals(LocalVars, State2, State3),
    exec_statements(Body, State3, State4, Control),
    ( Control = return(V) -> Result = V ; Result = none ),
    % Trace: method exit
    ( is_tracing
    -> trace_method_exit(ObjName, MethodName, Result),
       add_graph_node(return, return{type: method, object: ObjName, method: MethodName, value: Result}, _)
    ;  true
    ),
    State4 = state(_, Procs, NewOut, NewFiles, NewErr, NewClasses, _, UI, Cont),
    get_var(ObjName, State4, UpdatedInstance),
    set_var(ObjName, UpdatedInstance, StateIn, State5),
    State5 = state(Vars5, _, _, _, _, _, _, _, _),
    StateOut = state(Vars5, Procs, NewOut, NewFiles, NewErr, NewClasses, none, UI, Cont).

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
% Tracing Helpers
%------------------------------------------------------------

%% trace_expr_reads(+Expr, +State, +NodeId) is det.
%
% Track data dependencies by recording variable reads in an expression.
% Creates data flow edges from the last write of each variable to this node.

trace_expr_reads(Expr, _State, NodeId) :-
    ( is_tracing
    -> collect_expr_vars(Expr, Vars),
       forall(member(Var, Vars), record_var_read(Var, NodeId))
    ;  true
    ).

%% collect_expr_vars(+Expr, -Vars) is det.
%
% Collect all variable names referenced in an expression.

collect_expr_vars(var(Name), [Name]) :- !.
collect_expr_vars(num(_), []) :- !.
collect_expr_vars(str(_), []) :- !.
collect_expr_vars(op(_, Left, Right), Vars) :- !,
    collect_expr_vars(Left, LeftVars),
    collect_expr_vars(Right, RightVars),
    append(LeftVars, RightVars, Vars).
collect_expr_vars(unary(_, Expr), Vars) :- !,
    collect_expr_vars(Expr, Vars).
collect_expr_vars(call(_, Args), Vars) :- !,
    maplist(collect_expr_vars, Args, VarLists),
    append(VarLists, Vars).
collect_expr_vars(cond(Cond, Then, Else), Vars) :- !,
    collect_expr_vars(Cond, CondVars),
    collect_expr_vars(Then, ThenVars),
    collect_expr_vars(Else, ElseVars),
    append([CondVars, ThenVars, ElseVars], Vars).
collect_expr_vars(member_access(Obj, _), [Obj]) :- !.
collect_expr_vars(array_access(Name, Idx), [Name|IdxVars]) :- !,
    collect_expr_vars(Idx, IdxVars).
collect_expr_vars(_, []).  % Default: no variables

%% trace_condition_vars(+Cond, +NodeId) is det.
%
% Track variable reads in a condition expression for data flow.

trace_condition_vars(Cond, NodeId) :-
    ( is_tracing
    -> collect_expr_vars(Cond, Vars),
       forall(member(Var, Vars), record_var_read(Var, NodeId))
    ;  true
    ).

%------------------------------------------------------------
% Tests
%------------------------------------------------------------

:- use_module(library(plunit)).

:- begin_tests(simulator).

test(run_example_files) :-
    simulator_test_files(Files),
    forall(member(File, Files),
           assertion(run_file(File))).

:- end_tests(simulator).
