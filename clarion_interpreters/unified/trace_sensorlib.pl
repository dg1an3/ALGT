% trace_sensorlib.pl — Run SensorLib through the unified interpreter
% with procedure-level trace output compatible with CDB comparison.
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_sensorlib.pl
%
% Output format matches compare_cdb_prolog.py expectations:
%   CALL ProcName(args) -> result

:- use_module(clarion).

main :-
    read_file_to_string('../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
    init_session(Src, S0),

    call_procedure(S0, 'SSOpen', [], R0, S1),
    format("CALL SSOpen() -> ~w~n", [R0]),

    call_procedure(S1, 'SSAddReading', [1, 100, 50], R1, S2),
    format("CALL SSAddReading(1, 100, 50) -> ~w~n", [R1]),

    call_procedure(S2, 'SSAddReading', [2, 200, 25], R2, S3),
    format("CALL SSAddReading(2, 200, 25) -> ~w~n", [R2]),

    call_procedure(S3, 'SSAddReading', [3, 300, 10], R3, S4),
    format("CALL SSAddReading(3, 300, 10) -> ~w~n", [R3]),

    call_procedure(S4, 'SSCalculateWeightedAverage', [], Avg1, S5),
    format("CALL SSCalculateWeightedAverage() -> ~w~n", [Avg1]),

    call_procedure(S5, 'SSCleanupLowReadings', [150], Removed, S6),
    format("CALL SSCleanupLowReadings(150) -> ~w~n", [Removed]),

    call_procedure(S6, 'SSCalculateWeightedAverage', [], Avg2, S7),
    format("CALL SSCalculateWeightedAverage() -> ~w~n", [Avg2]),

    call_procedure(S7, 'SSClose', [], R4, _),
    format("CALL SSClose() -> ~w~n", [R4]).
