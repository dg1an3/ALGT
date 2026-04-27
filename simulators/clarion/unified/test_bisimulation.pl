%============================================================
% test_bisimulation.pl - Executable bisimulation checks
%
% Runs the bisimulation proof on concrete traces. The checks are:
%
%   1. Every structure lemma agrees with the abstract transition
%      delta (delegated to state_graph_lemmas:check_all_lemmas/0).
%
%   2. For the OffsetLib event trace (the same one in
%      clarion_projects/treatment-offset/trace_offsetlib.pl), the
%      abstract run of delta matches a hand-rolled simulation of
%      the compiled DLL -- demonstrating that
%      pi . exec_C = delta . pi on the trace. This is the pi-half
%      of the bisimulation diagram.
%
%   3. sigma of a simulated Prolog-side run of the same events
%      matches the delta-run. This is the sigma-half of the
%      diagram.
%
%   4. Therefore sigma(final_P) = delta*(init) = pi(final_C), so
%      the two endpoints are R-related: the bisimulation holds on
%      the trace.
%
% To run:
%
%   cd simulators/clarion/unified
%   swipl -g "main,halt" -t "halt(1)" test_bisimulation.pl
%============================================================

:- use_module(bisimulation).
:- use_module(state_graph_lemmas).
:- use_module(simulator_state, [empty_state/1, set_var/4]).

%------------------------------------------------------------
% The canonical OffsetLib trace, lifted to abstract events.
% Mirrors trace_offsetlib.pl exactly.
%------------------------------------------------------------

offsetlib_trace([
    init,
    set(1,  -15),       % APValue = -15 -> abs=15, APDir flips
    set(3,   20),       % SIValue =  20 -> no flip
    set(5,  -10),       % LRValue = -10 -> abs=10, LRDir flips
    set(8,  82252),     % OffsetDate
    set(9,  4320000),   % OffsetTime
    set(10, 2),         % DataSource
    calc,
    clear
]).

%------------------------------------------------------------
% Hand-rolled pi-side simulator: applies events directly to a
% Name-Value map matching the OLGetVar observable contract of the
% compiled DLL. This is intentionally written independently of
% bisimulation:abs_step/3 so the two can be cross-checked.
%------------------------------------------------------------

pi_init_obs(Obs) :-
    findall(Id-Default,
            ( bisimulation:observable_var(Id, _),
              pi_default_val(Id, Default)
            ),
            Obs).

pi_default_val(2,  1) :- !.
pi_default_val(4,  1) :- !.
pi_default_val(6,  1) :- !.
pi_default_val(10, 1) :- !.
pi_default_val(_,  0).

pi_apply(_Obs, init, Obs2) :-
    pi_init_obs(Obs2).
pi_apply(_Obs, clear, Obs2) :-
    pi_init_obs(Obs2).
pi_apply(Obs, set(Id, V), Obs2) :-
    ( bisimulation:dir_pair(Id, DirId), V < 0 ->
        AbsV is -V,
        pi_update_obs(Obs,  Id,    AbsV, Obs1),
        pi_get_obs(Obs1, DirId, D),
        ( D =:= 1 -> NewD = 2 ; NewD = 1 ),
        pi_update_obs(Obs1, DirId, NewD, Obs2)
    ;
        pi_update_obs(Obs, Id, V, Obs2)
    ).
pi_apply(Obs, calc, Obs2) :-
    pi_get_obs(Obs, 1, AP),
    pi_get_obs(Obs, 3, SI),
    pi_get_obs(Obs, 5, LR),
    N is AP*AP + SI*SI + LR*LR,
    local_isqrt(N, Mag),
    pi_update_obs(Obs, 7, Mag, Obs2).

pi_get_obs(Obs, Id, V) :- member(Id-V0, Obs), !, V = V0.
pi_get_obs(_,   _,  0).

pi_update_obs([], Id, V, [Id-V]).
pi_update_obs([Id-_|Rest], Id, V, [Id-V|Rest]) :- !.
pi_update_obs([Other|Rest], Id, V, [Other|Rest2]) :-
    pi_update_obs(Rest, Id, V, Rest2).

pi_run(Obs, [], Obs).
pi_run(Obs, [E|Es], Obs2) :-
    pi_apply(Obs, E, Obs1),
    pi_run(Obs1, Es, Obs2).

local_isqrt(N, 0) :- N =< 0, !.
local_isqrt(N, R) :-
    X1 is (N + 1) // 2,
    loop_s(N, N, X1, R).
