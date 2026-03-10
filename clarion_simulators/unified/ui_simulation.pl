%============================================================
% ui_simulation.pl - Simulation UI Backend
%
% Headless UI backend for testing. Provides:
%   - In-memory window/control state
%   - Event injection for test scenarios
%   - Control value tracking via USE bindings
%
% This backend allows tests to simulate user interactions
% without an actual GUI.
%============================================================

:- module(ui_simulation, [
    % Initialization
    sim_init/2,
    sim_shutdown/2,

    % Window operations
    sim_open_window/4,
    sim_close_window/3,

    % Control operations
    sim_get_control_value/4,
    sim_set_control_value/5,
    sim_set_control_prop/6,
    sim_select/4,
    sim_display/3
]).

:- use_module(simulator_state).

%------------------------------------------------------------
% Window State Structure
%------------------------------------------------------------
% window_state{
%     name: Name,           % Window variable name
%     title: Title,         % Window title
%     controls: [...],      % List of control_state{}
%     focus: ControlId,     % Currently focused control (or none)
%     is_open: Bool         % Is window open
% }
%
% control_state{
%     id: Id,               % Control identifier (from USE)
%     type: Type,           % entry | button | prompt | spin | string
%     text: Text,           % Display text / label
%     value: Value,         % Current value (for input controls)
%     binding: Binding,     % Variable binding (from USE)
%     props: Props          % Dict of properties
% }

%------------------------------------------------------------
% Initialization
%------------------------------------------------------------

sim_init(State, State).
    % Simulation backend requires no special initialization

sim_shutdown(State, State).
    % Simulation backend requires no special shutdown

%------------------------------------------------------------
% Window Operations
%------------------------------------------------------------

% Open a window - creates window_state from definition
sim_open_window(WindowDef, StateIn, StateOut, Result) :-
    ( WindowDef = window(Name, Title, Controls)
    -> build_window_state(Name, Title, Controls, WindowState),
       get_ui_state(StateIn, UIState),
       Windows = UIState.windows,
       NewUIState = UIState.put(windows, [WindowState|Windows]),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  % No window definition - create empty window for compatibility
       EmptyWindow = window_state{
           name: anonymous,
           title: '',
           controls: [],
           focus: none,
           is_open: true
       },
       get_ui_state(StateIn, UIState),
       Windows = UIState.windows,
       NewUIState = UIState.put(windows, [EmptyWindow|Windows]),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ).

% Build window_state from AST
build_window_state(Name, Title, Controls, WindowState) :-
    build_control_states(Controls, ControlStates),
    WindowState = window_state{
        name: Name,
        title: Title,
        controls: ControlStates,
        focus: none,
        is_open: true
    }.

% Build control states from control definitions
build_control_states([], []).
build_control_states([Control|Rest], [ControlState|RestStates]) :-
    build_control_state(Control, ControlState),
    build_control_states(Rest, RestStates).

% Build a single control state
% For new-style control(Type, Text, Attrs)
build_control_state(control(Type, Text, Attrs), ControlState) :-
    extract_control_id(Attrs, Id),
    extract_control_binding(Attrs, Binding),
    ControlState = control_state{
        id: Id,
        type: Type,
        text: Text,
        value: '',
        binding: Binding,
        props: props{}
    }.

% For old-style controls (backward compatibility)
build_control_state(entry_control(Format), ControlState) :-
    ControlState = control_state{
        id: none,
        type: entry,
        text: Format,
        value: '',
        binding: none,
        props: props{}
    }.
build_control_state(button_control(Text), ControlState) :-
    ControlState = control_state{
        id: none,
        type: button,
        text: Text,
        value: '',
        binding: none,
        props: props{}
    }.
build_control_state(prompt_control(Text), ControlState) :-
    ControlState = control_state{
        id: none,
        type: prompt,
        text: Text,
        value: '',
        binding: none,
        props: props{}
    }.
