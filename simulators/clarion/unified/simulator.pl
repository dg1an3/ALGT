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
    init_globals/3,          % init_globals(+GlobalDecls, +StateIn, -StateOut)
    with_external_stubs/2    % with_external_stubs(+Stubs, :Goal)
]).

% Note: parser is NOT imported here — the unified system uses
% clarion_parser.pl via ast_bridge.pl instead of the modular parser.
:- use_module(simulator_state).
:- use_module(simulator_eval).
:- use_module(simulator_builtins).
:- use_module(simulator_classes).
:- use_module(simulator_control).
:- use_module(execution_tracer).
:- use_module(clarion_types).
:- use_module(library(assoc)).

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
init_globals([var(Name, Type, init(InitVal))|Rest], StateIn, StateOut) :-
    InitVal \= none, !,
    declare_type(Name, Type, StateIn, State0),
    set_var(Name, InitVal, State0, State1),
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
init_globals([group_init(Name, Field, Value)|Rest], StateIn, StateOut) :-
    assign_member(Name, Field, Value, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([queue(Name, Fields)|Rest], StateIn, StateOut) :-
    init_globals([queue(Name, '', Fields)|Rest], StateIn, StateOut).
init_globals([queue(Name, Prefix, Fields)|Rest], StateIn, StateOut) :-
    create_empty_buffer(Fields, Buffer),
    FileState = file_state(Name, Prefix, [], Fields, [], Buffer, -1, true),
    set_file_state(Name, FileState, StateIn, State1),
    init_globals(Rest, State1, StateOut).
% Global object (its CLASS is declared earlier in the module)
init_globals([instance_global(Name, ClassName)|Rest], StateIn, StateOut) :-
    create_instance(ClassName, StateIn, Instance),
    set_var(Name, Instance, StateIn, State1),
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
control_equate_name(check(_, _, equate(Name)), Name).
% USE(VarName) without ? — Clarion implicitly creates ?VarName equate
control_equate_name(check(_, _, var(Name)), Name).
control_equate_name(entry(_, _, var(Name)), Name).

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
extract_keys([key(KeyName, KeyFields, Attrs)|Rest],
             [key(KeyName, KeyFields), key_attrs(KeyName, Attrs)|Keys]) :- !,
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
exec_statement(assign(VarName, Expr), StateIn0, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn0, StateIn, Value),
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

% Reference assignment (Ref &= Target). Value approximation:
%   NULL -> null;  NEW(Class) -> a fresh instance;  a FILE/QUEUE -> ref(file(F));
%   other names -> a copy of the value;  Expr -> its value
exec_statement(ref_assign(VarName, Target), StateIn, StateOut, normal) :- !,
    ref_target_value(Target, StateIn, State1, Value),
    set_var(VarName, Value, State1, StateOut).

% Method call (as statement)
exec_statement(method_call(ObjName, MethodName, Args), StateIn, StateOut, normal) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, _Result).

% SELF assignment
exec_statement(self_assign(PropName, Expr), StateIn0, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn0, StateIn, Value),
    get_self(StateIn, self_context(VarName, _, _)),
    get_var(VarName, StateIn, Instance),
    set_instance_prop(PropName, Value, Instance, NewInstance),
    set_var(VarName, NewInstance, StateIn, StateOut).

% PARENT method call
exec_statement(parent_call(MethodName, Args), StateIn, StateOut, normal) :- !,
    exec_parent_call(MethodName, Args, StateIn, StateOut, _Result).

% GROUP/instance member assignment
exec_statement(member_assign(VarName, FieldName, Expr), StateIn0, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn0, StateIn, Value),
    assign_member(VarName, FieldName, Value, StateIn, StateOut).

