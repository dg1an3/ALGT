% trace_offsetlib.pl — Prolog-side trace for OffsetLib variable comparison
%
% Mirrors the exact sequence from cdb_trace_target.py:
%   OLInit, OLSetField x6, OLCalcBtn, OLGetVar x7, OLClearBtn, OLGetVar x5
%
% Uses integer sqrt (Newton's method) matching Clarion's ISqrt.
%
% Usage:
%   cd treatment-offset
%   swipl -g "main,halt" -t "halt(1)" trace_offsetlib.pl

:- set_prolog_flag(double_quotes, codes).
:- dynamic var/2.

main :-
    % --- OLInit ---
    ol_init,
    format("CALL OLInit() -> 0~n"),

    % --- OLSetField: Anterior=15, Superior=20, Lateral=10 ---
    ol_set_field(1, 15),    format("CALL OLSetField(1, 15) -> 0~n"),
    ol_set_field(2, 20),    format("CALL OLSetField(2, 20) -> 0~n"),
    ol_set_field(3, 10),    format("CALL OLSetField(3, 10) -> 0~n"),

    % --- Date=82252, Time=4320000, Source=2 ---
    ol_set_field(5, 82252),   format("CALL OLSetField(5, 82252) -> 0~n"),
    ol_set_field(6, 4320000), format("CALL OLSetField(6, 4320000) -> 0~n"),
    ol_set_field(7, 2),       format("CALL OLSetField(7, 2) -> 0~n"),

    % --- OLCalcBtn: Magnitude = ISqrt(15^2 + 20^2 + 10^2) = ISqrt(725) ---
    ol_calc_btn(Mag),
    format("CALL OLCalcBtn() -> ~w~n", [Mag]),

    % --- OLGetVar: query all after Calculate ---
    ol_get_var(1, V1), format("CALL OLGetVar(1) -> ~w~n", [V1]),
    ol_get_var(2, V2), format("CALL OLGetVar(2) -> ~w~n", [V2]),
    ol_get_var(3, V3), format("CALL OLGetVar(3) -> ~w~n", [V3]),
    ol_get_var(4, V4), format("CALL OLGetVar(4) -> ~w~n", [V4]),
    ol_get_var(5, V5), format("CALL OLGetVar(5) -> ~w~n", [V5]),
    ol_get_var(6, V6), format("CALL OLGetVar(6) -> ~w~n", [V6]),
    ol_get_var(7, V7), format("CALL OLGetVar(7) -> ~w~n", [V7]),

    % --- OLClearBtn ---
    ol_clear_btn,
    format("CALL OLClearBtn() -> 0~n"),

    % --- OLGetVar: query after Clear ---
    ol_get_var(1, C1), format("CALL OLGetVar(1) -> ~w~n", [C1]),
    ol_get_var(2, C2), format("CALL OLGetVar(2) -> ~w~n", [C2]),
    ol_get_var(3, C3), format("CALL OLGetVar(3) -> ~w~n", [C3]),
    ol_get_var(4, C4), format("CALL OLGetVar(4) -> ~w~n", [C4]),
    ol_get_var(7, C7), format("CALL OLGetVar(7) -> ~w~n", [C7]).

%% Variable ID mapping
var_name(1, 'Anterior').
var_name(2, 'Superior').
var_name(3, 'Lateral').
var_name(4, 'Magnitude').
var_name(5, 'OffsetDate').
var_name(6, 'OffsetTime').
var_name(7, 'DataSource').

set_var(Name, Value) :-
    retractall(var(Name, _)),
    assert(var(Name, Value)).

get_var(Name, Value) :-
    ( var(Name, V) -> Value = V ; Value = 0 ).

%% OLInit
ol_init :-
    set_var('Anterior', 0),
    set_var('Superior', 0),
    set_var('Lateral', 0),
    set_var('Magnitude', 0),
    set_var('OffsetDate', 0),
    set_var('OffsetTime', 0),
    set_var('DataSource', 1).

%% OLSetField
ol_set_field(Id, Val) :-
    var_name(Id, Name),
    set_var(Name, Val).

%% OLCalcBtn: Magnitude = ISqrt(Ant^2 + Sup^2 + Lat^2)
ol_calc_btn(Mag) :-
    get_var('Anterior', A),
    get_var('Superior', S),
    get_var('Lateral', L),
    N is A*A + S*S + L*L,
    isqrt(N, Mag),
    set_var('Magnitude', Mag).

%% OLClearBtn
ol_clear_btn :- ol_init.

%% OLGetVar
ol_get_var(Id, Value) :-
    var_name(Id, Name),
    get_var(Name, Value).

%% Integer square root via Newton's method (matches Clarion ISqrt)
isqrt(N, 0) :- N =< 0, !.
isqrt(N, Result) :-
    X0 is N,
    X1 is (X0 + 1) // 2,
    isqrt_loop(N, X0, X1, Result).

isqrt_loop(_N, X, X1, X1) :- X1 >= X, !.
isqrt_loop(N, _X, X1, Result) :-
    X2 is (X1 + N // X1) // 2,
    isqrt_loop(N, X1, X2, Result).