build_control_state(spin_control(Format), ControlState) :-
    ControlState = control_state{
        id: none,
        type: spin,
        text: Format,
        value: 0,
        binding: none,
        props: props{}
    }.
build_control_state(string_control(Text), ControlState) :-
    ControlState = control_state{
        id: none,
        type: string,
        text: Text,
        value: '',
        binding: none,
        props: props{}
    }.

% Extract control ID from attributes
extract_control_id(Attrs, Id) :-
    ( member(use(control_ref(Id)), Attrs)
    -> true
    ;  Id = none
    ).

% Extract variable binding from attributes
extract_control_binding(Attrs, Binding) :-
    ( member(use(var_ref(Binding)), Attrs)
    -> true
    ;  Binding = none
    ).

% Close the top window
sim_close_window(StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    Windows = UIState.windows,
    ( Windows = [_|RestWindows]
    -> NewUIState = UIState.put(windows, RestWindows),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(no_window)
    ).

%------------------------------------------------------------
% Control Operations
%------------------------------------------------------------

% Get control value by ID
sim_get_control_value(ControlId, StateIn, Value, Result) :-
    get_ui_state(StateIn, UIState),
    Windows = UIState.windows,
    ( Windows = [TopWindow|_],
      find_control(ControlId, TopWindow.controls, Control)
    -> Value = Control.value,
       Result = ok
    ;  Value = '',
       Result = error(control_not_found)
    ).

% Set control value by ID
sim_set_control_value(ControlId, Value, StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    Windows = UIState.windows,
    ( Windows = [TopWindow|RestWindows],
      update_control_value(ControlId, Value, TopWindow.controls, NewControls)
    -> NewWindow = TopWindow.put(controls, NewControls),
       NewUIState = UIState.put(windows, [NewWindow|RestWindows]),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(control_not_found)
    ).

% Set control property
sim_set_control_prop(ControlId, Prop, Value, StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    Windows = UIState.windows,
    ( Windows = [TopWindow|RestWindows],
      update_control_prop(ControlId, Prop, Value, TopWindow.controls, NewControls)
    -> NewWindow = TopWindow.put(controls, NewControls),
       NewUIState = UIState.put(windows, [NewWindow|RestWindows]),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(control_not_found)
    ).

% Select (focus) a control
sim_select(ControlId, StateIn, StateOut, Result) :-
    get_ui_state(StateIn, UIState),
    Windows = UIState.windows,
    ( Windows = [TopWindow|RestWindows]
    -> NewWindow = TopWindow.put(focus, ControlId),
       NewUIState = UIState.put(windows, [NewWindow|RestWindows]),
       set_ui_state(NewUIState, StateIn, StateOut),
       Result = ok
    ;  StateOut = StateIn,
       Result = error(no_window)
    ).

% Display/refresh - no-op for simulation
sim_display(State, State, ok).

%------------------------------------------------------------
% Control Helpers
%------------------------------------------------------------

% Find a control by ID in a list
find_control(ControlId, [Control|_], Control) :-
    is_dict(Control, control_state),
    Control.id == ControlId, !.
find_control(ControlId, [_|Rest], Control) :-
    find_control(ControlId, Rest, Control).

% Update control value in a list
update_control_value(ControlId, Value, [Control|Rest], [NewControl|Rest]) :-
    is_dict(Control, control_state),
    Control.id == ControlId, !,
    NewControl = Control.put(value, Value).
update_control_value(ControlId, Value, [Control|Rest], [Control|NewRest]) :-
    update_control_value(ControlId, Value, Rest, NewRest).

% Update control property in a list
update_control_prop(ControlId, Prop, Value, [Control|Rest], [NewControl|Rest]) :-
    is_dict(Control, control_state),
    Control.id == ControlId, !,
    OldProps = Control.props,
    NewProps = OldProps.put(Prop, Value),
    NewControl = Control.put(props, NewProps).
update_control_prop(ControlId, Prop, Value, [Control|Rest], [Control|NewRest]) :-
    update_control_prop(ControlId, Prop, Value, Rest, NewRest).
