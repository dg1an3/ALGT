%% llvm.pl -- Top-level API for LLVM IR simulator
%%
%% Mirrors the clarion.pl API pattern:
%%   run_source/1,2   — Parse + execute LLVM IR source
%%   run_file/1,2     — Parse + execute LLVM IR from .ll file
%%   init_session/2   — Create a stateful session from source
%%   call_function/5  — Execute a named function within a session
%%   exec_function/4  — Stateless one-shot function call

:- module(llvm, [
    run_source/1,
    run_source/2,
    run_file/1,
    run_file/2,
    init_session/2,
    init_session_from_file/2,
    call_function/5,
    exec_function/4
]).

:- use_module(llvm_parser).
:- use_module(llvm_state).
:- use_module(llvm_simulator).

%% run_source(+Source)
%  Parse and execute the main function in LLVM IR source string.
run_source(Source) :-
    run_source(Source, _Result).

%% run_source(+Source, -Result)
run_source(Source, Result) :-
    parse_llvm(Source, Module),
    empty_state(BaseState),
    init_state(Module, BaseState, State),
    exec_function(main, [], State, _, Result).

%% run_file(+FilePath)
%  Parse and execute from a .ll file.
run_file(FilePath) :-
    run_file(FilePath, _Result).

%% run_file(+FilePath, -Result)
run_file(FilePath, Result) :-
    parse_llvm_file(FilePath, Module),
    empty_state(BaseState),
    init_state(Module, BaseState, State),
    exec_function(main, [], State, _, Result).

%% init_session(+Source, -Session)
%  Create a session from LLVM IR source string.
%  Session is a state ready for call_function/5.
init_session(Source, Session) :-
    parse_llvm(Source, Module),
    empty_state(BaseState),
    init_state(Module, BaseState, Session).

%% init_session_from_file(+FilePath, -Session)
%  Create a session from a .ll file.
init_session_from_file(FilePath, Session) :-
    parse_llvm_file(FilePath, Module),
    empty_state(BaseState),
    init_state(Module, BaseState, Session).

%% call_function(+Session, +FuncName, +Args, -Result, -Session2)
%  Execute a named function within a session, threading state.
call_function(Session, FuncName, Args, Result, Session2) :-
    % Clear registers from previous call but keep globals/memory/functions
    clear_registers(Session, CleanSession),
    exec_function(FuncName, Args, CleanSession, Session2, Result).

%% exec_function(+Source, +FuncName, +Args, -Result)
%  Stateless one-shot: parse, init, call, return result.
exec_function(Source, FuncName, Args, Result) :-
    init_session(Source, Session),
    call_function(Session, FuncName, Args, Result, _).
