%============================================================
% state_graph_lemmas.pl - Structure Lemmas for Global State
%                        Changes Under Each Event
%
% The bisimulation established in bisimulation.pl reduces to
% showing that sigma (on the Prolog side) and pi (on the
% compiled-DLL side) both commute with a shared abstract
% transition function delta.
%
% "Commutes" is shorthand for one equation per event; those
% equations are the structure lemmas that live here. Each lemma
% is stated as a Prolog predicate that succeeds iff the equation
% holds on the argument state, so the lemmas are mechanically
% checkable -- for any concrete pre-state we can execute the
% lemma and observe that it discharges.
%
% Structure of a lemma:
%
%   lemma_<event>(+PreAbs, +EventArgs, -PostAbs) :-
%       <equations defining PostAbs from PreAbs and EventArgs>.
%
% Each lemma is accompanied by a sanity check that agrees with
% bisimulation:abs_step/3. The two must stay in lockstep; the test
% suite (test_bisimulation.pl) drives them against one another
% plus the running interpreter.
%============================================================

:- module(state_graph_lemmas, [
    lemma_init/1,
    lemma_set_value_nonneg/4,
    lemma_set_value_negative/4,
    lemma_set_direction/4,
    lemma_set_scalar/4,
    lemma_calc/2,
    lemma_clear/2,

    check_all_lemmas/0,
    lemma_agrees_with_delta/3
]).

:- use_module(bisimulation, [
    abstract_init/1,
    abs_step/3,
    observable_var/2,
    dir_pair/2
]).

%------------------------------------------------------------
% Lemma (Init). Both OLInit (compiled DLL) and init_session plus
% implicit zero-init (Prolog interpreter) produce the same
% abstract state:
%
%       sigma(init_P) = pi(init_C) = abstract_init
%
% Formally: for any two states s_p, s_c resulting from
% initialisation, sigma(s_p) = pi(s_c) and both equal the constant
% abstract_init/1 dict.
%------------------------------------------------------------

lemma_init(Abs) :-
    abstract_init(Abs).

%------------------------------------------------------------
% Lemma (Set - value field, non-negative).
%
% When Id is a value field (APValue | SIValue | LRValue) and
% V >= 0:
%
%       OLSetField(Id, V) :  A |-> A[Name(Id) := V]
%
% i.e. exactly one observable variable changes, and the paired
% direction variable is NOT changed. This is the "no sign-flip"
% branch.
%------------------------------------------------------------

lemma_set_value_nonneg(Pre, Id, V, Post) :-
    dir_pair(Id, _),                  % Id is a value field
    V >= 0,
    observable_var(Id, Name),
    put_dict(Name, Pre, V, Post).

%------------------------------------------------------------
% Lemma (Set - value field, negative: sign-flip).
%
% When Id is a value field and V < 0, two observable variables
% change atomically:
%
%       OLSetField(Id, V) :
%           A |-> A[Name(Id)    := -V,
%                   Name(DirId) := toggle(A[Name(DirId)]) ]
%
% where DirId = dir_pair(Id) and toggle(1)=2, toggle(2)=1.
%
% No other observable variable changes. (In particular Magnitude
% is NOT recomputed here -- that only happens on a calc event.)
%------------------------------------------------------------

lemma_set_value_negative(Pre, Id, V, Post) :-
    dir_pair(Id, DirId),
    V < 0,
    AbsV is -V,
    observable_var(Id, Name),
    observable_var(DirId, DirName),
    get_dict(DirName, Pre, CurDir),
    ( CurDir =:= 1 -> NewDir = 2 ; NewDir = 1 ),
    put_dict(Name,    Pre,  AbsV,   Mid),
    put_dict(DirName, Mid,  NewDir, Post).

%------------------------------------------------------------
% Lemma (Set - direction field).
%
% When Id is a direction field (APDir | SIDir | LRDir), the value
% is written as-is (no sign-flip, no side effects):
%
%       OLSetField(Id, V) :  A |-> A[Name(Id) := V]
%------------------------------------------------------------

lemma_set_direction(Pre, Id, V, Post) :-
    dir_pair(_, Id),                  % Id appears on the right of dir_pair
    observable_var(Id, Name),
    put_dict(Name, Pre, V, Post).

