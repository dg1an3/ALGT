% trace_formlib.pl — Prolog-side trace for FormLib variable comparison
%
% Mirrors the exact sequence from cdb_trace_target.py, computing the
% same formulas as FormDemo.clw's Calculate and Clear button logic.
%
% Outputs CALL lines in the same format as the CDB trace for comparison.
%
% Usage:
%   cd form-demo
%   swipl -g "main,halt" -t "halt(1)" trace_formlib.pl

:- set_prolog_flag(double_quotes, codes).
:- dynamic var/2.   % var(Name, Value)

main :-
    % --- FLInit ---
    fl_init,
    format("CALL FLInit() -> 0~n"),

    % --- FLSetField: SensorID=42, Reading=500, Weight=80, SensorType=2 ---
    fl_set_field(1, 42),  format("CALL FLSetField(1, 42) -> 0~n"),
    fl_set_field(2, 500), format("CALL FLSetField(2, 500) -> 0~n"),
    fl_set_field(3, 80),  format("CALL FLSetField(3, 80) -> 0~n"),
    fl_set_field(5, 2),   format("CALL FLSetField(5, 2) -> 0~n"),

    % --- FLCalcBtn: Result = ((Reading * Weight) / 100) * SensorType ---
    fl_calc_btn(CalcResult),
    format("CALL FLCalcBtn() -> ~w~n", [CalcResult]),

    % --- FLGetVar: query all variables after Calculate ---
    fl_get_var(1, V1), format("CALL FLGetVar(1) -> ~w~n", [V1]),
    fl_get_var(2, V2), format("CALL FLGetVar(2) -> ~w~n", [V2]),
    fl_get_var(3, V3), format("CALL FLGetVar(3) -> ~w~n", [V3]),
    fl_get_var(4, V4), format("CALL FLGetVar(4) -> ~w~n", [V4]),
    fl_get_var(5, V5), format("CALL FLGetVar(5) -> ~w~n", [V5]),

    % --- FLClearBtn ---
    fl_clear_btn,
    format("CALL FLClearBtn() -> 0~n"),

    % --- FLGetVar: query all variables after Clear ---
    fl_get_var(1, C1), format("CALL FLGetVar(1) -> ~w~n", [C1]),
    fl_get_var(2, C2), format("CALL FLGetVar(2) -> ~w~n", [C2]),
    fl_get_var(3, C3), format("CALL FLGetVar(3) -> ~w~n", [C3]),
    fl_get_var(4, C4), format("CALL FLGetVar(4) -> ~w~n", [C4]),
    fl_get_var(5, C5), format("CALL FLGetVar(5) -> ~w~n", [C5]).

%% Variable ID mapping: 1=SensorID, 2=Reading, 3=Weight, 4=Result, 5=SensorType
var_name(1, 'SensorID').
var_name(2, 'Reading').
var_name(3, 'Weight').
var_name(4, 'Result').
var_name(5, 'SensorType').

set_var(Name, Value) :-
    retractall(var(Name, _)),
    assert(var(Name, Value)).

get_var(Name, Value) :-
    ( var(Name, V) -> Value = V ; Value = 0 ).

%% FLInit: reset all variables to defaults
fl_init :-
    set_var('SensorID', 0),
    set_var('Reading', 0),
    set_var('Weight', 0),
    set_var('Result', 0),
    set_var('SensorType', 1).

%% FLSetField(Id, Val): set variable by ID
fl_set_field(Id, Val) :-
    var_name(Id, Name),
    set_var(Name, Val).

%% FLCalcBtn: Result = ((Reading * Weight) / 100) * SensorType
%% Uses truncating integer division (same as Clarion)
fl_calc_btn(Result) :-
    get_var('Reading', R),
    get_var('Weight', W),
    get_var('SensorType', ST),
    Result is ((R * W) // 100) * ST,
    set_var('Result', Result).

%% FLClearBtn: reset all to defaults
fl_clear_btn :- fl_init.

%% FLGetVar(Id, Value): get variable by ID
fl_get_var(Id, Value) :-
    var_name(Id, Name),
    get_var(Name, Value).
