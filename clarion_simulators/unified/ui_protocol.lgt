%============================================================
% ui_protocol.lgt - UI Backend Protocol
%
% Defines the interface all UI backends must implement.
% Operations work on the simulator state containing ui_state.
%============================================================

:- protocol(iui_backend).

    :- public([
        init/2,                 % (StateIn, StateOut)
        shutdown/2,             % (StateIn, StateOut)

        % Window operations
        open_window/4,          % (WindowDef, StateIn, StateOut, Result)
        close_window/3,         % (StateIn, StateOut, Result)

        % Control operations
        get_control_value/4,    % (ControlId, StateIn, Value, Result)
        set_control_value/5,    % (ControlId, Value, StateIn, StateOut, Result)
        set_control_prop/6,     % (ControlId, Prop, Value, StateIn, StateOut, Result)
        select/4,               % (ControlId, StateIn, StateOut, Result)
        display/3               % (StateIn, StateOut, Result)
    ]).

:- end_protocol.
