%% trace_vecmat.pl -- Trace comparison script for VecMat MathUtil functions
%%
%% Outputs CALL FuncName(args) -> result lines for comparison against
%% compiled C++ execution.
%%
%% Usage:
%%   cd llvm_simulators/unified
%%   swipl -g "main,halt" traces/trace_vecmat.pl
%%
%% Compare with C++ side:
%%   diff <(swipl -g "main,halt" traces/trace_vecmat.pl) \
%%        <(./mathutil_test)

:- use_module('../llvm').

trace_call(Session, FuncName, Args, Session2) :-
    call_function(Session, FuncName, Args, Result, Session2),
    format_args(Args, ArgsStr),
    format("CALL ~w(~w) -> ~w~n", [FuncName, ArgsStr, Result]).

format_args([], "").
format_args([X], S) :- format(atom(S), "~w", [X]).
format_args([X|Rest], S) :-
    Rest \= [],
    format_args(Rest, RestStr),
    format(atom(S), "~w, ~w", [X, RestStr]).

main :-
    init_session_from_file('samples/mathutil.ll', S),

    % IsApproxEqual
    trace_call(S, 'IsApproxEqual_double', [1.0, 1.000001, 1e-5], _),
    trace_call(S, 'IsApproxEqual_double', [1.0, 2.0, 1e-5], _),
    trace_call(S, 'IsApproxEqual_double', [3.14, 3.14, 1e-5], _),

    % Gauss
    trace_call(S, 'Gauss_double', [0.0, 1.0], _),
    trace_call(S, 'Gauss_double', [1.0, 1.0], _),
    trace_call(S, 'Gauss_double', [-1.0, 1.0], _),
    trace_call(S, 'Gauss_double', [0.0, 0.5], _),

    % Gauss2D
    trace_call(S, 'Gauss2D_double', [0.0, 0.0, 1.0, 1.0], _),
    trace_call(S, 'Gauss2D_double', [1.0, 1.0, 1.0, 1.0], _),
    trace_call(S, 'Gauss2D_double', [0.0, 0.0, 2.0, 3.0], _),

    % dGauss2D_dx
    trace_call(S, 'dGauss2D_dx_double', [0.0, 0.0, 1.0, 1.0], _),
    trace_call(S, 'dGauss2D_dx_double', [1.0, 0.0, 1.0, 1.0], _),

    % dGauss2D_dy
    trace_call(S, 'dGauss2D_dy_double', [0.0, 0.0, 1.0, 1.0], _),
    trace_call(S, 'dGauss2D_dy_double', [0.0, 1.0, 1.0, 1.0], _),

    % AngleFromSinCos — test all quadrants
    trace_call(S, 'AngleFromSinCos_double', [0.0, 1.0], _),    % 0
    trace_call(S, 'AngleFromSinCos_double', [1.0, 0.0], _),    % PI/2
    trace_call(S, 'AngleFromSinCos_double', [0.0, -1.0], _),   % PI
    trace_call(S, 'AngleFromSinCos_double', [-1.0, 0.0], _).   % 3*PI/2
