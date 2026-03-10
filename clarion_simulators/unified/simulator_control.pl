%============================================================
% simulator_control.pl - Control Flow Helpers
%
% Provides helper predicates for control flow constructs.
% Actual loop execution is in simulator_core since it needs
% exec_statements.
%============================================================

:- module(simulator_control, [
    % Routine lookup
    get_routine/3,

    % CASE matching
    match_case/3,

    % Event phase management
    next_phase/2
]).

:- use_module(simulator_state).

%------------------------------------------------------------
% Routine Lookup
%------------------------------------------------------------

get_routine(Name, State, Routine) :-
    get_procs(State, Procs),
    member(Routine, Procs),
    Routine = routine(Name, _), !.
get_routine(Name, _, _) :-
    format(user_error, "Error: Undefined routine '~w'~n", [Name]),
    fail.

%------------------------------------------------------------
% CASE Statement Matching
%------------------------------------------------------------

% Find the matching case branch, returns body or 'else' if no match
match_case(_, [], else) :- !.
match_case(Value, [case_of(CaseVal, Body)|_], Body) :-
    Value = CaseVal, !.
match_case(Value, [_|Rest], Result) :-
    match_case(Value, Rest, Result).

%------------------------------------------------------------
% ACCEPT Loop Event Phases
%------------------------------------------------------------

next_phase(open_window, close_window).
next_phase(close_window, done).
next_phase(done, done).
