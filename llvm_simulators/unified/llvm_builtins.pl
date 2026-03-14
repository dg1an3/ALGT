%% llvm_builtins.pl -- External function stubs for LLVM IR simulator
%%
%% Provides implementations for standard library functions and LLVM intrinsics
%% that would normally be linked from libc/libm at runtime.

:- module(llvm_builtins, [
    llvm_builtin/3
]).

% ============================================================
% Math library (libm)
% ============================================================

llvm_builtin(sqrt, [X], R) :- R is sqrt(X).
llvm_builtin(sin,  [X], R) :- R is sin(X).
llvm_builtin(cos,  [X], R) :- R is cos(X).
llvm_builtin(tan,  [X], R) :- R is tan(X).
llvm_builtin(asin, [X], R) :- R is asin(X).
llvm_builtin(acos, [X], R) :- R is acos(X).
llvm_builtin(atan, [X], R) :- R is atan(X).
llvm_builtin(atan2,[Y, X], R) :- R is atan2(Y, X).
llvm_builtin(exp,  [X], R) :- R is exp(X).
llvm_builtin(log,  [X], R) :- R is log(X).
llvm_builtin(log10,[X], R) :- R is log(X) / log(10).
llvm_builtin(log2, [X], R) :- R is log(X) / log(2).
llvm_builtin(pow,  [X, Y], R) :- R is X ** Y.
llvm_builtin(fabs, [X], R) :- R is abs(X).
llvm_builtin(ceil, [X], R) :- R is ceiling(X).
llvm_builtin(floor,[X], R) :- R is floor(X).
llvm_builtin(round,[X], R) :- R is round(X).
llvm_builtin(fmod, [X, Y], R) :-
    Div is truncate(X / Y),
    R is X - Div * Y.
llvm_builtin(fmin, [X, Y], R) :- R is min(X, Y).
llvm_builtin(fmax, [X, Y], R) :- R is max(X, Y).
llvm_builtin(copysign, [X, Y], R) :-
    ( Y >= 0 -> R is abs(X) ; R is -abs(X) ).

% ============================================================
% LLVM intrinsics (llvm.* functions)
% ============================================================

llvm_builtin('llvm.sqrt.f64', [X], R) :- R is sqrt(X).
llvm_builtin('llvm.sqrt.f32', [X], R) :- R is sqrt(X).
llvm_builtin('llvm.fabs.f64', [X], R) :- R is abs(X).
llvm_builtin('llvm.fabs.f32', [X], R) :- R is abs(X).
llvm_builtin('llvm.pow.f64',  [X, Y], R) :- R is X ** Y.
llvm_builtin('llvm.pow.f32',  [X, Y], R) :- R is X ** Y.
llvm_builtin('llvm.sin.f64',  [X], R) :- R is sin(X).
llvm_builtin('llvm.cos.f64',  [X], R) :- R is cos(X).
llvm_builtin('llvm.exp.f64',  [X], R) :- R is exp(X).
llvm_builtin('llvm.exp2.f64', [X], R) :- R is 2 ** X.
llvm_builtin('llvm.log.f64',  [X], R) :- R is log(X).
llvm_builtin('llvm.log2.f64', [X], R) :- R is log(X) / log(2).
llvm_builtin('llvm.log10.f64',[X], R) :- R is log(X) / log(10).
llvm_builtin('llvm.floor.f64',[X], R) :- R is floor(X).
llvm_builtin('llvm.ceil.f64', [X], R) :- R is ceiling(X).
llvm_builtin('llvm.round.f64',[X], R) :- R is round(X).
llvm_builtin('llvm.minnum.f64', [X, Y], R) :- R is min(X, Y).
llvm_builtin('llvm.maxnum.f64', [X, Y], R) :- R is max(X, Y).
llvm_builtin('llvm.copysign.f64', [X, Y], R) :-
    ( Y >= 0 -> R is abs(X) ; R is -abs(X) ).

% ============================================================
% C standard library stubs
% ============================================================

llvm_builtin(abs,  [X], R) :- R is abs(X).
llvm_builtin(labs, [X], R) :- R is abs(X).

% printf — stub that returns 0 (characters printed not tracked)
llvm_builtin(printf, _, 0).
llvm_builtin(puts, _, 0).
