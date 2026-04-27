%============================================================
% clarion_simulator.pl - Clarion AST Execution Engine for Erlog
%
% Core execution engine running entirely in Prolog/Erlog.
% Variables can be unbound — Prolog unification propagates
% constraints naturally, enabling backward execution.
%
% Entry points called from Elixir via :erlog.prove/2:
%   run_ast(+AST, -FinalState)
%   init_session(+AST, -Session)
%   call_procedure(+Session, +ProcName, +Args, -Result, -NewSession)
%   exec_program(+AST, +Events, -Result, -FinalState)
%
% Erlog-compatible: no modules, no dicts, ISO-standard.
%============================================================

%------------------------------------------------------------
% Top-level Entry Points
%------------------------------------------------------------

run_ast(AST, FinalState) :-
    AST = program(map(MapDecls), GlobalDecls, code(Statements), Procedures),
    empty_state(InitState),
    init_map_protos(MapDecls, InitState, State0),
    init_procedures(Procedures, State0, State1),
    init_globals(GlobalDecls, State1, State2),
    exec_statements(Statements, State2, FinalState, _Control).

init_session(AST, Session) :-
    AST = program(map(MapDecls), GlobalDecls, _Code, Procedures),
    empty_state(InitState),
    init_map_protos(MapDecls, InitState, State0),
    init_procedures(Procedures, State0, State1),
    init_globals(GlobalDecls, State1, Session).

call_procedure(Session, ProcName, Args, Result, NewSession) :-
    wrap_args(Args, ArgExprs),
    exec_call(ProcName, ArgExprs, Session, NewSession, Result).

exec_program(AST, Events, Result, FinalState) :-
    AST = program(map(MapDecls), GlobalDecls, code(MainBody), Procedures),
    empty_state(InitState),
    init_map_protos(MapDecls, InitState, State0),
    init_procedures(Procedures, State0, State1),
    init_globals(GlobalDecls, State1, State2),
    % Set up event queue
    state_ui(State2, UI),
    set_ui_event_queue(Events, UI, NewUI),
    set_state_ui(NewUI, State2, State3),
    exec_statements(MainBody, State3, FinalState, _Control),
    ( get_var('Result', FinalState, Result) -> true ; Result = 0 ).

wrap_args([], []).
wrap_args([N|Rest], [number(N)|BRest]) :- integer(N), !, wrap_args(Rest, BRest).
wrap_args([N|Rest], [number(N)|BRest]) :- float(N), !, wrap_args(Rest, BRest).
wrap_args([S|Rest], [string(S)|BRest]) :- atom(S), !, wrap_args(Rest, BRest).
wrap_args([E|Rest], [E|BRest]) :- wrap_args(Rest, BRest).

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

init_map_protos(MapDecls, StateIn, StateOut) :-
    set_var('__MAP_PROTOS__', MapDecls, StateIn, StateOut).

init_procedures([], State, State).
init_procedures([Proc|Procs], StateIn, FinalState) :-
    state_procs(StateIn, ExistingProcs),
    set_state_procs([Proc|ExistingProcs], StateIn, State1),
    init_procedures(Procs, State1, FinalState).

