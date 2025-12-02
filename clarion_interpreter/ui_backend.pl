%============================================================
% ui_backend.pl - UI Backend Dispatcher
%
% Routes UI operations to appropriate backend based on
% ui_state.backend:
%   - simulation → ui_simulation.pl (headless/testing)
%   - tui        → ui_tui.pl (terminal UI) [future]
%   - remote     → ui_remote.pl (JSON-based) [future]
%============================================================

:- module(ui_backend, [
    % Initialization
    ui_init/3,              % (Backend, StateIn, StateOut)
    ui_shutdown/2,          % (StateIn, StateOut)

    % Window operations
    ui_open_window/4,       % (WindowDef, StateIn, StateOut, Result)
    ui_close_window/3,      % (StateIn, StateOut, Result)

    % Control operations
    ui_get_control_value/4, % (ControlId, StateIn, Value, Result)
    ui_set_control_value/5, % (ControlId, Value, StateIn, StateOut, Result)
    ui_set_control_prop/6,  % (ControlId, Prop, Value, StateIn, StateOut, Result)
    ui_select/4,            % (ControlId, StateIn, StateOut, Result)
    ui_display/3,           % (StateIn, StateOut, Result)

    % Event handling
    ui_push_event/4,        % (Event, StateIn, StateOut, Result)
    ui_poll_event/3,        % (StateIn, StateOut, Event)
    ui_has_events/2,        % (State, Bool)
    ui_get_current_event/2, % (State, Event)
    ui_set_current_event/4, % (Event, StateIn, StateOut, Result)

    % Mode control
    ui_set_mode/4,          % (Mode, StateIn, StateOut, Result)
    ui_get_mode/2,          % (State, Mode)
    ui_get_backend/2        % (State, Backend)
]).

:- use_module(interpreter_state).
:- use_module(ui_simulation).

%------------------------------------------------------------
% Backend Selection
%------------------------------------------------------------

% Get the current UI backend from state
ui_get_backend(State, Backend) :-
    get_ui_state(State, UIState),
    Backend = UIState.backend.

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

% Initialize UI backend
ui_init(Backend, StateIn, StateOut) :-
    get_ui_state(StateIn, UIState),
    NewUIState = UIState.put(backend, Backend),
    set_ui_state(NewUIState, StateIn, State1),
    dispatch_init(Backend, State1, StateOut).

dispatch_init(simulation, StateIn, StateOut) :-
    ui_simulation:sim_init(StateIn, StateOut).
dispatch_init(tui, State, State) :-
    format(user_error, "TUI backend not implemented~n", []).
dispatch_init(remote, State, State) :-
    format(user_error, "Remote backend not implemented~n", []).

% Shutdown UI backend
ui_shutdown(StateIn, StateOut) :-
    ui_get_backend(StateIn, Backend),
    dispatch_shutdown(Backend, StateIn, StateOut).

dispatch_shutdown(simulation, StateIn, StateOut) :-
    ui_simulation:sim_shutdown(StateIn, StateOut).
dispatch_shutdown(tui, State, State).
dispatch_shutdown(remote, State, State).

%------------------------------------------------------------
% Window Operations
%------------------------------------------------------------

