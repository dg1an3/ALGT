%============================================================
% clarion.pl - Unified Clarion Simulator
%
% Combines the simple parser (proven, handles MEMBER/PROGRAM)
% with the modular execution engine (pluggable storage, OOP,
% execution tracer, scenario DSL).
%
% Usage:
%   :- use_module(clarion).
%   run_source(Source).
%   exec_procedure(Source, ProcName, Args, Result).
%   exec_program(Source, Events, Result).
%
% For stateful multi-call (DLL simulation):
%   init_session(Source, Session).
%   call_procedure(Session, ProcName, Args, Result, Session2).
%============================================================

:- module(clarion, [
    parse_clarion/2,           % parse_clarion(+Source, -SimpleAST)
    bridge/2,                  % bridge(+SimpleAST, -ModularAST)
    run_source/1,              % run_source(+Source)
    run_source/2,              % run_source(+Source, -FinalState)
    run_file/1,                % run_file(+FileName)
    exec_procedure/4,          % exec_procedure(+Source, +ProcName, +Args, -Result)
    exec_program/3,            % exec_program(+Source, +Events, -Result)
    init_session/2,            % init_session(+Source, -Session)
    call_procedure/5           % call_procedure(+Session, +ProcName, +Args, -Result, -Session2)
]).

:- use_module(clarion_parser, [parse_clarion/2]).
:- use_module(ast_bridge, [bridge_ast/2]).
:- use_module(simulator, [run_ast/1, run_ast/2, exec_statements/4, exec_call/5]).
:- use_module(simulator_state).
:- use_module(simulator_eval).
:- use_module(simulator_builtins).

%------------------------------------------------------------
% Parse + Bridge
%------------------------------------------------------------

bridge(SimpleAST, ModularAST) :-
    bridge_ast(SimpleAST, ModularAST).

%------------------------------------------------------------
% Run source code
%------------------------------------------------------------

run_source(Source) :-
    parse_clarion(Source, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    run_ast(ModAST).

run_source(Source, FinalState) :-
    parse_clarion(Source, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    run_ast(ModAST, FinalState).

run_file(FileName) :-
    read_file_to_string(FileName, Source, []),
    format("Loading: ~w~n", [FileName]),
    run_source(Source).

%------------------------------------------------------------
% Execute a named procedure (stateless, one-shot)
%------------------------------------------------------------

exec_procedure(Source, ProcName, Args, Result) :-
    init_session(Source, Session), !,
    call_procedure(Session, ProcName, Args, Result, _), !.

%------------------------------------------------------------
% Stateful session for multi-call DLL simulation
%------------------------------------------------------------

init_session(Source, Session) :-
    parse_clarion(Source, SimpleAST), !,
    bridge_ast(SimpleAST, ModAST), !,
    ModAST = program(_, GlobalDecls, _, Procedures),
    empty_state(InitState),
    simulator:init_procedures(Procedures, InitState, State1),
    simulator:init_globals(GlobalDecls, State1, State2),
    Session = State2.

call_procedure(StateIn, ProcName, Args, Result, StateOut) :-
    maplist(wrap_arg, Args, ArgExprs),
    exec_call(ProcName, ArgExprs, StateIn, StateOut, Result), !.

wrap_arg(N, number(N)) :- number(N), !.
wrap_arg(S, string(S)) :- atom(S), !.
wrap_arg(X, X).  % already an expression

%------------------------------------------------------------
% Execute a PROGRAM with event simulation (for GUI testing)
%------------------------------------------------------------

exec_program(Source, Events, Result) :-
    parse_clarion(Source, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, code(MainBody), Procedures),
    empty_state(InitState),
    simulator:init_procedures(Procedures, InitState, State1),
    simulator:init_globals(GlobalDecls, State1, State2),
    % Store events for the accept loop to consume
    set_event_queue(Events, State2, State3),
    exec_statements(MainBody, State3, FinalState, _Control),
    % Extract Result variable if it exists
    ( get_var('Result', FinalState, Result) -> true ; Result = 0 ).

%------------------------------------------------------------
% Event queue management
%------------------------------------------------------------

set_event_queue(Events, StateIn, StateOut) :-
    StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
    ( is_dict(UI) ->
        put_dict(event_queue, UI, Events, NewUI)
    ;   NewUI = ui_state{
            backend: simulation,
            windows: [],
            event_queue: Events,
            current_event: none,
            mode: sync
        }
    ),
    StateOut = state(Vars, Procs, Out, Files, Err, Classes, Self, NewUI, Cont).
