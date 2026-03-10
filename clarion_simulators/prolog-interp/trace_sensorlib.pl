% trace_sensorlib.pl — Run SensorLib with full execution tracing
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_sensorlib.pl
%
% Outputs a trace log comparable to trace_sensorlib.py output.

:- use_module(clarion).
:- set_prolog_flag(double_quotes, codes).

main :-
    read_file_to_codes('../../clarion_projects/sensor-data/SensorLib.clw', Codes, []),
    parse_clarion(Codes, AST),

    init_file_io,
    set_trace(on),
    clear_trace,

    exec_procedure(AST, 'SSOpen', [], R0),
    exec_procedure(AST, 'SSAddReading', [1, 100, 50], R1),
    exec_procedure(AST, 'SSAddReading', [2, 200, 25], R2),
    exec_procedure(AST, 'SSAddReading', [3, 300, 10], R3),
    exec_procedure(AST, 'SSCalculateWeightedAverage', [], Avg1),
    exec_procedure(AST, 'SSCleanupLowReadings', [150], Removed),
    exec_procedure(AST, 'SSCalculateWeightedAverage', [], Avg2),
    exec_procedure(AST, 'SSClose', [], R4),

    set_trace(off),

    % Print procedure-level summary (comparable to Python output)
    format("=== Procedure-level trace (comparable to Python) ===~n"),
    format("CALL SSOpen() -> ~w~n", [R0]),
    format("CALL SSAddReading(1, 100, 50) -> ~w~n", [R1]),
    format("CALL SSAddReading(2, 200, 25) -> ~w~n", [R2]),
    format("CALL SSAddReading(3, 300, 10) -> ~w~n", [R3]),
    format("CALL SSCalculateWeightedAverage() -> ~w~n", [Avg1]),
    format("CALL SSCleanupLowReadings(150) -> ~w~n", [Removed]),
    format("CALL SSCalculateWeightedAverage() -> ~w~n", [Avg2]),
    format("CALL SSClose() -> ~w~n", [R4]),

    % Print detailed statement-level trace
    format("~n=== Statement-level trace (interpreter only) ===~n"),
    print_trace.