init_globals([], State, State).
init_globals([var(Name, _Type, init(InitVal))|Rest], StateIn, StateOut) :-
    InitVal \= none, !,
    set_var(Name, InitVal, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([var(Name, Type, _SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, DefaultVal),
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
    NewFS = file_state(Name, '', [], Fields, [], Buffer, -1, true),
    set_file_state(Name, NewFS, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([window(_Name, _Title, _Attrs, Controls)|Rest], StateIn, StateOut) :-
    assign_equates(Controls, 1, StateIn, State1),
    init_globals(Rest, State1, StateOut).
init_globals([_|Rest], StateIn, StateOut) :-
    init_globals(Rest, StateIn, StateOut).

%------------------------------------------------------------
% Equate Assignment (WINDOW controls)
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

%------------------------------------------------------------
% Group and File Initialization
%------------------------------------------------------------

init_group(Name, Prefix, Fields, StateIn, StateOut) :-
    create_group_value(Fields, GroupValue),
    set_var(Name, group_val(Prefix, Fields, GroupValue), StateIn, State1),
    ( Prefix \= '' ->
        set_var(group_prefix(Prefix), Name, State1, StateOut)
    ;   StateOut = State1
    ).

create_group_value([], []).
create_group_value([field(_, Type, _Size)|Rest], [Value|Values]) :-
    default_value(Type, Value),
    create_group_value(Rest, Values).

init_file(Name, Attrs, Contents, StateIn, StateOut) :-
    ( member(pre(Prefix), Attrs) -> true ; Prefix = '' ),
    ( member(driver(Driver), Attrs) -> true ; Driver = memory ),
    extract_keys(Contents, Keys),
    extract_record_fields(Contents, Fields),
    create_empty_buffer(Fields, Buffer),
    NewFS = file_state(Name, Prefix, Keys, Fields, [], Buffer, -1, false),
    set_file_state(Name, NewFS, StateIn, State1),
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
    ( StmtControl = normal ->
        exec_statements(Stmts, State1, StateOut, Control)
    ;   StateOut = State1, Control = StmtControl
    ).

%------------------------------------------------------------
% Statement Handlers
%------------------------------------------------------------

% Procedure/function call
exec_statement(call(Name, Args), StateIn, StateOut, normal) :- !,
    exec_call(Name, Args, StateIn, StateOut, _Result).

% Assignment
exec_statement(assign(VarName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Value),
    set_var(VarName, Value, StateIn, StateOut).

% Compound assignment (Var += Expr)
exec_statement(assign_add(VarName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Val),
    get_var(VarName, StateIn, CurrentVal),
    NewVal is CurrentVal + Val,
    set_var(VarName, NewVal, StateIn, StateOut).

% Method call (as statement)
exec_statement(method_call(ObjName, MethodName, Args), StateIn, StateOut, normal) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, _Result).

% SELF assignment
exec_statement(self_assign(PropName, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(Expr, StateIn, Value),
    state_self(StateIn, self_context(VarName, _, _)),
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
        set_buffer_field(FieldName, Value, FileState, NewFS),
        set_file_state(VarName, NewFS, StateIn, StateOut)
    ;   eval_full_expr(Expr, StateIn, Value),
        get_var(VarName, StateIn, GroupVal),
        ( GroupVal = group_val(Pfx, Fields, Values) ->
            set_group_field(FieldName, Value, Fields, Values, NewValues),
            set_var(VarName, group_val(Pfx, Fields, NewValues), StateIn, StateOut)
        ; GroupVal = group_val(Fields, Values) ->
            set_group_field(FieldName, Value, Fields, Values, NewValues),
            set_var(VarName, group_val(Fields, NewValues), StateIn, StateOut)
        ; GroupVal = instance(_, _) ->
            set_instance_prop(FieldName, Value, GroupVal, NewInstance),
            set_var(VarName, NewInstance, StateIn, StateOut)
        ;   StateOut = StateIn
        )
    ).

% Array assignment
exec_statement(array_assign(ArrayName, IndexExpr, Expr), StateIn, StateOut, normal) :- !,
    eval_full_expr(IndexExpr, StateIn, Index),
    eval_full_expr(Expr, StateIn, Value),
    get_var(ArrayName, StateIn, ArrayVal),
    ( ArrayVal = array(Elements) ->
        Idx is Index - 1,
        set_array_element(Idx, Value, Elements, NewElements),
        set_var(ArrayName, array(NewElements), StateIn, StateOut)
    ;   set_var(ArrayName, Value, StateIn, StateOut)
    ).

% Return statements
exec_statement(return, State, State, return) :- !.
exec_statement(return(Expr), StateIn, StateIn, return(Value)) :- !,
    eval_full_expr(Expr, StateIn, Value).

% IF statement (4-arg form with ELSIF)
exec_statement(if(Cond, ThenStmts, ElsifClauses, ElseStmts), StateIn, StateOut, Control) :- !,
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal) ->
        exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;   exec_elsifs(ElsifClauses, ElseStmts, StateIn, StateOut, Control)
    ).

% IF statement (3-arg legacy form)
exec_statement(if(Cond, ThenStmts, ElseStmts), StateIn, StateOut, Control) :- !,
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal) ->
        exec_statements(ThenStmts, StateIn, StateOut, Control)
    ;   exec_statements(ElseStmts, StateIn, StateOut, Control)
    ).

% Loop statements
exec_statement(loop(Body), StateIn, StateOut, Control) :- !,
    exec_loop_infinite(Body, StateIn, StateOut, Control).

exec_statement(loop_to(Var, FromExpr, ToExpr, Body), StateIn, StateOut, Control) :- !,
    eval_full_expr(FromExpr, StateIn, From),
    eval_full_expr(ToExpr, StateIn, To),
    set_var(Var, From, StateIn, State1),
    exec_loop_to(Var, To, Body, State1, StateOut, Control).

exec_statement(loop_while(Cond, Body), StateIn, StateOut, Control) :- !,
    exec_loop_while(Cond, Body, StateIn, StateOut, Control).

exec_statement(loop_until(Cond, Body), StateIn, StateOut, Control) :- !,
    exec_loop_until(Cond, Body, StateIn, StateOut, Control).

% BREAK and CYCLE
exec_statement(break, State, State, break) :- !.
exec_statement(cycle, State, State, cycle) :- !.

% CASE statement
exec_statement(case(Expr, Cases, ElseStmts), StateIn, StateOut, Control) :- !,
    eval_full_expr(Expr, StateIn, Value),
    exec_case(Value, Cases, ElseStmts, StateIn, StateOut, Control).

% DO routine call
exec_statement(do(RoutineName), StateIn, StateOut, Control) :- !,
    exec_routine(RoutineName, StateIn, StateOut, Control).

% EXIT (from routine)
exec_statement(exit, State, State, exit) :- !.

% ACCEPT loop
exec_statement(accept(Body), StateIn, StateOut, Control) :- !,
    exec_accept_loop(Body, StateIn, StateOut, Control, open_window).

% No-ops
exec_statement(control_prop_assign(_, _, _), State, State, normal) :- !.
exec_statement(select(_), State, State, normal) :- !.
exec_statement(beep, State, State, normal) :- !.
exec_statement(display, State, State, normal) :- !.

% Catch-all
exec_statement(_, State, State, normal).

%------------------------------------------------------------
% ELSIF Handling
%------------------------------------------------------------

exec_elsifs([], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_elsifs([elsif(Cond, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control) :-
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal) ->
        exec_statements(Stmts, StateIn, StateOut, Control)
    ;   exec_elsifs(Rest, ElseStmts, StateIn, StateOut, Control)
    ).

%------------------------------------------------------------
% Loop Execution
%------------------------------------------------------------

exec_loop_infinite(Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break -> StateOut = State1, Control = normal
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; BodyControl = cycle -> exec_loop_infinite(Body, State1, StateOut, Control)
    ; exec_loop_infinite(Body, State1, StateOut, Control)
    ).

exec_loop_to(Var, To, Body, StateIn, StateOut, Control) :-
    get_var(Var, StateIn, Current),
    ( Current > To ->
        StateOut = StateIn, Control = normal
    ;   exec_statements(Body, StateIn, State1, BodyControl),
        ( BodyControl = break -> StateOut = State1, Control = normal
        ; BodyControl = return -> StateOut = State1, Control = return
        ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
        ;   Next is Current + 1,
            set_var(Var, Next, State1, State2),
            exec_loop_to(Var, To, Body, State2, StateOut, Control)
        )
    ).

exec_loop_while(Cond, Body, StateIn, StateOut, Control) :-
    eval_full_expr(Cond, StateIn, CondVal),
    ( is_truthy(CondVal) ->
        exec_statements(Body, StateIn, State1, BodyControl),
        ( BodyControl = break -> StateOut = State1, Control = normal
        ; BodyControl = return -> StateOut = State1, Control = return
        ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
        ; exec_loop_while(Cond, Body, State1, StateOut, Control)
        )
    ;   StateOut = StateIn, Control = normal
    ).

exec_loop_until(Cond, Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break -> StateOut = State1, Control = normal
    ; BodyControl = return -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ;   eval_full_expr(Cond, State1, CondVal),
        ( is_truthy(CondVal) ->
            StateOut = State1, Control = normal
        ;   exec_loop_until(Cond, Body, State1, StateOut, Control)
        )
    ).

%------------------------------------------------------------
% CASE Execution
%------------------------------------------------------------

exec_case(_, [], ElseStmts, StateIn, StateOut, Control) :-
    exec_statements(ElseStmts, StateIn, StateOut, Control).
exec_case(Value, [case_of(range(StartExpr, EndExpr), Stmts)|Rest], ElseStmts,
          StateIn, StateOut, Control) :- !,
    eval_full_expr(StartExpr, StateIn, StartVal),
    eval_full_expr(EndExpr, StateIn, EndVal),
    ( number(Value), Value >= StartVal, Value =< EndVal ->
        exec_statements(Stmts, StateIn, StateOut, Control)
    ;   exec_case(Value, Rest, ElseStmts, StateIn, StateOut, Control)
    ).
exec_case(Value, [case_of(CaseVal, Stmts)|Rest], ElseStmts, StateIn, StateOut, Control) :-
    eval_full_expr(CaseVal, StateIn, MatchVal),
    ( Value = MatchVal ->
        exec_statements(Stmts, StateIn, StateOut, Control)
    ;   exec_case(Value, Rest, ElseStmts, StateIn, StateOut, Control)
    ).

%------------------------------------------------------------
% Routine Execution
%------------------------------------------------------------

exec_routine(Name, StateIn, StateOut, Control) :-
    get_routine(Name, StateIn, routine(Name, Body)),
    exec_statements(Body, StateIn, StateOut, RoutineControl),
    ( RoutineControl = exit -> Control = normal ; Control = RoutineControl ).

get_routine(Name, State, Routine) :-
    state_procs(State, Procs),
    member(Routine, Procs),
    Routine = routine(Name, _), !.

%------------------------------------------------------------
% ACCEPT Loop Execution (event-driven)
%------------------------------------------------------------

exec_accept_loop(Body, StateIn, StateOut, Control, _Phase) :-
    state_ui(StateIn, UI),
    ui_event_queue(UI, EventQueue),
    ( EventQueue = [Event|RestEvents] ->
        set_ui_event_queue(RestEvents, UI, NewUI),
        set_state_ui(NewUI, StateIn, State1),
        ( Event = set(VarName, Value) ->
            set_var(VarName, Value, State1, State2),
            exec_accept_loop(Body, State2, StateOut, Control, accepted)
        ; Event = choice(EqName, Index) ->
            atom_concat('__CHOICE__', EqName, ChoiceKey),
            set_var(ChoiceKey, Index, State1, State2),
            exec_accept_loop(Body, State2, StateOut, Control, accepted)
        ;   % Button press — set __ACCEPTED__ and run body
            set_var('__ACCEPTED__', Event, State1, State2),
            set_event_phase(accepted, State2, State3),
            exec_statements(Body, State3, State4, BodyControl),
            ( BodyControl = break ->
                StateOut = State4, Control = normal
            ; BodyControl = return(V) ->
                StateOut = State4, Control = return(V)
            ;   exec_accept_loop(Body, State4, StateOut, Control, accepted)
            )
        )
    ;   % No more events — exit accept loop
        StateOut = StateIn, Control = normal
    ).

%------------------------------------------------------------
% Procedure/Function Calls
%------------------------------------------------------------

exec_call(Name, Args, StateIn, StateOut, Result) :-
    ( builtin_call(Name, Args, StateIn, StateOut, Result) -> true
    ; is_external_proc(Name, StateIn) ->
        exec_external_stub(Name, Args, StateIn, StateOut, Result)
    ;   get_proc(Name, StateIn, procedure(_, Params, LocalVars, code(Body))),
        eval_args(Args, StateIn, ArgVals),
        bind_params(Params, ArgVals, StateIn, State1),
        init_locals(LocalVars, State1, State2),
        exec_statements(Body, State2, State3, BodyControl),
        ( BodyControl = return(V) -> Result = V ; Result = none ),
        % Merge globals back
        state_vars(StateIn, OuterVars),
        state_procs(StateIn, Procs),
        state_ui(StateIn, UI),
        state_cont(StateIn, Cont),
        state_vars(State3, InnerVars),
        state_output(State3, NewOut),
        state_files(State3, NewFiles),
        state_error(State3, NewErr),
        state_classes(State3, NewClasses),
        param_names(Params, ParamNames),
        local_names(LocalVars, LocalNames),
        merge_globals(OuterVars, InnerVars, ParamNames, LocalNames, MergedVars),
        StateOut = state(MergedVars, Procs, NewOut, NewFiles, NewErr, NewClasses, none, UI, Cont)
    ).

%------------------------------------------------------------
% External Procedure Stubs
%------------------------------------------------------------

exec_external_stub('MemCopy', _Args, StateIn, StateIn, 0) :- !.
exec_external_stub(Name, Args, StateIn, StateIn, Result) :-
    eval_args(Args, StateIn, _ArgVals),
    ( get_map_proto(Name, StateIn, Proto) ->
        ( Proto = external_proc(_, _, _, RetType, _) -> true
        ; Proto = map_proto(_, _, RetType, _) -> true
        ; RetType = void
        )
    ;   RetType = void
    ),
    ( RetType = void -> Result = none
    ; member(RetType, ['LONG', 'SHORT', 'BYTE', 'DECIMAL', 'PDECIMAL', 'DATE', 'TIME']) ->
        Result = 0
    ; member(RetType, ['REAL', 'SREAL']) -> Result = 0.0
    ; member(RetType, ['STRING', 'CSTRING', 'PSTRING']) -> Result = ''
    ;   Result = 0
    ).

%------------------------------------------------------------
% Global Merge (preserve callee's changes to caller's vars)
%------------------------------------------------------------

merge_globals([], _, _, _, []).
merge_globals([Name-_OldVal|Rest], InnerVars, ParamNames, LocalNames, [Name-NewVal|MergedRest]) :-
    assoc_get(Name, InnerVars, NewVal), !,
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

%------------------------------------------------------------
% Argument Evaluation and Parameter Binding
%------------------------------------------------------------

eval_args([], _, []).
eval_args([Arg|Args], State, [Val|Vals]) :-
    eval_full_expr(Arg, State, Val),
    eval_args(Args, State, Vals).

bind_params([], [], State, State).
bind_params([param(_, Name)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
bind_params([param(_, Name, optional, _)|Params], [Val|Vals], StateIn, StateOut) :-
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, Vals, State1, StateOut).
bind_params([param(Type, Name, optional, Default)|Params], [], StateIn, StateOut) :-
    ( Default = none ->
        default_value(Type, Val)
    ;   eval_full_expr(Default, StateIn, Val)
    ),
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, [], State1, StateOut).
bind_params([], [_|_], State, State).
bind_params([param(Type, Name)|Params], [], StateIn, StateOut) :-
    default_value(Type, Val),
    set_var(Name, Val, StateIn, State1),
    bind_params(Params, [], State1, StateOut).

init_locals([], State, State).
init_locals([var(Name, Type, _SizeSpec)|Rest], StateIn, StateOut) :-
    default_value(Type, Default),
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
init_locals([local_var(Name, Type, _SizeSpec)|Rest], StateIn, StateOut) :-
    Type \= custom(_),
    default_value(Type, Default),
    set_var(Name, Default, StateIn, State1),
    init_locals(Rest, State1, StateOut).
init_locals([window(_, _, _)|Rest], StateIn, StateOut) :-
    init_locals(Rest, StateIn, StateOut).
init_locals([_|Rest], StateIn, StateOut) :-
    init_locals(Rest, StateIn, StateOut).

%------------------------------------------------------------
% Method Call Execution
%------------------------------------------------------------

exec_method_call(ObjName, MethodName, Args, StateIn, StateOut, Result) :-
    get_var(ObjName, StateIn, Instance),
    Instance = instance(ClassName, _),
    find_method_impl(ClassName, MethodName, StateIn, MethodImpl),
    MethodImpl = method_impl(ImplClass, MethodName, Params, _BLocals, code(Body)),
    eval_args(Args, StateIn, ArgVals),
    get_class_def(ClassName, StateIn, class_def(ClassName, ParentClass, _, _)),
    set_state_self(self_context(ObjName, ImplClass, ParentClass), StateIn, State1),
    bind_params(Params, ArgVals, State1, State2),
    exec_statements(Body, State2, State3, BodyControl),
    ( BodyControl = return(V) -> Result = V ; Result = none ),
    state_procs(State3, Procs),
    state_output(State3, NewOut),
    state_files(State3, NewFiles),
    state_error(State3, NewErr),
    state_classes(State3, NewClasses),
    state_ui(StateIn, UI),
    state_cont(StateIn, Cont),
    get_var(ObjName, State3, UpdatedInstance),
    set_var(ObjName, UpdatedInstance, StateIn, State4),
    state_vars(State4, Vars4),
    StateOut = state(Vars4, Procs, NewOut, NewFiles, NewErr, NewClasses, none, UI, Cont).

exec_parent_call(MethodName, Args, StateIn, StateOut, Result) :-
    state_self(StateIn, self_context(ObjName, CurrentClass, _)),
    get_class_def(CurrentClass, StateIn, class_def(CurrentClass, ParentClass, _, _)),
    ( ParentClass \= none ->
        find_method_impl(ParentClass, MethodName, StateIn, MethodImpl),
        MethodImpl = method_impl(ImplClass, MethodName, Params, _BLocals, code(Body)),
        eval_args(Args, StateIn, ArgVals),
        get_class_def(ImplClass, StateIn, class_def(ImplClass, GrandParent, _, _)),
        set_state_self(self_context(ObjName, ImplClass, GrandParent), StateIn, State1),
        bind_params(Params, ArgVals, State1, State2),
        exec_statements(Body, State2, State3, BodyControl),
        ( BodyControl = return(V) -> Result = V ; Result = none ),
        state_self(StateIn, OrigSelf),
        set_state_self(OrigSelf, State3, StateOut)
    ;   StateOut = StateIn, Result = none
    ).

%------------------------------------------------------------
% Array Element Helpers
%------------------------------------------------------------

set_array_element(0, Value, [_|Rest], [Value|Rest]) :- !.
set_array_element(Idx, Value, [H|T], [H|NewT]) :-
    Idx > 0, Idx1 is Idx - 1,
    set_array_element(Idx1, Value, T, NewT).
set_array_element(Idx, Value, [], NewList) :-
    Idx >= 0,
    make_zeros(Idx, Padding),
    append(Padding, [Value], NewList).
