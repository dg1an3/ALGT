%============================================================
% bisimulation.pl - Bisimulation Proof Framework
%
% Establishes a bisimulation between:
%
%   P = the Prolog interpreter (state/9 term in simulator_state.pl)
%   C = the compiled Clarion DLL (observed via CDB traces and
%       GetVar-style exports -- see clarion_projects/treatment-offset/
%       cdb_trace_target.py)
%
% A bisimulation R, a subset of S_P x S_C, is a relation such that
% whenever s_p R s_c:
%
%   (forward)  s_p --e--> s_p'   =>   exists s_c'. s_c --e--> s_c'
%                                     and s_p' R s_c'
%   (backward) s_c --e--> s_c'   =>   exists s_p'. s_p --e--> s_p'
%                                     and s_p' R s_c'
%
% We build R = {(s_p, s_c) | sigma(s_p) = pi(s_c)} where sigma
% projects the Prolog state onto the abstract observable tuple and
% pi projects the compiled DLL state onto the same tuple. When
% both projections land in the same abstract-state domain A,
% showing that both transition systems commute with their
% projections -- i.e. there is a shared event function
%
%       delta : A x Event -> A
%
% such that
%
%       sigma(exec_P(s_p, e)) = delta(sigma(s_p), e)
%       pi(exec_C(s_c, e))    = delta(pi(s_c),    e)
%
% gives the bisimulation R immediately.
%
% This module defines sigma, pi, the abstract event transition
% delta, and the statement of the bisimulation. The per-event
% structure lemmas justifying delta live in state_graph_lemmas.pl;
% a concrete instance of the proof (run on the OffsetLib trace)
% lives in test_bisimulation.pl.
%============================================================

:- module(bisimulation, [
    % Abstract state (shared projection codomain)
    abstract_init/1,                % abstract_init(-A)

    % Projections
    sigma/2,                        % sigma(+PrologState, -A)
    pi_project/2,                   % pi_project(+DLLObservation, -A)

    % Abstract transition system (delta)
    abs_step/3,                     % abs_step(+A, +Event, -A2)
    abs_run/3,                      % abs_run(+A, +Events, -A2)

    % Bisimulation witness
    bisim_related/2,                % bisim_related(+PrologState, +DLLObservation)
    bisim_step_forward/4,           % bisim_step_forward(+S_P, +S_C, +Event, -Expected)
    bisim_check_trace/2,            % bisim_check_trace(+Events, -Witness)

    % Observable variable schema (OffsetLib instance)
    observable_var/2,               % observable_var(+Id, -Name)
    dir_pair/2                      % dir_pair(+ValueId, -DirId)
]).

:- use_module(simulator_state, [get_var/3]).

%------------------------------------------------------------
% Observable schema (OffsetLib)
%
% This is the alphabet of the abstract state: the ten variables
% exported by OLGetVar in the compiled DLL. Any other interpreter
% variable is internal and is deliberately NOT in the image of
% sigma.
%
% A value variable and its paired direction variable are treated
% together (sign-flip invariant -- see state_graph_lemmas.pl).
%------------------------------------------------------------

observable_var(1,  'APValue').
observable_var(2,  'APDir').
observable_var(3,  'SIValue').
observable_var(4,  'SIDir').
observable_var(5,  'LRValue').
observable_var(6,  'LRDir').
observable_var(7,  'Magnitude').
observable_var(8,  'OffsetDate').
observable_var(9,  'OffsetTime').
observable_var(10, 'DataSource').

dir_pair(1, 2).
dir_pair(3, 4).
dir_pair(5, 6).

%------------------------------------------------------------
% Abstract state
%
% A concrete record of the ten observable variables. This is the
% codomain of both sigma and pi, so the bisimulation reduces to
% ordinary equality of abstract states.
%------------------------------------------------------------

abstract_init(abs{
    'APValue':    0, 'APDir':     1,
    'SIValue':    0, 'SIDir':     1,
    'LRValue':    0, 'LRDir':     1,
    'Magnitude':  0,
    'OffsetDate': 0, 'OffsetTime': 0,
    'DataSource': 1
}).

%------------------------------------------------------------
% sigma : S_P -> A
%
% Reads each observable variable out of the interpreter's state
% (via simulator_state:get_var/3). A variable that has never been
% assigned defaults to 0, matching the interpreter's zero-init.
%------------------------------------------------------------

sigma(PrologState, Abs) :-
    findall(Name-Value,
            ( observable_var(_Id, Name),
              ( get_var(Name, PrologState, Value0) -> Value = Value0
              ; Value = 0
              )
            ),
            Pairs),
    dict_pairs(Abs, abs, Pairs).

