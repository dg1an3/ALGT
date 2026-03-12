% trace_automata.pl — Run AutomataLib through the unified simulator
% with procedure-level trace output compatible with CDB comparison.
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_automata.pl
%
% Output format matches compare_cdb_prolog.py expectations:
%   CALL ProcName(args) -> result
%
% LIMITATION: The unified Clarion simulator does not currently support
% DIM (array) declarations or array element access (Cells[i], Rules[i]).
% Until DIM support is added to the parser and execution engine, this
% trace file will NOT produce correct results. It is provided as a
% scaffold for future use once array support is implemented.
% See clarion_simulators/unified/CLAUDE.md for the current feature set.

:- use_module(clarion).

main :-
    read_file_to_string('../../clarion_projects/automata/AutomataLib.clw', Src, []),
    init_session(Src, S0),

    % Initialize the automaton
    call_procedure(S0, 'CAInit', [], R0, S1),
    format("CALL CAInit() -> ~w~n", [R0]),

    % Set up identity rule: rule[i] = min(i, 15)
    call_procedure(S1, 'CASetRule', [0, 0], R1, S2),
    format("CALL CASetRule(0, 0) -> ~w~n", [R1]),
    call_procedure(S2, 'CASetRule', [1, 1], R2, S3),
    format("CALL CASetRule(1, 1) -> ~w~n", [R2]),
    call_procedure(S3, 'CASetRule', [2, 2], R3, S4),
    format("CALL CASetRule(2, 2) -> ~w~n", [R3]),
    call_procedure(S4, 'CASetRule', [3, 3], R4, S5),
    format("CALL CASetRule(3, 3) -> ~w~n", [R4]),

    % Verify rules
    call_procedure(S5, 'CAGetRule', [1], R5, S6),
    format("CALL CAGetRule(1) -> ~w~n", [R5]),
    call_procedure(S6, 'CAGetRule', [3], R6, S7),
    format("CALL CAGetRule(3) -> ~w~n", [R6]),

    % Out-of-range rule access
    call_procedure(S7, 'CAGetRule', [50], R7, S8),
    format("CALL CAGetRule(50) -> ~w~n", [R7]),

    % Set a seed cell
    call_procedure(S8, 'CASetCell', [320, 1], R8, S9),
    format("CALL CASetCell(320, 1) -> ~w~n", [R8]),

    % Read back the cell
    call_procedure(S9, 'CAGetCell', [320], R9, S10),
    format("CALL CAGetCell(320) -> ~w~n", [R9]),

    % Out-of-range cell access
    call_procedure(S10, 'CAGetCell', [-1], R10, S11),
    format("CALL CAGetCell(-1) -> ~w~n", [R10]),

    % Step the automaton
    call_procedure(S11, 'CAStep', [], R11, S12),
    format("CALL CAStep() -> ~w~n", [R11]),

    % Check cells after step
    call_procedure(S12, 'CAGetCell', [319], R12, S13),
    format("CALL CAGetCell(319) -> ~w~n", [R12]),
    call_procedure(S13, 'CAGetCell', [320], R13, S14),
    format("CALL CAGetCell(320) -> ~w~n", [R13]),
    call_procedure(S14, 'CAGetCell', [321], R14, S15),
    format("CALL CAGetCell(321) -> ~w~n", [R14]),

    % Spatial entropy
    call_procedure(S15, 'CASpatialEntropy', [], R15, S16),
    format("CALL CASpatialEntropy() -> ~w~n", [R15]),

    % Cell count
    call_procedure(S16, 'CAGetCellCount', [0], R16, S17),
    format("CALL CAGetCellCount(0) -> ~w~n", [R16]),
    call_procedure(S17, 'CAGetCellCount', [1], R17, _),
    format("CALL CAGetCellCount(1) -> ~w~n", [R17]).