% Open a window
ui_open_window(WindowDef, StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_open_window(Backend, WindowDef, StateIn, StateOut, Result).

dispatch_open_window(simulation, WindowDef, StateIn, StateOut, Result) :-
    ui_simulation:sim_open_window(WindowDef, StateIn, StateOut, Result).
dispatch_open_window(tui, _WindowDef, State, State, error(not_implemented)).
dispatch_open_window(remote, _WindowDef, State, State, error(not_implemented)).

% Close the current window
ui_close_window(StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_close_window(Backend, StateIn, StateOut, Result).

dispatch_close_window(simulation, StateIn, StateOut, Result) :-
    ui_simulation:sim_close_window(StateIn, StateOut, Result).
dispatch_close_window(tui, State, State, error(not_implemented)).
dispatch_close_window(remote, State, State, error(not_implemented)).

%------------------------------------------------------------
% Control Operations
%------------------------------------------------------------

% Get control value
ui_get_control_value(ControlId, StateIn, Value, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_get_control_value(Backend, ControlId, StateIn, Value, Result).

dispatch_get_control_value(simulation, ControlId, StateIn, Value, Result) :-
    ui_simulation:sim_get_control_value(ControlId, StateIn, Value, Result).
dispatch_get_control_value(tui, _ControlId, _State, '', error(not_implemented)).
dispatch_get_control_value(remote, _ControlId, _State, '', error(not_implemented)).

% Set control value
ui_set_control_value(ControlId, Value, StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_set_control_value(Backend, ControlId, Value, StateIn, StateOut, Result).

dispatch_set_control_value(simulation, ControlId, Value, StateIn, StateOut, Result) :-
    ui_simulation:sim_set_control_value(ControlId, Value, StateIn, StateOut, Result).
dispatch_set_control_value(tui, _ControlId, _Value, State, State, error(not_implemented)).
dispatch_set_control_value(remote, _ControlId, _Value, State, State, error(not_implemented)).

% Set control property
ui_set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_set_control_prop(Backend, ControlId, Prop, Value, StateIn, StateOut, Result).

dispatch_set_control_prop(simulation, ControlId, Prop, Value, StateIn, StateOut, Result) :-
    ui_simulation:sim_set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result).
dispatch_set_control_prop(tui, _ControlId, _Prop, _Value, State, State, error(not_implemented)).
dispatch_set_control_prop(remote, _ControlId, _Prop, _Value, State, State, error(not_implemented)).

% Select (focus) a control
ui_select(ControlId, StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_select(Backend, ControlId, StateIn, StateOut, Result).

dispatch_select(simulation, ControlId, StateIn, StateOut, Result) :-
    ui_simulation:sim_select(ControlId, StateIn, StateOut, Result).
dispatch_select(tui, _ControlId, State, State, error(not_implemented)).
dispatch_select(remote, _ControlId, State, State, error(not_implemented)).

% Display/refresh
ui_display(StateIn, StateOut, Result) :-
    ui_get_backend(StateIn, Backend),
    dispatch_display(Backend, StateIn, StateOut, Result).

dispatch_display(simulation, StateIn, StateOut, Result) :-
    ui_simulation:sim_display(StateIn, StateOut, Result).
dispatch_display(tui, State, State, error(not_implemented)).
dispatch_display(remote, State, State, error(not_implemented)).

%------------------------------------------------------------
% Event Handling
%------------------------------------------------------------

% Push an event to the queue
ui_push_event(Event, StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    Queue = UIState.event_queue,
    append(Queue, [Event], NewQueue),
    NewUIState = UIState.put(event_queue, NewQueue),
    set_ui_state(NewUIState, StateIn, StateOut),
    Result = ok.

% Poll event from queue (non-blocking, returns none if empty)
ui_poll_event(StateIn, StateOut, Event) :-
    get_ui_state(StateIn, UIState),
    Queue = UIState.event_queue,
    ( Queue = [Event|RestQueue]
    -> NewUIState = UIState.put(event_queue, RestQueue),
       set_ui_state(NewUIState, StateIn, StateOut)
    ;  Event = none,
       StateOut = StateIn
    ).

% Check if there are events in the queue
ui_has_events(State, Bool) :-
    get_ui_state(State, UIState),
    Queue = UIState.event_queue,
    ( Queue = [] -> Bool = false ; Bool = true ).

% Get current event being processed
ui_get_current_event(State, Event) :-
    get_ui_state(State, UIState),
    Event = UIState.current_event.

% Set current event being processed
ui_set_current_event(Event, StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    NewUIState = UIState.put(current_event, Event),
    set_ui_state(NewUIState, StateIn, StateOut),
    Result = ok.

%------------------------------------------------------------
% Mode Control
%------------------------------------------------------------

% Set execution mode (sync/async)
ui_set_mode(Mode, StateIn, StateOut, Result) :-
    ( member(Mode, [sync, async])
    -> get_ui_state(StateIn, UIState),
       NewUIState = UIState.put(mode, Mode),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(invalid_mode)
    ).

% Get current execution mode
ui_get_mode(State, Mode) :-
    get_ui_state(State, UIState),
    Mode = UIState.mode.
