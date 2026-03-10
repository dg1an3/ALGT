%============================================================
% simulator_classes.pl - Class and Instance Management
%
% Handles class definitions, instance creation, and property access.
% Method execution is handled in simulator_core.
%============================================================

:- module(simulator_classes, [
    % Class definitions
    init_class/6,
    get_class_def/3,

    % Instance management
    create_instance/3,
    get_instance_prop/3,
    set_instance_prop/4,

    % Method lookup
    find_method_impl/4,
    get_inherited_props/3,

    % Default values
    default_value/3
]).

:- use_module(simulator_state).

%------------------------------------------------------------
% Class Definition Management
%------------------------------------------------------------

% Initialize a class definition in state
init_class(Name, Parent, Attrs, Members, StateIn, StateOut) :-
    StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
    ClassDef = class_def(Name, Parent, Attrs, Members),
    StateOut = state(Vars, Procs, Out, Files, Err, [ClassDef|Classes], Self, UI, Cont).

% Get class definition by name
get_class_def(ClassName, State, ClassDef) :-
    get_classes(State, Classes),
    member(ClassDef, Classes),
    ClassDef = class_def(ClassName, _, _, _), !.
get_class_def(ClassName, _, _) :-
    format(user_error, "Error: Undefined class '~w'~n", [ClassName]),
    fail.

%------------------------------------------------------------
% Instance Management
%------------------------------------------------------------

% Create a new instance of a class with default property values
create_instance(ClassName, State, instance(ClassName, Props)) :-
    get_class_def(ClassName, State, class_def(ClassName, Parent, _, Members)),
    % Get inherited properties from parent
    ( Parent \= none
    -> get_inherited_props(Parent, State, InheritedProps)
    ;  InheritedProps = []
    ),
    % Get own properties
    get_class_props(Members, OwnProps),
    append(InheritedProps, OwnProps, Props).

% Get inherited properties from parent class chain
get_inherited_props(none, _, []) :- !.
get_inherited_props(ParentName, State, AllProps) :-
    get_class_def(ParentName, State, class_def(ParentName, GrandParent, _, Members)),
    get_class_props(Members, ParentProps),
    get_inherited_props(GrandParent, State, GrandProps),
    append(GrandProps, ParentProps, AllProps).

% Extract property definitions from class members
get_class_props([], []).
get_class_props([property(Name, Type, Size)|Rest], [prop(Name, Default)|Props]) :-
    default_value(Type, Size, Default),
    get_class_props(Rest, Props).
get_class_props([method(_, _, _, _)|Rest], Props) :-
    get_class_props(Rest, Props).
get_class_props([method(_, _)|Rest], Props) :-
    get_class_props(Rest, Props).

% Get property value from instance
get_instance_prop(PropName, instance(_, Props), Value) :-
    member(prop(PropName, Value), Props), !.
get_instance_prop(PropName, _, _) :-
    format(user_error, "Error: Unknown property '~w'~n", [PropName]),
    fail.

% Set property value in instance, returns new instance
set_instance_prop(PropName, Value, instance(Class, Props), instance(Class, NewProps)) :-
    ( select(prop(PropName, _), Props, RestProps)
    -> NewProps = [prop(PropName, Value)|RestProps]
    ;  NewProps = [prop(PropName, Value)|Props]
    ).

%------------------------------------------------------------
% Method Lookup
%------------------------------------------------------------

% Find method implementation in class hierarchy
find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    get_procs(State, Procs),
    member(MethodImpl, Procs),
    MethodImpl = method_impl(ClassName, MethodName, _, _, _), !.
find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    % Not in this class, try parent
    get_class_def(ClassName, State, class_def(ClassName, ParentClass, _, _)),
    ParentClass \= none,
    find_method_impl(ParentClass, MethodName, State, MethodImpl).
find_method_impl(ClassName, MethodName, _, _) :-
    format(user_error, "Error: Method '~w.~w' not found~n", [ClassName, MethodName]),
    fail.

%------------------------------------------------------------
% Default Values
%------------------------------------------------------------

default_value('STRING', _, "").
default_value('CSTRING', _, "").
default_value('PSTRING', _, "").
default_value('LONG', _, 0).
default_value('SHORT', _, 0).
default_value('BYTE', _, 0).
default_value('DECIMAL', _, 0).
default_value('PDECIMAL', _, 0).
default_value('REAL', _, 0.0).
default_value('SREAL', _, 0.0).
default_value('DATE', _, 0).
default_value('TIME', _, 0).
default_value(_, _, 0).  % Default for unknown types
