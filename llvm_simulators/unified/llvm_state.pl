%% llvm_state.pl -- State management for LLVM IR simulator
%%
%% State tuple (mirroring Clarion simulator's 9-tuple pattern):
%%   state(Registers, Memory, NextAddr, Globals, Functions, Output, Error, PrevBlock, TraceOn)
%%
%% Registers: assoc mapping register name -> typed_value(Type, Value)
%% Memory:    assoc mapping integer address -> typed_value(Type, Value)
%% NextAddr:  next free address (integer counter)
%% Globals:   assoc mapping global name -> address or constant
%% Functions: assoc mapping function name -> function definition
%% Output:    list of output strings (reversed)
%% Error:     none | error(Message)
%% PrevBlock: atom - label of the previously executed basic block (for phi)
%% TraceOn:   true | false

:- module(llvm_state, [
    empty_state/1,
    init_state/3,
    get_register/3,
    set_register/4,
    alloc_memory/3,
    load_memory/3,
    store_memory/4,
    get_global/3,
    set_global/4,
    get_function/3,
    set_function/4,
    get_prev_block/2,
    set_prev_block/3,
    get_output/2,
    append_output/3,
    get_error/2,
    set_error/3,
    get_trace_on/2,
    set_trace_on/3,
    clear_registers/2
]).

:- use_module(library(assoc)).

%% empty_state(-State)
empty_state(state(Regs, Mem, 1000, Globals, Funcs, [], none, none, false)) :-
    empty_assoc(Regs),
    empty_assoc(Mem),
    empty_assoc(Globals),
    empty_assoc(Funcs).

%% init_state(+Module, +BaseState, -InitState)
%  Initialize state from a parsed LLVM module — register functions and globals.
init_state(module(Globals, _Declares, Defines), BaseState, State) :-
    foldl(register_function, Defines, BaseState, State1),
    foldl(register_global, Globals, State1, State).

register_function(define(RetType, Name, Params, Blocks), StateIn, StateOut) :-
    set_function(Name, function(RetType, Params, Blocks), StateIn, StateOut).

register_global(global(Name, Type, Value), StateIn, StateOut) :-
    % Allocate memory for the global and store its initial value
    alloc_memory(Addr, StateIn, State1),
    store_memory(Addr, typed_value(Type, Value), State1, State2),
    set_global(Name, Addr, State2, StateOut).

% ============================================================
% Register accessors
% ============================================================

get_register(Name, state(Regs,_,_,_,_,_,_,_,_), Value) :-
    get_assoc(Name, Regs, Value).

set_register(Name, Value,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs1, Mem, Next, Gs, Fs, Out, Err, Prev, Tr)) :-
    put_assoc(Name, Regs, Value, Regs1).

clear_registers(
    state(_, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr)) :-
    empty_assoc(Regs).

% ============================================================
% Memory accessors
% ============================================================

alloc_memory(Addr,
    state(Regs, Mem, Addr, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr)) :-
    Next is Addr + 8.  % 8-byte aligned

load_memory(Addr, state(_, Mem, _, _, _, _, _, _, _), Value) :-
    get_assoc(Addr, Mem, Value).

store_memory(Addr, Value,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem1, Next, Gs, Fs, Out, Err, Prev, Tr)) :-
    put_assoc(Addr, Mem, Value, Mem1).

% ============================================================
% Global accessors
% ============================================================

get_global(Name, state(_,_,_,Gs,_,_,_,_,_), Value) :-
    get_assoc(Name, Gs, Value).

set_global(Name, Value,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem, Next, Gs1, Fs, Out, Err, Prev, Tr)) :-
    put_assoc(Name, Gs, Value, Gs1).

% ============================================================
% Function accessors
% ============================================================

get_function(Name, state(_,_,_,_,Fs,_,_,_,_), Value) :-
    get_assoc(Name, Fs, Value).

set_function(Name, Value,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem, Next, Gs, Fs1, Out, Err, Prev, Tr)) :-
    put_assoc(Name, Fs, Value, Fs1).

% ============================================================
% Control flow
% ============================================================

get_prev_block(state(_,_,_,_,_,_,_,Prev,_), Prev).

set_prev_block(Label,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, _, Tr),
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Label, Tr)).

% ============================================================
% Output
% ============================================================

get_output(state(_,_,_,_,_,Out,_,_,_), Out).

append_output(Str,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr),
    state(Regs, Mem, Next, Gs, Fs, [Str|Out], Err, Prev, Tr)).

% ============================================================
% Error
% ============================================================

get_error(state(_,_,_,_,_,_,Err,_,_), Err).

set_error(Err,
    state(Regs, Mem, Next, Gs, Fs, Out, _, Prev, Tr),
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr)).

% ============================================================
% Trace flag
% ============================================================

get_trace_on(state(_,_,_,_,_,_,_,_,Tr), Tr).

set_trace_on(Tr,
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, _),
    state(Regs, Mem, Next, Gs, Fs, Out, Err, Prev, Tr)).
