% trace_fractal.pl — Run FractalLib through the unified simulator
% with procedure-level trace output compatible with CDB comparison.
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_fractal.pl
%
% Output format matches compare_cdb_prolog.py expectations:
%   CALL ProcName(args) -> result
%
% LIMITATION: The unified Clarion simulator uses Prolog's native
% arithmetic for REAL division and multiplication.  FractalLib relies
% on IEEE 754 floating-point via Clarion's REAL type, and the
% fixed-point encoding (multiply/divide by 10000) may produce
% rounding differences compared to the compiled DLL, especially
% for ROUND(expr, 1) in the logistic map.  Row procedures that
% use MemCopy/ADDRESS for buffer writes are not supported by the
% simulator and are therefore excluded from this trace.

:- use_module(clarion).

main :-
    read_file_to_string('../../clarion_projects/mandelbrot/FractalLib.clw', Src, []),
    init_session(Src, S0),

    % --- Mandelbrot single-point tests ---
    % (0, 0) -> in set, should return maxIter=100
    call_procedure(S0, 'FLMandelbrot', [0, 0, 100], R0, S1),
    format("CALL FLMandelbrot(0, 0, 100) -> ~w~n", [R0]),

    % (20000, 0) i.e. (2.0, 0) -> escapes at iteration 2
    call_procedure(S1, 'FLMandelbrot', [20000, 0, 100], R1, S2),
    format("CALL FLMandelbrot(20000, 0, 100) -> ~w~n", [R1]),

    % (10000, 0) i.e. (1.0, 0) -> escapes at iteration 3
    call_procedure(S2, 'FLMandelbrot', [10000, 0, 100], R2, S3),
    format("CALL FLMandelbrot(10000, 0, 100) -> ~w~n", [R2]),

    % (-10000, 0) i.e. (-1.0, 0) -> in set
    call_procedure(S3, 'FLMandelbrot', [-10000, 0, 100], R3, S4),
    format("CALL FLMandelbrot(-10000, 0, 100) -> ~w~n", [R3]),

    % (100000, 0) i.e. (10.0, 0) -> escapes at iteration 1
    call_procedure(S4, 'FLMandelbrot', [100000, 0, 100], R4, S5),
    format("CALL FLMandelbrot(100000, 0, 100) -> ~w~n", [R4]),

    % --- Julia single-point tests ---
    % z=(0,0), c=(-0.7, 0.27015) -> in set
    call_procedure(S5, 'FLJulia', [0, 0, -7000, 2702, 100], R5, S6),
    format("CALL FLJulia(0, 0, -7000, 2702, 100) -> ~w~n", [R5]),

    % z=(20000,0), c=(-0.7, 0.27015) -> escapes quickly
    call_procedure(S6, 'FLJulia', [20000, 0, -7000, 2702, 100], R6, S7),
    format("CALL FLJulia(20000, 0, -7000, 2702, 100) -> ~w~n", [R6]),

    % --- Logistic map tests ---
    % p=0.5, k=1.0 -> 0.75 -> 7500
    call_procedure(S7, 'FLLogistic', [5000, 10000], R7, S8),
    format("CALL FLLogistic(5000, 10000) -> ~w~n", [R7]),

    % p=0.1, k=2.0 -> 0.28 -> 2800
    call_procedure(S8, 'FLLogistic', [1000, 20000], R8, S9),
    format("CALL FLLogistic(1000, 20000) -> ~w~n", [R8]),

    % p=0.0, k=2.5 -> 0 (fixed point)
    call_procedure(S9, 'FLLogistic', [0, 25000], R9, _),
    format("CALL FLLogistic(0, 25000) -> ~w~n", [R9]).