% Array assignment
exec_statement(array_assign(ArrayName, IndexExpr, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(IndexExpr, StateIn, State1, Index),
    eval_full_expr(Expr, State1, State2, Value),
    assign_element(ArrayName, Index, Value, State2, StateOut).

assign_member(VarName, FieldName, Value, StateIn, StateOut) :-
    ( get_file_state(VarName, StateIn, FileState) ->
        set_buffer_field(FieldName, Value, FileState, NewFileState),
        set_file_state(VarName, NewFileState, StateIn, StateOut)
    ;
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

assign_element(ArrayName, Index, Value0, StateIn, StateOut) :-
    ( declared_type(ArrayName, StateIn, Type, Size)
    -> coerce(Type, Size, Value0, Value)
    ;  Value = Value0
    ),
    get_var(ArrayName, StateIn, ArrayVal),
    ( ArrayVal = array(Elements)
    -> Idx is truncate(Index) - 1,
       set_array_element(Idx, Value, Elements, NewElements),
       set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ; is_text(ArrayVal)                  % S[i] = character
    -> assign_slice(ArrayName, Index, Index, Value0, StateIn, StateOut)
    ;  set_var(ArrayName, Value, StateIn, StateOut)
    ).

% S[a:b] = Expr
exec_statement(slice_assign(Name, FromExpr, ToExpr, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(FromExpr, StateIn, State1, From),
    eval_full_expr(ToExpr, State1, State2, To),
    eval_full_expr(Expr, State2, State3, Value),
    assign_slice(Name, From, To, Value, State3, StateOut).

assign_slice(Name, From, To, Value, StateIn, StateOut) :-
    get_var(Name, StateIn, Text),
    replace_slice(Text, From, To, Value, NewText),
    set_var(Name, NewText, StateIn, StateOut).

% A[i] op= Expr (the index is evaluated once)
exec_statement(array_update(Name, IndexExpr, Field, Op, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(IndexExpr, StateIn, State1, Index),
    ( Field == none
    -> Read = array_access(Name, number(Index)), Write = array_assign(Name, number(Index), evaluated(New))
    ;  Read = array_field_access(Name, number(Index), Field),
       Write = array_field_assign(Name, number(Index), Field, evaluated(New))
    ),
    eval_full_expr(Read, State1, State2, Old),
    eval_full_expr(Expr, State2, State3, Value),
    eval_binop(Op, Old, Value, New),
    exec_statement(Write, State3, StateOut, normal).

% A[i].Field = Expr — only when the element is a GROUP value; otherwise warn and skip
exec_statement(array_field_assign(ArrayName, IndexExpr, Field, Expr), StateIn0, StateOut, normal) :- !,
    eval_full_expr(IndexExpr, StateIn0, StateIn1, Index),
    eval_full_expr(Expr, StateIn1, StateIn, Value),
    Idx is truncate(Index) - 1,
    (   get_var(ArrayName, StateIn, array(Elements)),
        simulator_eval:get_array_element(Idx, Elements, Elem),
        ( Elem = group_val(P, Fields, Values) -> NewElem = group_val(P, Fields, NewValues)
        ; Elem = group_val(Fields, Values) -> NewElem = group_val(Fields, NewValues) )
    ->  set_group_field(Field, Value, Fields, Values, NewValues),
        set_array_element(Idx, NewElem, Elements, NewElements),
        set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ;   format(user_error, "Warning: ~w[~w] is not a GROUP element; ~w not assigned~n",
               [ArrayName, Index, Field]),
        StateOut = StateIn
    ).

exec_statement(assign_add(VarName, Expr), StateIn0, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn0, StateIn, Val),
    get_var(VarName, StateIn, CurrentVal),
    eval_binop('+', CurrentVal, Val, NewVal),
    set_var(VarName, NewVal, StateIn, StateOut).

% Return statements
exec_statement(return, State, State, return) :- !.
exec_statement(return(Expr), StateIn, StateOut, return(Value)) :- !,
    eval_full_expr(Expr, StateIn, StateOut, Value).

% IF statement (4-arg form with ELSIF) - with tracing
exec_statement(if(Cond, ThenStmts, ElsifClauses, ElseStmts), StateIn0, StateOut, Control) :- !,
    eval_full_expr(Cond, StateIn0, StateIn, CondVal),
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
exec_statement(if(Cond, ThenStmts, ElseStmts), StateIn0, StateOut, Control) :- !,
    \+ is_list(ElseStmts),
    eval_full_expr(Cond, StateIn0, StateIn, CondVal),
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
    exec_statement(loop_to(Var, FromExpr, ToExpr, number(1), Body), StateIn, StateOut, Control).
exec_statement(loop_times(CountExpr, Body), StateIn, StateOut, Control) :- !,
    eval_full_expr(CountExpr, StateIn, State1, Count0),
    to_number(Count0, Count),
    exec_loop_times(Count, Body, State1, StateOut, Control).
exec_statement(loop_to(Var, FromExpr, ToExpr, StepExpr, Body), StateIn0, StateOut, Control) :- !,
    eval_full_expr(FromExpr, StateIn0, StateIn1, From),
    eval_full_expr(ToExpr, StateIn1, StateIn2, To),
    eval_full_expr(StepExpr, StateIn2, StateIn, Step0),
    to_number(Step0, Step),
    ( Step =:= 0 -> throw(error(loop_step_zero(Var), context(exec_statement/4, 'LOOP ... BY 0 never ends'))) ; true ),
    ( is_tracing
    -> trace_loop_start(loop_to, info{var: Var, from: From, to: To}),
       add_graph_node(loop, loop{type: loop_to, var: Var, from: From, to: To}, _)
    ;  true
    ),
    set_var(Var, From, StateIn, State1),
    exec_loop_to(Var, To, Step, Body, State1, StateOut, Control),
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
exec_statement(case(Expr, Cases, ElseStmts), StateIn0, StateOut, Control) :- !,
    eval_full_expr(Expr, StateIn0, StateIn, Value),
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

%% eval_full_expr(+Expr, +StateIn, -StateOut, -Value)
%  Calls inside an expression run left to right and keep their side effects.
eval_full_expr(binop(Op, Left, Right), StateIn, StateOut, Result) :- !,
    eval_full_expr(Left, StateIn, State1, LVal),
    eval_full_expr(Right, State1, StateOut, RVal),
    eval_binop(Op, LVal, RVal, Result).
eval_full_expr(call(Name, Args), StateIn, StateOut, Result) :- !,
    exec_call(Name, Args, StateIn, StateOut, Result).
eval_full_expr(method_call(ObjName, MethodName, Args), StateIn, StateOut, Result) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, Result).
eval_full_expr(self_access(PropName), State, State, Value) :- !,
    get_self(State, self_context(VarName, _, _)),
    get_var(VarName, State, Instance),
    get_instance_prop(PropName, Instance, Value).
eval_full_expr(member_access(ObjName, PropName), State, State, Value) :- !,
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
eval_full_expr(not(Expr), StateIn, StateOut, Result) :- !,
    eval_full_expr(Expr, StateIn, StateOut, Val),
    ( is_truthy(Val) -> Result = 0 ; Result = 1 ).
% Reference identity: Ref &= NULL, Ref &= Other (compares the stored references)
eval_full_expr(ref_eq(A, null), StateIn, StateOut, Result) :- !,
    eval_full_expr(A, StateIn, StateOut, V),
    ( V == null -> Result = 1 ; Result = 0 ).
eval_full_expr(ref_eq(A, B), StateIn, StateOut, Result) :- !,
    eval_full_expr(A, StateIn, State1, VA),
    eval_full_expr(B, State1, StateOut, VB),
    ( VA == VB -> Result = 1 ; Result = 0 ).
% Omitted call argument f(, a): passed through as the atom 'omitted'
eval_full_expr(omitted, State, State, omitted) :- !.
eval_full_expr(slice(Name, FromExpr, ToExpr), StateIn, StateOut, Value) :- !,
    eval_full_expr(FromExpr, StateIn, State1, From),
    eval_full_expr(ToExpr, State1, StateOut, To),
    eval_expr(slice(Name, number(From), number(To)), StateOut, Value).
eval_full_expr(array_access(ArrayName, IndexExpr), StateIn, StateOut, Value) :- !,
    eval_full_expr(IndexExpr, StateIn, StateOut, Index),
    eval_expr(array_access(ArrayName, number(Index)), StateOut, Value).
% A[i].Field — field of a GROUP array element (0 if the element is not a group)
eval_full_expr(array_field_access(ArrayName, IndexExpr, Field), StateIn, State, Value) :- !,
    eval_full_expr(IndexExpr, StateIn, State, Index),
    ( get_var(ArrayName, State, array(Elements)),
      Idx is truncate(Index) - 1,
      simulator_eval:get_array_element(Idx, Elements, Elem),
      ( Elem = group_val(_, Fields, Values) ; Elem = group_val(Fields, Values) )
    -> get_group_field(Field, Fields, Values, Value)
    ;  Value = 0
    ).
eval_full_expr(Expr, State, State, Value) :-
    eval_expr(Expr, State, Value).

%------------------------------------------------------------
% ELSIF Handling
%------------------------------------------------------------

exec_elsifs([], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_elsifs([elsif(Cond, Stmts)|Rest], ElseStmts, StateIn0, StateOut, Control) :-
    eval_full_expr(Cond, StateIn0, StateIn, CondVal),
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
    ; BodyControl = exit -> StateOut = State1, Control = exit
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; exec_loop_infinite(Body, State1, StateOut, Control)
    ).

exec_loop_to(Var, To, Step, Body, StateIn, StateOut, Control) :-
    get_var(Var, StateIn, Current),
    ( loop_done(Step, Current, To)
    -> StateOut = StateIn, Control = normal
    ;  exec_statements(Body, StateIn, State1, BodyControl),
       ( loop_exit(BodyControl, Control0)
       -> StateOut = State1, Control = Control0
       ;  Next is Current + Step,
          set_var(Var, Next, State1, State2),
          exec_loop_to(Var, To, Step, Body, State2, StateOut, Control)
       )
    ).

loop_done(Step, Current, To) :- ( Step < 0 -> Current < To ; Current > To ).

loop_exit(break, normal).
loop_exit(exit, exit).
loop_exit(return, return).
loop_exit(return(V), return(V)).

exec_loop_times(N, Body, StateIn, StateOut, Control) :-
    ( N < 1
    -> StateOut = StateIn, Control = normal
    ;  exec_statements(Body, StateIn, State1, BodyControl),
       ( loop_exit(BodyControl, Control0)
       -> StateOut = State1, Control = Control0
       ;  N1 is N - 1,
          exec_loop_times(N1, Body, State1, StateOut, Control)
       )
    ).

exec_loop_while(Cond, Body, StateIn0, StateOut, Control) :-
    eval_full_expr(Cond, StateIn0, StateIn, CondVal),
    ( is_truthy(CondVal)
    -> exec_statements(Body, StateIn, State1, BodyControl),
       ( BodyControl = break -> StateOut = State1, Control = normal
       ; BodyControl = exit -> StateOut = State1, Control = exit
    ; BodyControl = return -> StateOut = State1, Control = return
       ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
       ; exec_loop_while(Cond, Body, State1, StateOut, Control)
       )
    ;  StateOut = StateIn, Control = normal
    ).

exec_loop_until(Cond, Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break -> StateOut = State1, Control = normal
    ; BodyControl = exit -> StateOut = State1, Control = exit
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; eval_full_expr(Cond, State1, State2, CondVal),
      ( is_truthy(CondVal)
      -> StateOut = State2, Control = normal
      ;  exec_loop_until(Cond, Body, State2, StateOut, Control)
      )
    ).

%------------------------------------------------------------
% CASE Execution
%------------------------------------------------------------

% Traced version of exec_case that records which branch was taken
exec_case_traced(_, [], ElseStmts, StateIn, StateOut, Control, Index) :-
    ( is_tracing
    -> trace_case_match(else, else, Index)
    ;  true
    ),
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_case_traced(Value, [case_of(range(StartExpr, EndExpr), Stmts)|Rest], ElseStmts, StateIn, StateOut, Control, Index) :- !,
    eval_full_expr(StartExpr, StateIn, _, StartVal),
    eval_full_expr(EndExpr, StateIn, _, EndVal),
    ( compare_values(O1, Value, StartVal), O1 \== (<),
      compare_values(O2, Value, EndVal), O2 \== (>)
    -> ( is_tracing
       -> trace_case_match(Value, range(StartVal, EndVal), Index)
       ;  true
       ),
       exec_statements(Stmts, StateIn, StateOut, Control)
    ;  NextIndex is Index + 1,
       exec_case_traced(Value, Rest, ElseStmts, StateIn, StateOut, Control, NextIndex)
    ).
exec_case_traced(Value, [case_of(CaseVal, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control, Index) :-
    eval_full_expr(CaseVal, StateIn, _, MatchVal),
    ( compare_values(=, Value, MatchVal)
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
        ; Event = accepted(EqName) ->
            % Accepted event — set __ACCEPTED__ to equate and __EVENT__ to EVENT:Accepted (1)
            ( get_var(equate(EqName), State1, EqVal) -> true ; EqVal = 0 ),
            set_var('__ACCEPTED__', EqVal, State1, StateA1),
            set_var('__EVENT__', 1, StateA1, State2),
            exec_statements(Body, State2, State3, BodyControl),
            ( BodyControl = break
            -> StateOut = State3, Control = normal
            ; BodyControl = return(V)
            -> StateOut = State3, Control = return(V)
            ; exec_accept_loop(Body, State3, StateOut, Control, accepted)
            )
        ; Event = selected(EqName) ->
            % Selected event — set __ACCEPTED__ to equate and __EVENT__ to EVENT:Selected (2)
            ( get_var(equate(EqName), State1, EqVal2) -> true ; EqVal2 = 0 ),
            set_var('__ACCEPTED__', EqVal2, State1, StateS1),
            set_var('__EVENT__', 2, StateS1, State2),
            exec_statements(Body, State2, State3, BodyControl),
            ( BodyControl = break
            -> StateOut = State3, Control = normal
            ; BodyControl = return(V)
            -> StateOut = State3, Control = return(V)
            ; exec_accept_loop(Body, State3, StateOut, Control, accepted)
            )
        ; Event = new_selection(EqName) ->
            % NewSelection event — set __ACCEPTED__ to equate and __EVENT__ to EVENT:NewSelection (17)
            ( get_var(equate(EqName), State1, EqVal3) -> true ; EqVal3 = 0 ),
            set_var('__ACCEPTED__', EqVal3, State1, StateN1),
            set_var('__EVENT__', 17, StateN1, State2),
            exec_statements(Body, State2, State3, BodyControl),
            ( BodyControl = break
            -> StateOut = State3, Control = normal
            ; BodyControl = return(V)
            -> StateOut = State3, Control = return(V)
            ; exec_accept_loop(Body, State3, StateOut, Control, accepted)
            )
        ;   % Button press event (integer) — set __ACCEPTED__ only (legacy path)
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
    % Clarion is case-insensitive; builtins are registered UPPERCASE
    upcase_atom(Name, UName),
    ( ( \+ is_builtin(UName) ; own_procedure(Name, Args, StateIn) )
    -> exec_user_call(Name, Args, StateIn, StateOut, Result)
    ; builtin_args(UName, Args, StateIn, State1, BuiltinArgs),
      builtin_call(UName, BuiltinArgs, State1, StateOut, Result)
    -> true
    ; find_proc(Name, StateIn, _)
    -> exec_user_call(Name, Args, StateIn, StateOut, Result)
    ; length(Args, Arity),
      throw(error(builtin_failed(UName, Arity), context(exec_call/5, 'Built-in cannot handle these arguments')))
    ).

% The program's own procedure hides a built-in of that name (Add(1, 2)), except
% where the built-in is meant: ADD(File).
own_procedure(Name, Args, State) :-
    find_proc(Name, State, _),
    \+ ( Args = [var(First)|_], file_ref_target(First, State, _) ).

is_builtin(UName) :-
    clause(simulator_builtins:builtin_call(UName, _, _, _, _), _), !.

% Built-ins read simple arguments themselves (some need the variable, not its
% value). Anything that may contain a call is evaluated first.
builtin_args(_, [], State, State, []).
builtin_args(UName, [Arg0|Args], StateIn, StateOut, [Arg1|Args1]) :-
    ( about_the_name(UName) -> Arg = Arg0 ; resolve_ref_arg(Arg0, StateIn, Arg) ),
    ( simple_arg(Arg)
    -> Arg1 = Arg, State1 = StateIn
    ;  eval_full_expr(Arg, StateIn, State1, Value),
       ( number(Value) -> Arg1 = number(Value)
       ; compound(Value) -> Arg1 = evaluated(Value)
       ; Arg1 = string(Value) )
    ),
    builtin_args(UName, Args, State1, StateOut, Args1).

% Built-ins that work on the parameter or reference itself, not what it refers to
about_the_name('OMITTED').
about_the_name('DISPOSE').

% A by-reference parameter or file reference stands for what it refers to
resolve_ref_arg(var(Name), State, Arg) :-
    get_vars(State, Vars),
    ( alias_of(Name, Vars, Target) -> resolve_ref_arg(var(Target), State, Arg)
    ; file_ref_target(Name, State, File) -> Arg = var(File)
    ), !.
resolve_ref_arg(Arg, _, Arg).

% Name is a FILE or QUEUE, or a variable that refers to one
file_ref_target(Name, State, Name) :- get_file_state(Name, State, _), !.
file_ref_target(Name, State, File) :-
    get_vars(State, Vars),
    ( alias_of(Name, Vars, Target) -> file_ref_target(Target, State, File)
    ; memberchk(var(Name, Value), Vars), nonvar(Value), Value = ref(file(File))
    ).

simple_arg(var(_)).
simple_arg(control_ref(_)).
simple_arg(picture(_)).
simple_arg(number(_)).
simple_arg(string(_)).
simple_arg(omitted).

exec_user_call(Name, Args, StateIn, StateOut, Result) :-
    ( find_proc(Name, StateIn, Proc)
    -> Proc = procedure(ProcName, Params, LocalVars, code(Body)),
       exec_proc(Name, ProcName, Params, LocalVars, Body, Args, StateIn, StateOut, Result)
    ; is_external_proc(Name, StateIn)
    -> exec_external_stub(Name, Args, StateIn, StateOut, Result)
    ;  throw(error(undefined_procedure(Name), context(exec_call/5, 'Undefined procedure')))
    ).

% get_proc/3 without the message when there is none
find_proc(Name, State, Proc) :-
    get_procs(State, Procs),
    ( Proc = procedure(Name, _, _, _), memberchk(Proc, Procs)
    -> true
    ;  resolve_name_alias(Name, State, ClarionName),
       Proc = procedure(ClarionName, _, _, _), memberchk(Proc, Procs)
    ).

exec_proc(Name, ProcName, Params, LocalVars, Body, Args, StateIn, StateOut, Result) :-
    frame_keys(Params, LocalVars, CalleeKeys),
    pass_args(Params, Args, CalleeKeys, StateIn, CallState, ArgVals),
    % Trace: procedure entry
    ( is_tracing
    -> trace_proc_enter(Name, ArgVals),
       add_graph_node(call, call{name: Name, args: ArgVals}, _CallNodeId)
    ;  true
    ),
    enter_frame(Params, LocalVars, CallState, State0),
    bind_params(Params, ArgVals, State0, State1),
    ref_values(Params, State1, BoundRefs),
    init_locals(LocalVars, State1, State2),
    exec_statements(Body, State2, State3, Control),
    ( Control = return(V) -> Result0 = V ; Result0 = none ),
    proc_result(ProcName, Result0, StateIn, Result),
    % Trace: procedure exit
    ( is_tracing
    -> trace_proc_exit(Name, Result),
       add_graph_node(return, return{name: Name, value: Result}, _RetNodeId)
    ;  true
    ),
    ref_values(Params, State3, FinalRefs),
    leave_frame(CallState, State3, State4),
    copy_out(Params, Args, BoundRefs, FinalRefs, State4, StateOut).

% Convert a result to the MAP return type. A typed function that returns
% nothing gives that type's empty value.
proc_result(ProcName, Result0, State, Result) :-
    ( get_map_proto(ProcName, State, Proto),
      ( Proto = map_proto(_, _, Type, _) ; Proto = external_proc(_, _, _, Type, _) ),
      Type \== void
    -> ( Result0 == none -> type_default(Type, none, Result) ; coerce(Type, none, Result0, Result) )
    ;  Result = Result0
    ).

%------------------------------------------------------------
% Procedure frames
%------------------------------------------------------------
% A procedure sees the globals and its own parameters and locals, never its
% caller's. var('$frame', frame(Keys, Shadowed)) records the current
% procedure's own names and the globals they hide.

enter_frame(Params, LocalVars, StateIn, StateOut) :-
    frame_globals(StateIn, _, Globals),
    frame_keys(Params, LocalVars, Keys),
    partition_vars(Globals, Keys, Shadowed, Visible),
    replace_vars([var('$frame', frame(Keys, Shadowed))|Visible], StateIn, StateOut).

% CallState is the caller's state, Inner the callee's at exit.
leave_frame(CallState, Inner, StateOut) :-
    frame_globals(CallState, CallerFrame, GlobalsBefore),
    get_vars(Inner, InnerVars),
    memberchk(var('$frame', frame(InnerKeys, Shadowed)), InnerVars),
    vars_assoc(InnerVars, InnerAssoc),
    vars_assoc(Shadowed, ShadowAssoc),
    % Names the callee made up itself are dropped
    findall(var(Key, Value),
            ( member(var(Key, _), GlobalsBefore),
              ( key_in(Key, InnerKeys)
              -> get_assoc(Key, ShadowAssoc, Value)
              ;  get_assoc(Key, InnerAssoc, Value)
              ) ),
            Globals),
    CallerFrame = frame(CallerKeys, Locals),
    ( CallerKeys == none
    -> Vars = Globals
    ;  partition_vars(Globals, CallerKeys, CallerShadowed, Visible),
       append([var('$frame', frame(CallerKeys, CallerShadowed))|Locals], Visible, Vars)
    ),
    CallState = state(_, Procs, _, _, _, _, Self, UI, Cont),
    Inner = state(_, _, Out, Files, Err, Classes, _, _, _),
    StateOut = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont).

% frame_globals(+State, -frame(Keys, LocalVars), -Globals)
frame_globals(State, frame(Keys, Locals), Globals) :-
    get_vars(State, Vars),
    ( selectchk(var('$frame', frame(Keys, Shadowed)), Vars, Rest)
    -> partition_vars(Rest, Keys, Locals, Visible),
       append(Shadowed, Visible, Globals)
    ;  Keys = none, Locals = [], Globals = Vars
    ).

frame_keys(Params, LocalVars, Keys) :-
    param_names(Params, ParamNames),
    local_names(LocalVars, LocalNames),
    append(ParamNames, LocalNames, Keys).

partition_vars([], _, [], []).
partition_vars([V|Vs], Keys, In, Out) :-
    V = var(Key, _),
    ( key_in(Key, Keys)
    -> In = [V|In1], Out = Out1
    ;  In = In1, Out = [V|Out1]
    ),
    partition_vars(Vs, Keys, In1, Out1).

key_in('$type'(Name), Keys) :- !, memberchk(Name, Keys).
key_in('$omitted'(Name), Keys) :- !, memberchk(Name, Keys).
key_in(Key, _) :- implicit_long_name(Key), !.      % Name# belongs to its procedure
key_in(Key, Keys) :- memberchk(Key, Keys).

vars_assoc(Vars, Assoc) :-
    empty_assoc(Empty),
    foldl([var(K, V), A0, A]>>put_assoc(K, A0, V, A), Vars, Empty, Assoc).

replace_vars(Vars, state(_, Procs, Out, Files, Err, Classes, Self, UI, Cont),
                   state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont)).

%------------------------------------------------------------
% By-reference parameters
%------------------------------------------------------------
% A plain name the procedure can also see (a global, record field, key, file)
% is passed as an alias, so both names always show the same value. The caller's
% own variables are out of the procedure's sight, as is a global hidden by one
% of its names: those are copied in, and copied back if changed.

pass_args([], Args, _, StateIn, StateOut, Vals) :- !,
    eval_args(Args, StateIn, StateOut, Vals).
pass_args(_, [], _, State, State, []) :- !.
pass_args([Param|Params], [Arg|Args], CalleeKeys, StateIn, StateOut, [Val|Vals]) :-
    ( file_param(Param), Arg = var(Name), file_ref_target(Name, StateIn, File)
    -> Val = ref(file(File)), State1 = StateIn
    ; ref_param(Param, _), Arg = var(Name),
      alias_target(Name, StateIn, Target),
      visible_to_callee(Target, CalleeKeys, StateIn)
    -> Val = alias(Target), State1 = StateIn
    ;  eval_full_expr(Arg, StateIn, State1, Val)
    ),
    pass_args(Params, Args, CalleeKeys, State1, StateOut, Vals).

file_param(param(file_ref, _)).
file_param(param(file_ref, _, _, _)).

% An alias never points at another alias
alias_target(Name, State, Target) :-
    get_vars(State, Vars),
    ( alias_of(Name, Vars, Next) -> alias_target(Next, State, Target) ; Target = Name ).

visible_to_callee(Name, CalleeKeys, State) :-
    get_vars(State, Vars),
    ( memberchk(var('$frame', frame(CallerKeys, _)), Vars) -> true ; CallerKeys = [] ),
    \+ ( member(Keys, [CallerKeys, CalleeKeys]), own_name(Name, Keys) ).

own_name(Name, Keys) :- key_in(Name, Keys), !.
own_name(Name, Keys) :-
    parse_prefixed_name(Name, Prefix, _),
    ( memberchk(group_prefix(Prefix), Keys) ; memberchk(Prefix, Keys) ), !.

ref_values([], _, []).
ref_values([Param|Params], State, [Value|Values]) :-
    ( ref_param(Param, Name), get_vars(State, Vars), memberchk(var(Name, Value0), Vars)
    -> Value = Value0
    ;  Value = none
    ),
    ref_values(Params, State, Values).

ref_param(param(ref(_), Name), Name).
ref_param(param(ref(_), Name, _, _), Name).

copy_out([Param|Params], [Arg|Args], [Before|Bs], [After|As], StateIn, StateOut) :- !,
    ( ref_param(Param, _), Before \== After, assign_lvalue(Arg, After, StateIn, State1)
    -> true
    ;  State1 = StateIn
    ),
    copy_out(Params, Args, Bs, As, State1, StateOut).
copy_out(_, _, _, _, State, State).

assign_lvalue(var(Name), Value, StateIn, StateOut) :-
    set_var(Name, Value, StateIn, StateOut).
assign_lvalue(array_access(Name, IndexExpr), Value, StateIn, StateOut) :-
    eval_full_expr(IndexExpr, StateIn, _, Index),
    assign_element(Name, Index, Value, StateIn, StateOut).
assign_lvalue(member_access(Name, Field), Value, StateIn, StateOut) :-
    assign_member(Name, Field, Value, StateIn, StateOut).

assign_lvalue(self_access(Prop), Value, StateIn, StateOut) :-
    get_self(StateIn, self_context(VarName, _, _)),
    get_var(VarName, StateIn, Instance),
    set_instance_prop(Prop, Value, Instance, NewInstance),
    set_var(VarName, NewInstance, StateIn, StateOut).

%------------------------------------------------------------
% External Procedure Stubs (MODULE declarations)
%------------------------------------------------------------

%% exec_external_stub(+Name, +Args, +StateIn, -StateOut, -Result)
%
% A MODULE procedure whose source is not loaded is an error, because a made-up
% result (0 usually means success) would hide what it was meant to do. Supply a
% result with with_external_stubs/2. MemCopy is the one built-in exception.

:- meta_predicate with_external_stubs(+, 0).
:- thread_local external_stub/2.

%% with_external_stubs(+Stubs, :Goal)
%  Run Goal with Name=Value results for external procedures (any case). The
%  value 'default' means the empty value of the declared return type.
with_external_stubs(Stubs, Goal) :-
    setup_call_cleanup(
        findall(Ref, ( member(Name=Value, Stubs), upcase_atom(Name, U),
                       asserta(external_stub(U, Value), Ref) ), Refs),
        Goal,
        maplist(erase, Refs)).

% MemCopy/RtlMoveMemory simulation: copy GROUP fields from src var to dest var
% In compiled Clarion, MemCopy(ADDRESS(dest), ADDRESS(src), SIZE(src)) copies bytes.
% In the simulator, we find which variables correspond to the addresses and copy
% the group value. This is a best-effort simulation.
exec_external_stub('MemCopy', [DestExpr, SrcExpr, _LenExpr], StateIn, StateOut, 0) :- !,
    % A no-op: ADDRESS returns synthetic values, and Clarion code copies the
    % fields by assignment (e.g. TB:Month = TR:Month). Only external callers
    % that take a pointer would see the difference.
    eval_full_expr(DestExpr, StateIn, State1, _DestAddr),
    eval_full_expr(SrcExpr, State1, StateOut, _SrcAddr).

exec_external_stub(Name, Args, StateIn, StateOut, Result) :-
    eval_args(Args, StateIn, StateOut, ArgVals),
    % Look up the MAP prototype for return type info
    ( get_map_proto(Name, StateIn, Proto)
    -> ( Proto = external_proc(_, ModName, _, RetType, _)
       -> true
       ; Proto = map_proto(_, _, RetType, _), ModName = local
       )
    ;  RetType = void, ModName = unknown
    ),
    upcase_atom(Name, UName),
    ( external_stub(UName, Stub)
    -> ( Stub \== default -> Result = Stub
       ; RetType == void -> Result = none
       ; type_default(RetType, none, Result)
       )
    ;  throw(error(unresolved_external(Name, ModName),
                   context(exec_call/5, 'Procedure source not loaded; see with_external_stubs/2')))
    ),
    % Trace if enabled
    ( is_tracing
    -> trace_proc_enter(Name, ArgVals),
       add_graph_node(call, call{type: external, name: Name, module: ModName, args: ArgVals}, _),
       trace_proc_exit(Name, Result),
       add_graph_node(return, return{type: external, name: Name, value: Result}, _)
    ;  true
    ),
    format("  [EXTERNAL ~w:~w(~w) -> ~w]~n", [ModName, Name, ArgVals, Result]).

param_names([], []).
param_names([param(_, Name)|Rest], [Name|Names]) :- param_names(Rest, Names).
param_names([param(_, Name, _, _)|Rest], [Name|Names]) :- param_names(Rest, Names).

local_names([], []).
local_names([local_var(Name, _, _)|Rest], [Name|Names]) :- !, local_names(Rest, Names).
local_names([local_decl(group(Name, Prefix, _))|Rest], [Name, group_prefix(Prefix)|Names]) :- !,
    local_names(Rest, Names).
local_names([var(Name, _, _)|Rest], [Name|Names]) :- !, local_names(Rest, Names).
local_names([_|Rest], Names) :- local_names(Rest, Names).

eval_args([], State, State, []).
eval_args([Arg|Args], StateIn, StateOut, [Val|Vals]) :-
    eval_full_expr(Arg, StateIn, State1, Val),
    eval_args(Args, State1, StateOut, Vals).

bind_params([], _, State, State).      % extra arguments are ignored
bind_params([Param|Params], Vals0, StateIn, StateOut) :-
    ( Param = param(Type, Name, optional, Default) -> true
    ; Param = param(Type, Name), Default = none ),
    ( Vals0 = [V|Vals] -> true ; V = omitted, Vals = [] ),
    ( V \== omitted -> Val = V
    ; Default == none -> split_type(Type, T, Size), default_value(T, Size, Val)
    ; eval_full_expr(Default, StateIn, _, Val)
    ),
    declare_type(Name, Type, StateIn, State1),
    set_var(Name, Val, State1, State2),
    ( V == omitted -> Omitted = 1 ; Omitted = 0 ),     % for OMITTED()
    set_var('$omitted'(Name), Omitted, State2, State3),
    bind_params(Params, Vals, State3, StateOut).

ref_target_value(null, State, State, null).
ref_target_value(new(Class), State, State, Instance) :-
    create_instance(Class, State, Instance).
ref_target_value(name(Name), State, State, Value) :-
    ( file_ref_target(Name, State, File) -> Value = ref(file(File))
    ; get_var(Name, State, V) -> Value = V
    ; Value = ref(Name)
    ).
ref_target_value(expr(Expr), StateIn, StateOut, Value) :-
    eval_full_expr(Expr, StateIn, StateOut, Value).

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
    declare_type(Name, Type, StateIn, State0),
    set_var(Name, InitVal, State0, State1),
    init_locals(Rest, State1, StateOut).
init_locals([local_var(Name, Type, SizeSpec)|Rest], StateIn, StateOut) :-
    Type \= custom(_),
    default_value(Type, SizeSpec, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
% Local QUEUE / GROUP (from the bridge): same initialisation as globals
init_locals([local_decl(Decl)|Rest], StateIn, StateOut) :- !,
    init_globals([Decl], StateIn, State1),
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
    eval_args(Args, StateIn, ArgState, ArgVals),
    % Trace: method entry
    ( is_tracing
    -> trace_method_enter(ObjName, MethodName, ArgVals),
       add_graph_node(call, call{type: method, object: ObjName, method: MethodName, args: ArgVals}, _)
    ;  true
    ),
    get_class_def(ClassName, StateIn, class_def(ClassName, ParentClass, _, _)),
    set_self(self_context(ObjName, ImplClass, ParentClass), ArgState, State1),
    enter_method(Params, LocalVars, State1, State1a),
    bind_params(Params, ArgVals, State1a, State2),
    init_locals(LocalVars, State2, State3),
    exec_statements(Body, State3, State4, Control),
    ( Control = return(V) -> Result = V ; Result = none ),
    % Trace: method exit
    ( is_tracing
    -> trace_method_exit(ObjName, MethodName, Result),
       add_graph_node(return, return{type: method, object: ObjName, method: MethodName, value: Result}, _)
    ;  true
    ),
    leave_method(Params, LocalVars, ArgState, State4, StateOut).

% A method's parameters and locals must not write through an alias of the same
% name in its caller, and Name# variables start afresh.
enter_method(Params, LocalVars, StateIn, StateOut) :-
    frame_keys(Params, LocalVars, Keys),
    get_vars(StateIn, Vars),
    exclude([var(Key, Value)]>>( implicit_long_name(Key)
                               ; nonvar(Value), Value = alias(_), key_in(Key, Keys) ),
            Vars, Vars1),
    replace_vars(Vars1, StateIn, StateOut).

% A method works on its caller's variables (its instance may be one of them),
% so on exit only its own parameters and locals are put back.
leave_method(Params, LocalVars, Before, Inner, StateOut) :-
    frame_keys(Params, LocalVars, Keys),
    get_vars(Before, VarsBefore),
    get_vars(Inner, VarsInner),
    vars_assoc(VarsInner, InnerAssoc),
    findall(var(Key, Value),
            ( member(var(Key, Value0), VarsBefore),
              ( \+ key_in(Key, Keys), get_assoc(Key, InnerAssoc, Value1)
              -> Value = Value1
              ;  Value = Value0
              ) ),
            Vars),
    get_self(Before, Self),
    replace_vars(Vars, Inner, State1),
    set_self(Self, State1, StateOut).

exec_parent_call(MethodName, Args, StateIn, StateOut, Result) :-
    get_self(StateIn, self_context(ObjName, CurrentClass, _)),
    get_class_def(CurrentClass, StateIn, class_def(CurrentClass, ParentClass, _, _)),
    ( ParentClass \= none
    -> find_method_impl(ParentClass, MethodName, StateIn, MethodImpl),
       MethodImpl = method_impl(ImplClass, MethodName, Params, LocalVars, code(Body)),
       eval_args(Args, StateIn, ArgState, ArgVals),
       get_class_def(ImplClass, StateIn, class_def(ImplClass, GrandParent, _, _)),
       set_self(self_context(ObjName, ImplClass, GrandParent), ArgState, State1),
       enter_method(Params, LocalVars, State1, State1a),
       bind_params(Params, ArgVals, State1a, State2),
       init_locals(LocalVars, State2, State3),
       exec_statements(Body, State3, State4, Control),
       ( Control = return(V) -> Result = V ; Result = none ),
       leave_method(Params, LocalVars, ArgState, State4, StateOut)
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
    Idx > 0, !,
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
