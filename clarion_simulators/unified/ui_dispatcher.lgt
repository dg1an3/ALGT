%============================================================
% ui_dispatcher.lgt - UI Backend Dispatcher (Logtalk)
%
% Routes UI operations to appropriate backend object.
% Event queue and mode control are handled directly here
% (shared across all backends).
%
% Usage:
%   ui_dispatcher::init(simulation, StateIn, StateOut).
%   ui_dispatcher::open_window(WindowDef, StateIn, StateOut, Result).
%============================================================

:- object(ui_dispatcher).

    :- use_module(library(lists), [member/2, append/3]).

    :- public([
        % Initialization
        init/3,                 % (Backend, StateIn, StateOut)
        shutdown/2,             % (StateIn, StateOut)

        % Window operations
        open_window/4,          % (WindowDef, StateIn, StateOut, Result)
        close_window/3,         % (StateIn, StateOut, Result)

        % Control operations
        get_control_value/4,    % (ControlId, StateIn, Value, Result)
        set_control_value/5,    % (ControlId, Value, StateIn, StateOut, Result)
        set_control_prop/6,     % (ControlId, Prop, Value, StateIn, StateOut, Result)
        select/4,               % (ControlId, StateIn, StateOut, Result)
        display/3,              % (StateIn, StateOut, Result)

        % Event handling (shared, not dispatched)
        push_event/4,           % (Event, StateIn, StateOut, Result)
        poll_event/3,           % (StateIn, StateOut, Event)
        has_events/2,           % (State, Bool)
        get_current_event/2,    % (State, Event)
        set_current_event/4,    % (Event, StateIn, StateOut, Result)

        % Mode control (shared, not dispatched)
        set_mode/4,             % (Mode, StateIn, StateOut, Result)
        get_mode/2,             % (State, Mode)
        get_backend/2           % (State, Backend)
    ]).

    % Backend selection
    :- private(get_backend_object/2).

    get_backend_object(simulation, ui_simulation).
    get_backend_object(tui, _) :-
        format(user_error, "TUI backend not implemented~n", []), fail.
    get_backend_object(remote, _) :-
        format(user_error, "Remote backend not implemented~n", []), fail.

    get_backend(State, Backend) :-
        {simulator_state:get_ui_state(State, UIState)},
        get_dict(backend, UIState, Backend).

    % Initialization
    init(Backend, StateIn, StateOut) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        put_dict(backend, UIState, Backend, NewUIState),
        {simulator_state:set_ui_state(NewUIState, StateIn, State1)},
        get_backend_object(Backend, Obj),
        Obj::init(State1, StateOut).

    shutdown(StateIn, StateOut) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::shutdown(StateIn, StateOut).

    % Dispatched window operations
    open_window(WindowDef, StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::open_window(WindowDef, StateIn, StateOut, Result).

    close_window(StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::close_window(StateIn, StateOut, Result).

    % Dispatched control operations
    get_control_value(ControlId, StateIn, Value, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::get_control_value(ControlId, StateIn, Value, Result).

    set_control_value(ControlId, Value, StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::set_control_value(ControlId, Value, StateIn, StateOut, Result).

    set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result).

    select(ControlId, StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::select(ControlId, StateIn, StateOut, Result).

    display(StateIn, StateOut, Result) :-
        get_backend(StateIn, Backend),
        get_backend_object(Backend, Obj),
        Obj::display(StateIn, StateOut, Result).

    % Event handling (shared across all backends)
    push_event(Event, StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(event_queue, UIState, Queue),
        append(Queue, [Event], NewQueue),
        put_dict(event_queue, UIState, NewQueue, NewUIState),
        {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
        Result = ok.

    poll_event(StateIn, StateOut, Event) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(event_queue, UIState, Queue),
        ( Queue = [Event|RestQueue]
        -> put_dict(event_queue, UIState, RestQueue, NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)}
        ;  Event = none,
           StateOut = StateIn
        ).

    has_events(State, Bool) :-
        {simulator_state:get_ui_state(State, UIState)},
        get_dict(event_queue, UIState, Queue),
        ( Queue = [] -> Bool = false ; Bool = true ).

    get_current_event(State, Event) :-
        {simulator_state:get_ui_state(State, UIState)},
        get_dict(current_event, UIState, Event).

    set_current_event(Event, StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        put_dict(current_event, UIState, Event, NewUIState),
        {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
        Result = ok.

    % Mode control (shared across all backends)
    set_mode(Mode, StateIn, StateOut, Result) :-
        ( member(Mode, [sync, async])
        -> {simulator_state:get_ui_state(StateIn, UIState)},
           put_dict(mode, UIState, Mode, NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  StateOut = StateIn,
           Result = error(invalid_mode)
        ).

    get_mode(State, Mode) :-
        {simulator_state:get_ui_state(State, UIState)},
        get_dict(mode, UIState, Mode).

:- end_object.