%------------------------------------------------------------
% Lemma (Set - other scalar fields).
%
% For OffsetDate, OffsetTime, DataSource: write V as-is.
%
%       OLSetField(Id, V) :  A |-> A[Name(Id) := V]
%------------------------------------------------------------

lemma_set_scalar(Pre, Id, V, Post) :-
    observable_var(Id, Name),
    \+ dir_pair(Id, _),
    \+ dir_pair(_, Id),
    put_dict(Name, Pre, V, Post).

%------------------------------------------------------------
% Lemma (Calc).
%
% OLCalcBtn is a pure function of (APValue, SIValue, LRValue):
%
%       A |-> A[Magnitude := isqrt(AP^2 + SI^2 + LR^2)]
%
% All other observable variables are unchanged.
%
% Corollary: the calc event is idempotent whenever the three
% value fields are unchanged, which is what makes the "Query
% after Calc" probes in trace_offsetlib.pl observationally stable.
%------------------------------------------------------------

lemma_calc(Pre, Post) :-
    get_dict('APValue', Pre, AP),
    get_dict('SIValue', Pre, SI),
    get_dict('LRValue', Pre, LR),
    N is AP*AP + SI*SI + LR*LR,
    bisim_isqrt(N, Mag),
    put_dict('Magnitude', Pre, Mag, Post).

% Re-use bisimulation's isqrt (but keep it module-local so this
% file can be loaded independently for review).
bisim_isqrt(N, 0) :- N =< 0, !.
bisim_isqrt(N, R) :-
    X1 is (N + 1) // 2,
    isqrt_loop_l(N, N, X1, R).
isqrt_loop_l(_, X, X1, X1) :- X1 >= X, !.
isqrt_loop_l(N, _X, X1, R) :-
    X2 is (X1 + N // X1) // 2,
    isqrt_loop_l(N, X1, X2, R).

%------------------------------------------------------------
% Lemma (Clear).
%
% OLClearBtn restores the initial abstract state regardless of
% the pre-state:
%
%       for all A. clear : A |-> abstract_init
%
% Which is the same action as init, so "clear" and "init" are
% observationally equivalent events. This justifies collapsing
% them into a single equivalence class when reasoning about state
% reachability.
%------------------------------------------------------------

lemma_clear(_Pre, Post) :-
    abstract_init(Post).

%------------------------------------------------------------
% Agreement check: each lemma must produce the same post-state
% as bisimulation:abs_step/3 (the delta function used by the
% proof). If either side drifts, check_all_lemmas/0 reports the
% divergence.
%------------------------------------------------------------

lemma_agrees_with_delta(Pre, Event, Post) :-
    abs_step(Pre, Event, Post_delta),
    ( Event = init                -> lemma_init(Post)
    ; Event = clear               -> lemma_clear(Pre, Post)
    ; Event = calc                -> lemma_calc(Pre, Post)
    ; Event = set(Id, V), V >= 0,
      dir_pair(Id, _)             -> lemma_set_value_nonneg(Pre, Id, V, Post)
    ; Event = set(Id, V), V < 0,
      dir_pair(Id, _)             -> lemma_set_value_negative(Pre, Id, V, Post)
    ; Event = set(Id, V),
      dir_pair(_, Id)             -> lemma_set_direction(Pre, Id, V, Post)
    ; Event = set(Id, V)          -> lemma_set_scalar(Pre, Id, V, Post)
    ),
    Post == Post_delta.

%------------------------------------------------------------
% check_all_lemmas/0
%
% A tiny sample-based check. The set of events is large (V ranges
% over all integers) but each lemma partitions the event space
% into a finite set of cases, and representative witnesses for
% each case are enough to exercise every structural clause.
%------------------------------------------------------------

check_all_lemmas :-
    abstract_init(A0),
    Events = [
        init,
        set(1,  10),        % value field, non-negative
        set(1, -10),        % value field, negative (sign-flip)
        set(2,   2),        % direction field
        set(8, 82252),      % scalar (OffsetDate)
        calc,
        clear
    ],
    forall(
        member(E, Events),
        ( lemma_agrees_with_delta(A0, E, _Post)
        -> format("  [ok] lemma for ~w~n", [E])
        ;  format("  [FAIL] lemma for ~w~n", [E]),
           throw(lemma_failed(E))
        )
    ).
