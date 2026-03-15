%% llvm_simulator.pl -- Instruction dispatch and control flow for LLVM IR
%%
%% Core execution loop:
%%   exec_function/5  — execute a named function with arguments
%%   exec_block/4     — execute a basic block, return next action
%%   exec_instruction/3 — execute one instruction, thread state
%%
%% Control flow uses terminators: ret, br (conditional/unconditional), unreachable.
%% Phi nodes are resolved at block entry using PrevBlock in state.

:- module(llvm_simulator, [
    exec_function/5,
    exec_block/4
]).

:- use_module(llvm_state).
:- use_module(llvm_eval).
:- use_module(llvm_builtins).
:- use_module(library(assoc)).

% ============================================================
% Function execution
% ============================================================

%% exec_function(+FuncName, +Args, +StateIn, -StateOut, -Result)
%  Execute a named function. Args is a list of values.
exec_function(FuncName, Args, StateIn, StateOut, Result) :-
    (   get_function(FuncName, StateIn, function(RetType, Params, Blocks))
    ->  % Save caller's registers and clear for callee
        clear_registers(StateIn, CleanState),
        % Bind parameters to registers
        bind_params(Params, Args, CleanState, State1),
        % Get entry block (first block)
        Blocks = [block(EntryLabel, _, _) | _],
        % Build block lookup
        build_block_map(Blocks, BlockMap),
        % Save and reset PrevBlock for callee
        get_prev_block(StateIn, SavedPrevBlock),
        set_prev_block(none, State1, State2),
        % Execute starting from entry block
        exec_blocks(EntryLabel, BlockMap, State2, CalleeState, RetType, Result),
        % Restore caller's registers and prev block
        % (keep callee's memory/globals changes)
        restore_caller_state(StateIn, CalleeState, SavedPrevBlock, StateOut)
    ;   % Try builtin
        llvm_builtin(FuncName, Args, Result)
    ->  StateOut = StateIn
    ;   format(atom(Msg), "Unknown function: ~w", [FuncName]),
        set_error(error(Msg), StateIn, StateOut),
        type_default(void, Result)
    ).

%% restore_caller_state(+CallerState, +CalleeState, +PrevBlock, -RestoredState)
%  Restore caller's registers but keep callee's memory/global changes.
restore_caller_state(
    state(CallerRegs, _, _, _, _, _, _, _, _),
    state(_, Mem, Next, Gs, Fs, Out, Err, _, Tr),
    PrevBlock,
    state(CallerRegs, Mem, Next, Gs, Fs, Out, Err, PrevBlock, Tr)).

%% bind_params(+Params, +Args, +StateIn, -StateOut)
bind_params([], [], State, State).
bind_params([param(Type, Name)|Ps], [Val|Vs], StateIn, StateOut) :-
    set_register(Name, typed_value(Type, Val), StateIn, State1),
    bind_params(Ps, Vs, State1, StateOut).
bind_params([param(_Type)|_Ps], _, State, State).  % unnamed param (declare)

% ============================================================
% Block map construction
% ============================================================

build_block_map(Blocks, Map) :-
    empty_assoc(Empty),
    foldl(add_block, Blocks, Empty, Map).

add_block(block(Label, Instrs, Term), MapIn, MapOut) :-
    put_assoc(Label, MapIn, block(Instrs, Term), MapOut).

% ============================================================
% Block execution loop
% ============================================================

%% exec_blocks(+Label, +BlockMap, +StateIn, -StateOut, +RetType, -Result)
%  Execute blocks starting from Label until a ret terminator.
exec_blocks(Label, BlockMap, StateIn, StateOut, RetType, Result) :-
    get_assoc(Label, BlockMap, block(Instrs, Terminator)),
    % Resolve phi nodes for this block
    resolve_phis(Instrs, StateIn, State1, NonPhiInstrs),
    % Execute non-phi instructions
    exec_instructions(NonPhiInstrs, State1, State2),
    % Update PrevBlock
    set_prev_block(Label, State2, State3),
    % Dispatch terminator
    exec_terminator(Terminator, State3, StateOut, BlockMap, RetType, Result).

%% resolve_phis(+Instrs, +StateIn, -StateOut, -NonPhiInstrs)
%  Resolve phi instructions at block entry, return remaining instructions.
resolve_phis([Instr|Rest], StateIn, StateOut, NonPhis) :-
    (   Instr = phi(Result, Type, Entries)
    ->  get_prev_block(StateIn, PrevBlock),
        resolve_phi_value(Entries, PrevBlock, StateIn, Value),
        set_register(Result, typed_value(Type, Value), StateIn, State1),
        resolve_phis(Rest, State1, StateOut, NonPhis)
    ;   StateOut = StateIn,
        NonPhis = [Instr|Rest]
    ).
resolve_phis([], State, State, []).

resolve_phi_value([phi_entry(Operand, Label)|Rest], PrevBlock, State, Value) :-
    (   Label == PrevBlock
    ->  resolve_value(Operand, any, State, Value)
    ;   resolve_phi_value(Rest, PrevBlock, State, Value)
    ).

% ============================================================
% Instruction sequence execution
% ============================================================

exec_instructions([], State, State).
exec_instructions([Instr|Rest], StateIn, StateOut) :-
    exec_instruction(Instr, StateIn, State1),
    exec_instructions(Rest, State1, StateOut).

% ============================================================
% Instruction dispatch (one clause per instruction type)
% ============================================================

% Binary operations: add, sub, mul, fadd, fsub, fmul, fdiv, etc.
exec_instruction(instr(Op, Result, Type, [Op1, Op2]), StateIn, StateOut) :-
    resolve_value(Op1, Type, StateIn, V1),
    resolve_value(Op2, Type, StateIn, V2),
    eval_binary_op(Op, Type, V1, V2, Value),
    set_register(Result, typed_value(Type, Value), StateIn, StateOut).

% Unary fneg (floating-point negate)
exec_instruction(fneg(Result, Type, Op), StateIn, StateOut) :-
    resolve_value(Op, Type, StateIn, V),
    Value is -V,
    set_register(Result, typed_value(Type, Value), StateIn, StateOut).

% Integer comparison
exec_instruction(icmp(Result, Cond, Type, Op1, Op2), StateIn, StateOut) :-
    resolve_value(Op1, Type, StateIn, V1),
    resolve_value(Op2, Type, StateIn, V2),
    % For signed comparisons, sign-extend first
    ( member(Cond, [slt, sgt, sle, sge]) ->
        ( Type = i(Bits) ->
            sign_extend(Bits, V1, SV1),
            sign_extend(Bits, V2, SV2)
        ;
            SV1 = V1, SV2 = V2
        )
    ;
        SV1 = V1, SV2 = V2
    ),
    eval_icmp(Cond, SV1, SV2, Value),
    set_register(Result, typed_value(i(1), Value), StateIn, StateOut).

% Floating-point comparison
exec_instruction(fcmp(Result, Cond, Type, Op1, Op2), StateIn, StateOut) :-
    resolve_value(Op1, Type, StateIn, V1),
    resolve_value(Op2, Type, StateIn, V2),
    eval_fcmp(Cond, V1, V2, Value),
    set_register(Result, typed_value(i(1), Value), StateIn, StateOut).

% Select (ternary)
exec_instruction(select(Result, _CondType, Cond, Type, TrueVal, FalseVal), StateIn, StateOut) :-
    resolve_value(Cond, i(1), StateIn, CV),
    ( CV =:= 1 ->
        resolve_value(TrueVal, Type, StateIn, Value)
    ;
        resolve_value(FalseVal, Type, StateIn, Value)
    ),
    set_register(Result, typed_value(Type, Value), StateIn, StateOut).

% Cast / conversion
exec_instruction(cast(CastOp, Result, FromType, Val, ToType), StateIn, StateOut) :-
    resolve_value(Val, FromType, StateIn, V),
    eval_cast(CastOp, FromType, ToType, V, Value),
    set_register(Result, typed_value(ToType, Value), StateIn, StateOut).

% Alloca — allocate stack memory
exec_instruction(alloca(Result, Type), StateIn, StateOut) :-
    alloc_memory(Addr, StateIn, State1),
    % Store default value at the allocated address
    type_default(Type, Default),
    store_memory(Addr, typed_value(Type, Default), State1, State2),
    set_register(Result, typed_value(ptr, Addr), State2, StateOut).

exec_instruction(alloca(Result, Type, NumOp), StateIn, StateOut) :-
    resolve_value(NumOp, i(64), StateIn, N),
    % Allocate N slots
    alloc_n(N, Type, StateIn, Addr, State1),
    set_register(Result, typed_value(ptr, Addr), State1, StateOut).

% Load — read from memory
exec_instruction(load(Result, Type, _PtrType, Ptr), StateIn, StateOut) :-
    resolve_value(Ptr, ptr, StateIn, Addr),
    ( load_memory(Addr, StateIn, typed_value(_, Value)) ->
        true
    ;
        type_default(Type, Value)
    ),
    set_register(Result, typed_value(Type, Value), StateIn, StateOut).

% Store — write to memory (void instruction, no result)
exec_instruction(store(ValType, Val, _PtrType, Ptr), StateIn, StateOut) :-
    resolve_value(Val, ValType, StateIn, Value),
    resolve_value(Ptr, ptr, StateIn, Addr),
    store_memory(Addr, typed_value(ValType, Value), StateIn, StateOut).

% Call with result
exec_instruction(call(Result, RetType, Callee, Args), StateIn, StateOut) :-
    resolve_call_target(Callee, FuncName),
    resolve_call_args(Args, StateIn, ArgVals),
    exec_function(FuncName, ArgVals, StateIn, State1, Value),
    set_register(Result, typed_value(RetType, Value), State1, StateOut).

% Call void (no result)
exec_instruction(call_void(Callee, Args), StateIn, StateOut) :-
    resolve_call_target(Callee, FuncName),
    resolve_call_args(Args, StateIn, ArgVals),
    exec_function(FuncName, ArgVals, StateIn, StateOut, _).

% GEP (getelementptr) — compute pointer offset
exec_instruction(getelementptr(Result, _InBounds, BaseType, _PtrType, Ptr, Indices), StateIn, StateOut) :-
    resolve_value(Ptr, ptr, StateIn, BaseAddr),
    resolve_gep_indices(Indices, BaseType, StateIn, Offset),
    Addr is BaseAddr + Offset,
    set_register(Result, typed_value(ptr, Addr), StateIn, StateOut).

% Phi — should have been resolved already, but handle gracefully
exec_instruction(phi(Result, Type, Entries), StateIn, StateOut) :-
    get_prev_block(StateIn, PrevBlock),
    resolve_phi_value(Entries, PrevBlock, StateIn, Value),
    set_register(Result, typed_value(Type, Value), StateIn, StateOut).

% ============================================================
% Terminator dispatch
% ============================================================

%% exec_terminator(+Term, +StateIn, -StateOut, +BlockMap, +RetType, -Result)

% Return value
exec_terminator(ret(Type, ValOp), StateIn, StateIn, _BlockMap, _RetType, Result) :-
    resolve_value(ValOp, Type, StateIn, Result).

% Return void
exec_terminator(ret(void, void), State, State, _BlockMap, _RetType, void).

% Unconditional branch
exec_terminator(br(label(Target)), StateIn, StateOut, BlockMap, RetType, Result) :-
    exec_blocks(Target, BlockMap, StateIn, StateOut, RetType, Result).

% Conditional branch
exec_terminator(br(Cond, label(TrueLabel), label(FalseLabel)), StateIn, StateOut, BlockMap, RetType, Result) :-
    resolve_value(Cond, i(1), StateIn, CV),
    ( CV =:= 1 ->
        exec_blocks(TrueLabel, BlockMap, StateIn, StateOut, RetType, Result)
    ;
        exec_blocks(FalseLabel, BlockMap, StateIn, StateOut, RetType, Result)
    ).

% Unreachable
exec_terminator(unreachable, StateIn, StateOut, _BlockMap, _RetType, void) :-
    set_error(error("Reached unreachable instruction"), StateIn, StateOut).

% ============================================================
% Block execution (public interface for testing)
% ============================================================

%% exec_block(+Block, +StateIn, -StateOut, -Action)
%  Execute a single block. Action is the terminator for external dispatch.
exec_block(block(Instrs, Term), StateIn, StateOut, Term) :-
    exec_instructions(Instrs, StateIn, StateOut).

% ============================================================
% Helpers
% ============================================================

resolve_call_target(global(Name), Name) :- !.
resolve_call_target(local(Name), Name) :- !.
resolve_call_target(Name, Name).

resolve_call_args([], _State, []).
resolve_call_args([arg(Type, Operand)|Rest], State, [Val|Vals]) :-
    resolve_value(Operand, Type, State, Val),
    resolve_call_args(Rest, State, Vals).

%% alloc_n(+N, +Type, +StateIn, -FirstAddr, -StateOut)
%  Allocate N memory slots for array.
alloc_n(N, Type, StateIn, FirstAddr, StateOut) :-
    N > 0,
    alloc_memory(FirstAddr, StateIn, State1),
    type_default(Type, Default),
    store_memory(FirstAddr, typed_value(Type, Default), State1, State2),
    N1 is N - 1,
    alloc_rest(N1, Type, State2, StateOut).

alloc_rest(0, _Type, State, State).
alloc_rest(N, Type, StateIn, StateOut) :-
    N > 0,
    alloc_memory(_, StateIn, State1),
    type_default(Type, Default),
    store_memory(_, typed_value(Type, Default), State1, State2),
    N1 is N - 1,
    alloc_rest(N1, Type, State2, StateOut).

%% resolve_gep_indices(+Indices, +BaseType, +State, -ByteOffset)
%  Compute byte offset for getelementptr. Simplified for Phase 1.
resolve_gep_indices([], _Type, _State, 0).
resolve_gep_indices([index(IdxType, IdxOp)|Rest], BaseType, State, Offset) :-
    resolve_value(IdxOp, IdxType, State, Idx),
    type_size(BaseType, Size),
    resolve_gep_indices(Rest, BaseType, State, RestOffset),
    Offset is Idx * Size + RestOffset.

%% type_size(+Type, -Bytes)
%  Size of a type in bytes (for GEP offset calculation).
type_size(i(Bits), Size) :- Size is (Bits + 7) // 8.
type_size(float, 4).
type_size(double, 8).
type_size(ptr, 8).
type_size(pointer(_), 8).
type_size(array(N, T), Size) :- type_size(T, ElemSize), Size is N * ElemSize.
type_size(_, 8). % default