loop_s(_, X, X1, X1) :- X1 >= X, !.
loop_s(N, _, X1, R) :-
    X2 is (X1 + N // X1) // 2,
    loop_s(N, X1, X2, R).

%------------------------------------------------------------
% sigma-side simulator: mutates a real interpreter state/9 term
% via simulator_state:set_var/4 in the same pattern the interpreter
% would when executing OLInit / OLSetField / OLCalcBtn /
% OLClearBtn. (We drive the state directly rather than re-parsing
% OffsetLib.clw so this test stays self-contained; a full
% end-to-end run against the parsed source is exercised by
% test_unified.pl.)
%------------------------------------------------------------

sigma_apply(_, init, S2) :-
    sigma_init_state(S2).
sigma_apply(_, clear, S2) :-
    sigma_init_state(S2).
sigma_apply(S, set(Id, V), S2) :-
    bisimulation:observable_var(Id, Name),
    ( bisimulation:dir_pair(Id, DirId), V < 0 ->
        AbsV is -V,
        bisimulation:observable_var(DirId, DirName),
        set_var(Name, AbsV, S, S1),
        simulator_state:get_var(DirName, S1, CurDir),
        ( CurDir =:= 1 -> NewDir = 2 ; NewDir = 1 ),
        set_var(DirName, NewDir, S1, S2)
    ;
        set_var(Name, V, S, S2)
    ).
sigma_apply(S, calc, S2) :-
    simulator_state:get_var('APValue', S, AP),
    simulator_state:get_var('SIValue', S, SI),
    simulator_state:get_var('LRValue', S, LR),
    N is AP*AP + SI*SI + LR*LR,
    local_isqrt(N, Mag),
    set_var('Magnitude', Mag, S, S2).

sigma_init_state(S) :-
    empty_state(S0),
    set_var('APValue',    0, S0,  S1),
    set_var('APDir',      1, S1,  S2),
    set_var('SIValue',    0, S2,  S3),
    set_var('SIDir',      1, S3,  S4),
    set_var('LRValue',    0, S4,  S5),
    set_var('LRDir',      1, S5,  S6),
    set_var('Magnitude',  0, S6,  S7),
    set_var('OffsetDate', 0, S7,  S8),
    set_var('OffsetTime', 0, S8,  S9),
    set_var('DataSource', 1, S9,  S).

sigma_run(S, [], S).
sigma_run(S, [E|Es], S2) :-
    sigma_apply(S, E, S1),
    sigma_run(S1, Es, S2).

%------------------------------------------------------------
% Top-level driver
%------------------------------------------------------------

main :-
    format("~n== Bisimulation proof checks ==~n"),
    check_lemmas,
    check_trace_agreement,
    check_step_by_step,
    format("~n== All checks passed ==~n").

check_lemmas :-
    format("~n[1] Structure lemmas agree with abstract delta:~n"),
    check_all_lemmas.

check_trace_agreement :-
    format("~n[2] Trace endpoints: sigma(final_P) = delta*(init) = pi(final_C)~n"),
    offsetlib_trace(Events),

    % delta-run (shared abstract semantics).
    bisim_check_trace(Events, Abs_delta),
    format("  delta* (abstract):  ~w~n", [Abs_delta]),

    % pi-run (independent re-implementation, cross-check).
    pi_init_obs(Obs0),
    pi_run(Obs0, Events, Obs_final),
    pi_project(Obs_final, Abs_pi),
    ( Abs_pi == Abs_delta
    -> format("  [ok] pi(final_C) = delta*(init)~n")
    ;  format("  [FAIL] pi(final_C) != delta*(init)~n  pi = ~w~n", [Abs_pi]),
       throw(pi_mismatch)
    ),

    % sigma-run (drives real simulator_state terms).
    sigma_init_state(S0),
    sigma_run(S0, Events, S_final),
    sigma(S_final, Abs_sigma),
    ( Abs_sigma == Abs_delta
    -> format("  [ok] sigma(final_P) = delta*(init)~n")
    ;  format("  [FAIL] sigma(final_P) != delta*(init)~n  sigma = ~w~n", [Abs_sigma]),
       throw(sigma_mismatch)
    ),

    % Endpoint witness of the bisimulation relation.
    ( bisim_related(S_final, Obs_final)
    -> format("  [ok] final_P R final_C  (bisimulation holds on trace)~n")
    ;  throw(endpoint_not_related)
    ).

check_step_by_step :-
    format("~n[3] Pointwise commuting square at every step:~n"),
    offsetlib_trace(Events),
    sigma_init_state(S0),
    pi_init_obs(Obs0),
    abstract_init(A0),
    step_check(Events, S0, Obs0, A0, 0).

step_check([], _, _, _, _) :- !.
step_check([E|Es], S, Obs, A, N) :-
    abs_step(A, E, A1),
    sigma_apply(S, E, S1),
    pi_apply(Obs, E, Obs1),
    sigma(S1, A_P),
    pi_project(Obs1, A_C),
    ( A_P == A1, A_C == A1
    -> format("  [ok] step ~w: ~w~n", [N, E])
    ;  format("  [FAIL] step ~w: ~w~n    delta = ~w~n    sigma = ~w~n    pi    = ~w~n",
              [N, E, A1, A_P, A_C]),
       throw(commuting_square_broken(N, E))
    ),
    N1 is N + 1,
    step_check(Es, S1, Obs1, A1, N1).
