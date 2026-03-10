%============================================================
% scenario_dsl.pl - Scenario-Based Testing DSL
%
% Provides a declarative DSL for testing Clarion programs
% with UI interactions. Scenarios specify:
%   - Setup: Initial program/window state
%   - Actions: User interactions (field input, button clicks)
%   - Expectations: Expected outcomes (messages, variable values)
%============================================================

:- module(scenario_dsl, [
    % Scenario execution
    run_scenario/2,         % (Scenario, Result)
    run_scenarios/2,        % (Scenarios, Results)
    run_scenario_file/2,    % (FilePath, Results)

    % Action helpers
    inject_event/4,         % (Event, StateIn, StateOut, Result)
    set_field/5,            % (ControlId, Value, StateIn, StateOut, Result)
    click_button/4          % (ControlId, StateIn, StateOut, Result)
]).

:- use_module(simulator_state).
:- use_module(ui_backend).
:- use_module(simulator).
:- use_module(clarion).

%------------------------------------------------------------
% Scenario Structure
%------------------------------------------------------------
% scenario(Name, Setup, Actions, Expectations)
%
% Name: Atom identifying the scenario
% Setup: List of setup terms
%   - program(Source)           % Clarion source code
%   - window(WindowDef)         % Window definition to open
%   - var(Name, Value)          % Pre-set variable
%   - file(Name, Records)       % Pre-populate file
%
% Actions: List of action terms
%   - event(EventType)          % Inject raw event
%   - field(ControlId, Value)   % Set field value
%   - click(ControlId)          % Click button (injects EVENT:Accepted)
%   - step                      % Run one ACCEPT iteration
%   - run_until(Condition)      % Run until condition met
%
% Expectations: List of expectation terms
%   - message(Text)             % MESSAGE was called with exact text
%   - message_contains(Substr)  % MESSAGE contains substring
%   - var(Name, Value)          % Variable has expected value
%   - control_value(Id, Value)  % Control has expected value
%   - no_error                  % No runtime errors occurred
%   - error(Code)               % Specific error code occurred

%------------------------------------------------------------
% Scenario Execution
%------------------------------------------------------------

% Run a single scenario
run_scenario(scenario(Name, Setup, Actions, Expectations), Result) :-
    format("Running scenario: ~w~n", [Name]),
    % Initialize state
    setup_scenario(Setup, State0, SetupResult),
    ( SetupResult = ok
    -> % Execute actions
       execute_actions(Actions, State0, State1, ActionsResult),
       ( ActionsResult = ok
       -> % Check expectations
          check_expectations(Expectations, State1, ExpectResults),
          ( all_passed(ExpectResults)
          -> Result = passed(Name)
          ;  Result = failed(Name, expectations_failed(ExpectResults))
          )
       ;  Result = failed(Name, actions_failed(ActionsResult))
       )
    ;  Result = failed(Name, setup_failed(SetupResult))
    ).

% Run multiple scenarios
run_scenarios([], []).
run_scenarios([Scenario|Rest], [Result|Results]) :-
    run_scenario(Scenario, Result),
    run_scenarios(Rest, Results).

% Run scenarios from a file
run_scenario_file(FilePath, Results) :-
    read_file_to_terms(FilePath, Scenarios, []),
    run_scenarios(Scenarios, Results).

%------------------------------------------------------------
% Setup Phase
%------------------------------------------------------------

setup_scenario([], State, ok) :-
    empty_state(State).
setup_scenario(Setup, FinalState, Result) :-
    Setup \= [],
    empty_state(State0),
    ui_init(simulation, State0, State1),
    apply_setup(Setup, State1, FinalState, Result).

apply_setup([], State, State, ok).
apply_setup([SetupItem|Rest], StateIn, StateOut, Result) :-
    apply_setup_item(SetupItem, StateIn, State1, ItemResult),
    ( ItemResult = ok
    -> apply_setup(Rest, State1, StateOut, Result)
    ;  StateOut = State1,
       Result = ItemResult
    ).

