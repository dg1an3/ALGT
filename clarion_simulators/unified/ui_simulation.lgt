%============================================================
% ui_simulation.lgt - Simulation UI Backend (Logtalk)
%
% Headless UI backend for testing. Provides:
%   - In-memory window/control state
%   - Event injection for test scenarios
%   - Control value tracking via USE bindings
%============================================================

:- object(ui_simulation,
    implements(iui_backend)).

    :- use_module(library(lists), [member/2]).

    init(State, State).
    shutdown(State, State).

    % Open a window - creates window_state from definition
    open_window(WindowDef, StateIn, StateOut, Result) :-
        ( WindowDef = window(Name, Title, Controls)
        -> build_window_state(Name, Title, Controls, WindowState),
           {simulator_state:get_ui_state(StateIn, UIState)},
           get_dict(windows, UIState, Windows),
           put_dict(windows, UIState, [WindowState|Windows], NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  EmptyWindow = window_state{
               name: anonymous,
               title: '',
               controls: [],
               focus: none,
               is_open: true
           },
           {simulator_state:get_ui_state(StateIn, UIState)},
           get_dict(windows, UIState, Windows),
           put_dict(windows, UIState, [EmptyWindow|Windows], NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ).

    % Close the top window
    close_window(StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(windows, UIState, Windows),
        ( Windows = [_|RestWindows]
        -> put_dict(windows, UIState, RestWindows, NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  StateOut = StateIn,
           Result = error(no_window)
        ).

    % Get control value by ID
    get_control_value(ControlId, StateIn, Value, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(windows, UIState, Windows),
        ( Windows = [TopWindow|_],
          get_dict(controls, TopWindow, Controls),
          find_control(ControlId, Controls, Control)
        -> get_dict(value, Control, Value),
           Result = ok
        ;  Value = '',
           Result = error(control_not_found)
        ).

    % Set control value by ID
    set_control_value(ControlId, Value, StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(windows, UIState, Windows),
        ( Windows = [TopWindow|RestWindows],
          get_dict(controls, TopWindow, Controls),
          update_control_value(ControlId, Value, Controls, NewControls)
        -> put_dict(controls, TopWindow, NewControls, NewWindow),
           put_dict(windows, UIState, [NewWindow|RestWindows], NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  StateOut = StateIn,
           Result = error(control_not_found)
        ).

    % Set control property
    set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(windows, UIState, Windows),
        ( Windows = [TopWindow|RestWindows],
          get_dict(controls, TopWindow, Controls),
          update_control_prop(ControlId, Prop, Value, Controls, NewControls)
        -> put_dict(controls, TopWindow, NewControls, NewWindow),
           put_dict(windows, UIState, [NewWindow|RestWindows], NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  StateOut = StateIn,
           Result = error(control_not_found)
        ).

    % Select (focus) a control
    select(ControlId, StateIn, StateOut, Result) :-
        {simulator_state:get_ui_state(StateIn, UIState)},
        get_dict(windows, UIState, Windows),
        ( Windows = [TopWindow|RestWindows]
        -> put_dict(focus, TopWindow, ControlId, NewWindow),
           put_dict(windows, UIState, [NewWindow|RestWindows], NewUIState),
           {simulator_state:set_ui_state(NewUIState, StateIn, StateOut)},
           Result = ok
        ;  StateOut = StateIn,
           Result = error(no_window)
        ).

    % Display/refresh - no-op for simulation
    display(State, State, ok).

    % Private helpers
    :- private([
        build_window_state/4,
        build_control_states/2,
        build_control_state/2,
        extract_control_id/2,
        extract_control_binding/2,
        find_control/3,
        update_control_value/4,
        update_control_prop/5
    ]).

    build_window_state(Name, Title, Controls, WindowState) :-
        build_control_states(Controls, ControlStates),
        WindowState = window_state{
            name: Name,
            title: Title,
            controls: ControlStates,
            focus: none,
            is_open: true
        }.

    build_control_states([], []).
    build_control_states([Control|Rest], [ControlState|RestStates]) :-
        build_control_state(Control, ControlState),
        build_control_states(Rest, RestStates).

    % New-style control(Type, Text, Attrs)
    build_control_state(control(Type, Text, Attrs), ControlState) :-
        extract_control_id(Attrs, Id),
        extract_control_binding(Attrs, Binding),
        ControlState = control_state{
            id: Id, type: Type, text: Text,
            value: '', binding: Binding, props: props{}
        }.
    % Legacy control types
    build_control_state(entry_control(Format), control_state{
        id: none, type: entry, text: Format, value: '', binding: none, props: props{}}).
    build_control_state(button_control(Text), control_state{
        id: none, type: button, text: Text, value: '', binding: none, props: props{}}).
    build_control_state(prompt_control(Text), control_state{
        id: none, type: prompt, text: Text, value: '', binding: none, props: props{}}).
    build_control_state(spin_control(Format), control_state{
        id: none, type: spin, text: Format, value: 0, binding: none, props: props{}}).
    build_control_state(string_control(Text), control_state{
        id: none, type: string, text: Text, value: '', binding: none, props: props{}}).

    extract_control_id(Attrs, Id) :-
        ( member(use(control_ref(Id)), Attrs) -> true ; Id = none ).

    extract_control_binding(Attrs, Binding) :-
        ( member(use(var_ref(Binding)), Attrs) -> true ; Binding = none ).

    find_control(ControlId, [Control|_], Control) :-
        is_dict(Control, control_state),
        get_dict(id, Control, Id),
        Id == ControlId, !.
    find_control(ControlId, [_|Rest], Control) :-
        find_control(ControlId, Rest, Control).

    update_control_value(ControlId, Value, [Control|Rest], [NewControl|Rest]) :-
        is_dict(Control, control_state),
        get_dict(id, Control, Id),
        Id == ControlId, !,
        put_dict(value, Control, Value, NewControl).
    update_control_value(ControlId, Value, [Control|Rest], [Control|NewRest]) :-
        update_control_value(ControlId, Value, Rest, NewRest).

    update_control_prop(ControlId, Prop, Value, [Control|Rest], [NewControl|Rest]) :-
        is_dict(Control, control_state),
        get_dict(id, Control, Id),
        Id == ControlId, !,
        get_dict(props, Control, OldProps),
        put_dict(Prop, OldProps, Value, NewProps),
        put_dict(props, Control, NewProps, NewControl).
    update_control_prop(ControlId, Prop, Value, [Control|Rest], [Control|NewRest]) :-
        update_control_prop(ControlId, Prop, Value, Rest, NewRest).

:- end_object.
