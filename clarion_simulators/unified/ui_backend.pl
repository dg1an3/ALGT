%============================================================
% ui_backend.pl - UI Backend Dispatcher (Logtalk Bridge)
%
% Thin Prolog module wrapper that delegates to Logtalk
% ui_dispatcher object.
%
% Routes UI operations to appropriate backend based on
% ui_state.backend:
%   - simulation → ui_simulation (headless/testing)
%   - tui        → ui_tui (terminal UI) [future]
%   - remote     → ui_remote (JSON-based) [future]
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

:- use_module(storage_backend, [ensure_logtalk_backends/0]).
:- ensure_logtalk_backends.

% All operations delegate to ui_dispatcher Logtalk object

% Initialization
ui_init(Backend, StateIn, StateOut) :-
    ui_dispatcher::init(Backend, StateIn, StateOut).

ui_shutdown(StateIn, StateOut) :-
    ui_dispatcher::shutdown(StateIn, StateOut).

% Window operations
ui_open_window(WindowDef, StateIn, StateOut, Result) :-
    ui_dispatcher::open_window(WindowDef, StateIn, StateOut, Result).

ui_close_window(StateIn, StateOut, Result) :-
    ui_dispatcher::close_window(StateIn, StateOut, Result).

% Control operations
ui_get_control_value(ControlId, StateIn, Value, Result) :-
    ui_dispatcher::get_control_value(ControlId, StateIn, Value, Result).

ui_set_control_value(ControlId, Value, StateIn, StateOut, Result) :-
    ui_dispatcher::set_control_value(ControlId, Value, StateIn, StateOut, Result).

ui_set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result) :-
    ui_dispatcher::set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result).

ui_select(ControlId, StateIn, StateOut, Result) :-
    ui_dispatcher::select(ControlId, StateIn, StateOut, Result).

ui_display(StateIn, StateOut, Result) :-
    ui_dispatcher::display(StateIn, StateOut, Result).

% Event handling
ui_push_event(Event, StateIn, StateOut, Result) :-
    ui_dispatcher::push_event(Event, StateIn, StateOut, Result).

ui_poll_event(StateIn, StateOut, Event) :-
    ui_dispatcher::poll_event(StateIn, StateOut, Event).

ui_has_events(State, Bool) :-
    ui_dispatcher::has_events(State, Bool).

ui_get_current_event(State, Event) :-
    ui_dispatcher::get_current_event(State, Event).

ui_set_current_event(Event, StateIn, StateOut, Result) :-
    ui_dispatcher::set_current_event(Event, StateIn, StateOut, Result).

% Mode control
ui_set_mode(Mode, StateIn, StateOut, Result) :-
    ui_dispatcher::set_mode(Mode, StateIn, StateOut, Result).

ui_get_mode(State, Mode) :-
    ui_dispatcher::get_mode(State, Mode).

ui_get_backend(State, Backend) :-
    ui_dispatcher::get_backend(State, Backend).