% Setup item handlers
apply_setup_item(program(Source), StateIn, StateOut, Result) :-
    ( parse_string(Source, AST)
    -> init_program(AST, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(parse_failed)
    ).

apply_setup_item(window(WindowDef), StateIn, StateOut, Result) :-
    ui_open_window(WindowDef, StateIn, StateOut, Result).

apply_setup_item(var(Name, Value), StateIn, StateOut, ok) :-
    set_var(Name, Value, StateIn, StateOut).

apply_setup_item(event_queue(Events), StateIn, StateOut, ok) :-
    push_events(Events, StateIn, StateOut).

apply_setup_item(_, State, State, ok).  % Ignore unknown setup items

% Push multiple events to the queue
push_events([], State, State).
push_events([Event|Rest], StateIn, StateOut) :-
    ui_push_event(Event, StateIn, State1, _),
    push_events(Rest, State1, StateOut).

%------------------------------------------------------------
% Action Execution
%------------------------------------------------------------

execute_actions([], State, State, ok).
execute_actions([Action|Rest], StateIn, StateOut, Result) :-
    execute_action(Action, StateIn, State1, ActionResult),
    ( ActionResult = ok
    -> execute_actions(Rest, State1, StateOut, Result)
    ;  StateOut = State1,
       Result = ActionResult
    ).

% Action handlers
execute_action(event(Event), StateIn, StateOut, Result) :-
    inject_event(Event, StateIn, StateOut, Result).

execute_action(field(ControlId, Value), StateIn, StateOut, Result) :-
    set_field(ControlId, Value, StateIn, StateOut, Result).

execute_action(click(ControlId), StateIn, StateOut, Result) :-
    click_button(ControlId, StateIn, StateOut, Result).

execute_action(step, StateIn, StateOut, Result) :-
    accept_loop_step(StateIn, StateOut, Result).

execute_action(run_to_completion, StateIn, StateOut, ok) :-
    run_accept_to_completion(StateIn, StateOut).

% Inject a raw event into the queue
inject_event(Event, StateIn, StateOut, Result) :-
    ui_push_event(Event, StateIn, StateOut, Result).

% Set a field value by control ID
set_field(ControlId, Value, StateIn, StateOut, Result) :-
    ui_set_control_value(ControlId, Value, StateIn, StateOut, Result).

% Click a button (sets current event to Accepted with that control)
click_button(ControlId, StateIn, StateOut, Result) :-
    ui_push_event(event_accepted(ControlId), StateIn, State1, _),
    ui_set_current_event(event_accepted(ControlId), State1, StateOut, Result).

% Run one step of the accept loop
accept_loop_step(StateIn, StateOut, Result) :-
    ( get_continuation(StateIn, Cont),
      Cont \= none
    -> % Resume existing continuation
       resume_accept_loop(Cont, StateIn, StateOut, Control),
       ( Control = next -> Result = ok ; Result = ok )
    ;  % No continuation - just process next event
       ui_poll_event(StateIn, StateOut, _),
       Result = ok
    ).

% Run accept loop until no more events or window closes
run_accept_to_completion(StateIn, StateOut) :-
    ( ui_has_events(StateIn, true)
    -> accept_loop_step(StateIn, State1, _),
       run_accept_to_completion(State1, StateOut)
    ;  StateOut = StateIn
    ).

%------------------------------------------------------------
% Expectation Checking
%------------------------------------------------------------

check_expectations([], _, []).
check_expectations([Expect|Rest], State, [Result|Results]) :-
    check_expectation(Expect, State, Result),
    check_expectations(Rest, State, Results).

% Expectation checkers
check_expectation(message(Text), State, Result) :-
    get_output(State, Output),
    ( member(message(Text), Output)
    -> Result = passed(message(Text))
    ;  Result = failed(message(Text), not_found)
    ).

check_expectation(message_contains(Substr), State, Result) :-
    get_output(State, Output),
    ( find_message_containing(Substr, Output)
    -> Result = passed(message_contains(Substr))
    ;  Result = failed(message_contains(Substr), not_found)
    ).

check_expectation(var(Name, Expected), State, Result) :-
    ( get_var(Name, State, Actual)
    -> ( Actual = Expected
       -> Result = passed(var(Name, Expected))
       ;  Result = failed(var(Name, Expected), actual(Actual))
       )
    ;  Result = failed(var(Name, Expected), undefined)
    ).

check_expectation(control_value(ControlId, Expected), State, Result) :-
    ui_get_control_value(ControlId, State, Actual, _),
    ( Actual = Expected
    -> Result = passed(control_value(ControlId, Expected))
    ;  Result = failed(control_value(ControlId, Expected), actual(Actual))
    ).

check_expectation(no_error, State, Result) :-
    get_error(State, ErrCode),
    ( ErrCode = 0
    -> Result = passed(no_error)
    ;  Result = failed(no_error, error_code(ErrCode))
    ).

check_expectation(error(ExpectedCode), State, Result) :-
    get_error(State, ActualCode),
    ( ActualCode = ExpectedCode
    -> Result = passed(error(ExpectedCode))
    ;  Result = failed(error(ExpectedCode), actual(ActualCode))
    ).

% Helper to find a message containing a substring
find_message_containing(Substr, [message(Text)|_]) :-
    atom(Text),
    atom_string(Text, TextStr),
    atom_string(Substr, SubstrStr),
    sub_string(TextStr, _, _, _, SubstrStr), !.
find_message_containing(Substr, [message(Text)|_]) :-
    string(Text),
    atom_string(Substr, SubstrStr),
    sub_string(Text, _, _, _, SubstrStr), !.
find_message_containing(Substr, [_|Rest]) :-
    find_message_containing(Substr, Rest).

% Check if all expectations passed
all_passed([]).
all_passed([passed(_)|Rest]) :- all_passed(Rest).

%------------------------------------------------------------
% Utility Predicates
%------------------------------------------------------------

% Parse Clarion source from a string
parse_string(Source, AST) :-
    atom_string(SourceAtom, Source),
    atom_codes(SourceAtom, Codes),
    lexer:tokenize(Codes, Tokens),
    parser:parse_program(Tokens, AST).

% Initialize program from AST (wrapper for simulator)
init_program(AST, StateIn, StateOut) :-
    simulator:init_program(AST, StateIn, StateOut).
