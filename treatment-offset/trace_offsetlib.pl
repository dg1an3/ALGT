% trace_offsetlib.pl — Prolog-side trace for OffsetLib variable comparison
%
% Mirrors the exact sequence from cdb_trace_target.py, including
% sign-flip logic: negative values are negated and the paired
% direction is toggled (1->2 or 2->1).
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

    % --- OLSetField with sign-flip ---
    % APValue = -15: negates to 15, APDir flips 1->2 (Posterior)
    ol_set_field(1, -15), format("CALL OLSetField(1, -15) -> 0~n"),
    % SIValue = 20: positive, SIDir stays 1 (Superior)
    ol_set_field(3, 20),  format("CALL OLSetField(3, 20) -> 0~n"),
    % LRValue = -10: negates to 10, LRDir flips 1->2 (Right)
    ol_set_field(5, -10), format("CALL OLSetField(5, -10) -> 0~n"),

    % Date, time, source
    ol_set_field(8, 82252),   format("CALL OLSetField(8, 82252) -> 0~n"),
    ol_set_field(9, 4320000), format("CALL OLSetField(9, 4320000) -> 0~n"),
    ol_set_field(10, 2),      format("CALL OLSetField(10, 2) -> 0~n"),

    % --- OLCalcBtn ---
    ol_calc_btn(Mag),
    format("CALL OLCalcBtn() -> ~w~n", [Mag]),

    % --- OLGetVar: query all after Calculate ---
    ol_get_var(1, V1),  format("CALL OLGetVar(1) -> ~w~n", [V1]),
    ol_get_var(2, V2),  format("CALL OLGetVar(2) -> ~w~n", [V2]),
    ol_get_var(3, V3),  format("CALL OLGetVar(3) -> ~w~n", [V3]),
    ol_get_var(4, V4),  format("CALL OLGetVar(4) -> ~w~n", [V4]),
    ol_get_var(5, V5),  format("CALL OLGetVar(5) -> ~w~n", [V5]),
    ol_get_var(6, V6),  format("CALL OLGetVar(6) -> ~w~n", [V6]),
    ol_get_var(7, V7),  format("CALL OLGetVar(7) -> ~w~n", [V7]),
    ol_get_var(8, V8),  format("CALL OLGetVar(8) -> ~w~n", [V8]),
    ol_get_var(9, V9),  format("CALL OLGetVar(9) -> ~w~n", [V9]),
    ol_get_var(10, V10), format("CALL OLGetVar(10) -> ~w~n", [V10]),

    % --- OLClearBtn ---
    ol_clear_btn,
    format("CALL OLClearBtn() -> 0~n"),

    % --- OLGetVar: query after Clear ---
    ol_get_var(1, C1),  format("CALL OLGetVar(1) -> ~w~n", [C1]),
    ol_get_var(2, C2),  format("CALL OLGetVar(2) -> ~w~n", [C2]),
    ol_get_var(3, C3),  format("CALL OLGetVar(3) -> ~w~n", [C3]),
    ol_get_var(4, C4),  format("CALL OLGetVar(4) -> ~w~n", [C4]),
    ol_get_var(5, C5),  format("CALL OLGetVar(5) -> ~w~n", [C5]),
    ol_get_var(6, C6),  format("CALL OLGetVar(6) -> ~w~n", [C6]),
    ol_get_var(7, C7),  format("CALL OLGetVar(7) -> ~w~n", [C7]),
    ol_get_var(10, C10), format("CALL OLGetVar(10) -> ~w~n", [C10]).

%% Variable ID mapping
var_name(1, 'APValue').
var_name(2, 'APDir').
var_name(3, 'SIValue').
var_name(4, 'SIDir').
var_name(5, 'LRValue').
var_name(6, 'LRDir').
var_name(7, 'Magnitude').
var_name(8, 'OffsetDate').
var_name(9, 'OffsetTime').
var_name(10, 'DataSource').

%% Paired direction variable for each value variable
dir_pair(1, 2).   % APValue <-> APDir
dir_pair(3, 4).   % SIValue <-> SIDir
dir_pair(5, 6).   % LRValue <-> LRDir

set_var(Name, Value) :-
    retractall(var(Name, _)),
    assert(var(Name, Value)).

get_var(Name, Value) :-
    ( var(Name, V) -> Value = V ; Value = 0 ).

%% OLInit
ol_init :-
    set_var('APValue', 0),  set_var('APDir', 1),
    set_var('SIValue', 0),  set_var('SIDir', 1),
    set_var('LRValue', 0),  set_var('LRDir', 1),
    set_var('Magnitude', 0),
    set_var('OffsetDate', 0), set_var('OffsetTime', 0),
    set_var('DataSource', 1).

%% OLSetField with sign-flip for value fields
ol_set_field(Id, Val) :-
    var_name(Id, Name),
    ( dir_pair(Id, DirId) ->
        % This is a value field — check for negative
        ( Val < 0 ->
            AbsVal is 0 - Val,
            set_var(Name, AbsVal),
            % Flip direction: 1->2 or 2->1
            var_name(DirId, DirName),
            get_var(DirName, CurDir),
            ( CurDir =:= 1 -> NewDir = 2 ; NewDir = 1 ),
            set_var(DirName, NewDir)
        ;
            set_var(Name, Val)
        )
    ;
        % Direction or other field — set directly
        set_var(Name, Val)
    ).

%% OLCalcBtn: Magnitude = ISqrt(AP^2 + SI^2 + LR^2)
ol_calc_btn(Mag) :-
    get_var('APValue', A),
    get_var('SIValue', S),
    get_var('LRValue', L),
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
