% trace_radar.pl — Run RadarLib through the unified simulator
% with procedure-level trace output compatible with CDB comparison.
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_radar.pl
%
% Output format matches compare_cdb_prolog.py expectations:
%   CALL ProcName(args) -> result

:- use_module(clarion).

main :-
    read_file_to_string('../../clarion_projects/radar-term/RadarLib.clw', Src, []),
    init_session(Src, S0),

    % Open files
    call_procedure(S0, 'RLOpen', [], R0, S1),
    format("CALL RLOpen() -> ~w~n", [R0]),

    % Add a station (number=1, name="TestStn", phone="5551234",
    %   commPort=2, baudRate=9600, autoInterval=60)
    call_procedure(S1, 'RLAddStation', [1, 0, 7, 0, 7, 2, 9600, 60], R1, S2),
    format("CALL RLAddStation(1, 0, 7, 0, 7, 2, 9600, 60) -> ~w~n", [R1]),

    % Get station count
    call_procedure(S2, 'RLGetStationCount', [], SC1, S3),
    format("CALL RLGetStationCount() -> ~w~n", [SC1]),

    % Select station 1
    call_procedure(S3, 'RLSelectStation', [1], RS1, S4),
    format("CALL RLSelectStation(1) -> ~w~n", [RS1]),

    % Set radar parameters: tilt=3, range=2 (100km), gain=10
    call_procedure(S4, 'RLSetParams', [3, 2, 10], RP1, S5),
    format("CALL RLSetParams(3, 2, 10) -> ~w~n", [RP1]),

    % Set mode to 1 (Interactive)
    call_procedure(S5, 'RLSetMode', [1], RM1, S6),
    format("CALL RLSetMode(1) -> ~w~n", [RM1]),

    % Get mode
    call_procedure(S6, 'RLGetMode', [], GM1, S7),
    format("CALL RLGetMode() -> ~w~n", [GM1]),

    % Add a picture (name="IMG001.BMP", year=2026, month=3, day=12,
    %   hour=14, minute=30, tilt=3, range=2, gain=10)
    call_procedure(S7, 'RLAddPicture', [0, 10, 2026, 3, 12, 14, 30, 3, 2, 10], AP1, S8),
    format("CALL RLAddPicture(0, 10, 2026, 3, 12, 14, 30, 3, 2, 10) -> ~w~n", [AP1]),

    % Get picture count
    call_procedure(S8, 'RLGetPictureCount', [], PC1, S9),
    format("CALL RLGetPictureCount() -> ~w~n", [PC1]),

    % Range conversion: code 2 -> 100 km
    call_procedure(S9, 'RLRangeToKm', [2], KM1, S10),
    format("CALL RLRangeToKm(2) -> ~w~n", [KM1]),

    % Range conversion: code 4 -> 400 km
    call_procedure(S10, 'RLRangeToKm', [4], KM2, S11),
    format("CALL RLRangeToKm(4) -> ~w~n", [KM2]),

    % Invalid range code -> -1
    call_procedure(S11, 'RLRangeToKm', [5], KM3, S12),
    format("CALL RLRangeToKm(5) -> ~w~n", [KM3]),

    % Delete picture 1
    call_procedure(S12, 'RLDeletePicture', [1], DP1, S13),
    format("CALL RLDeletePicture(1) -> ~w~n", [DP1]),

    % Picture count after delete
    call_procedure(S13, 'RLGetPictureCount', [], PC2, S14),
    format("CALL RLGetPictureCount() -> ~w~n", [PC2]),

    % Close files
    call_procedure(S14, 'RLClose', [], RC1, _),
    format("CALL RLClose() -> ~w~n", [RC1]).