%------------------------------------------------------------
% pi : S_C -> A
%
% The compiled DLL is observed by calling OLGetVar(Id) for each Id
% in the schema. An observation is a list of Id-Value pairs; pi
% simply tabulates it into the abstract-state dict. This is total:
% missing ids default to 0 (except the direction and DataSource
% ids, which default to 1 to match DllMain ATTACH zero-init plus
% the explicit 1-initialisation in OLInit).
%------------------------------------------------------------

pi_project(Observation, Abs) :-
    findall(Name-Value,
            ( observable_var(Id, Name),
              ( member(Id-V, Observation) -> Value = V
              ; pi_default(Id, Value)
              )
            ),
            Pairs),
    dict_pairs(Abs, abs, Pairs).

pi_default(2,  1) :- !.
pi_default(4,  1) :- !.
pi_default(6,  1) :- !.
pi_default(10, 1) :- !.
pi_default(_,  0).

%------------------------------------------------------------
% Abstract transition delta : A x Event -> A
%
% Events:
%   init        - reinitialise (OLInit / DllMain ATTACH)
%   set(Id, V)  - OLSetField(Id, V); sign-flip when Id is a value
%                 field and V < 0
%   calc        - OLCalcBtn; Magnitude := isqrt(AP^2 + SI^2 + LR^2)
%   clear       - OLClearBtn; equivalent to init
%
% These equations are the content of the structure lemmas in
% state_graph_lemmas.pl; delta is defined here so it can be reused
% by both the forward (P -> A) and the backward (C -> A) side of
% the bisimulation.
%------------------------------------------------------------

abs_step(_, init, A) :-
    abstract_init(A).

abs_step(A, clear, A2) :-
    abs_step(A, init, A2).

abs_step(A, set(Id, V), A2) :-
    observable_var(Id, Name),
    ( dir_pair(Id, DirId), V < 0 ->
        observable_var(DirId, DirName),
        AbsV is -V,
        get_dict(DirName, A, CurDir),
        ( CurDir =:= 1 -> NewDir = 2 ; NewDir = 1 ),
        put_dict(Name,    A,  AbsV,  A1),
        put_dict(DirName, A1, NewDir, A2)
    ;
        put_dict(Name, A, V, A2)
    ).

abs_step(A, calc, A2) :-
    get_dict('APValue', A, AP),
    get_dict('SIValue', A, SI),
    get_dict('LRValue', A, LR),
    N is AP*AP + SI*SI + LR*LR,
    isqrt(N, Mag),
    put_dict('Magnitude', A, Mag, A2).

abs_run(A, [], A).
abs_run(A, [E|Es], A2) :-
    abs_step(A, E, A1),
    abs_run(A1, Es, A2).

%------------------------------------------------------------
% Integer square root -- matches Clarion's ISqrt(). Pure, so safe
% to share between the sigma-side and the pi-side.
%------------------------------------------------------------

isqrt(N, 0) :- N =< 0, !.
isqrt(N, R) :-
    X1 is (N + 1) // 2,
    isqrt_loop(N, N, X1, R).

isqrt_loop(_N, X, X1, X1) :- X1 >= X, !.
isqrt_loop(N, _X, X1, R) :-
    X2 is (X1 + N // X1) // 2,
    isqrt_loop(N, X1, X2, R).

%------------------------------------------------------------
% Bisimulation relation
%
%   s_p R s_c   iff   sigma(s_p) = pi(s_c)
%
% Equality of abstract-state dicts is definitional, so R is
% decidable from a Prolog state and a DLL observation.
%------------------------------------------------------------

bisim_related(PrologState, DLLObservation) :-
    sigma(PrologState, A_P),
    pi_project(DLLObservation, A_C),
    A_P == A_C.

%------------------------------------------------------------
% Forward simulation step (P-side).
%
% Given related states s_p R s_c and an event e, advance the
% abstract state and hand the expected post-image to the caller,
% which is responsible for stepping the interpreter and checking
% that sigma of the result equals this expected image. This is the
% P-half of the diagram; the C-half is the content of
% state_graph_lemmas:lemma_pi_step/3, discharged by direct appeal
% to the CDB trace equations.
%------------------------------------------------------------

bisim_step_forward(S_P, S_C, Event, ExpectedAbs) :-
    bisim_related(S_P, S_C),
    sigma(S_P, A),
    abs_step(A, Event, ExpectedAbs).

%------------------------------------------------------------
% bisim_check_trace/2
%
% Runs the abstract transition system on a sequence of events,
% returning the resulting abstract state. Callers pair this with
% the sigma-image of the interpreter's final state and the
% pi-image of the DLL's final observation and check all three
% agree.
%------------------------------------------------------------

bisim_check_trace(Events, FinalAbs) :-
    abstract_init(A0),
    abs_run(A0, Events, FinalAbs).
