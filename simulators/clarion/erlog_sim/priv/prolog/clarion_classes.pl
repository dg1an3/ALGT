%============================================================
% clarion_classes.pl - Class and Instance Management
%
% Handles class definitions, instance creation, property access,
% and method lookup with inheritance chain walking.
%
% Erlog-compatible: no modules, no dicts, ISO-standard.
%============================================================

%------------------------------------------------------------
% Class Definition Management
%------------------------------------------------------------

% Initialize a class definition in state
init_class(Name, Parent, Attrs, Members, StateIn, StateOut) :-
    state_classes(StateIn, Classes),
    ClassDef = class_def(Name, Parent, Attrs, Members),
    set_state_classes([ClassDef|Classes], StateIn, StateOut).

% Get class definition by name
get_class_def(ClassName, State, ClassDef) :-
    state_classes(State, Classes),
    member(ClassDef, Classes),
    ClassDef = class_def(ClassName, _, _, _), !.

%------------------------------------------------------------
% Instance Management
%------------------------------------------------------------

% Create a new instance with default property values
create_instance(ClassName, State, instance(ClassName, Props)) :-
    get_class_def(ClassName, State, class_def(ClassName, Parent, _, Members)),
    ( Parent \= none ->
        get_inherited_props(Parent, State, InheritedProps)
    ;   InheritedProps = []
    ),
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
get_class_props([property(Name, Type, _Size)|Rest], [prop(Name, Default)|Props]) :-
    default_value(Type, Default),
    get_class_props(Rest, Props).
get_class_props([method(_, _, _, _)|Rest], Props) :-
    get_class_props(Rest, Props).
get_class_props([method(_, _)|Rest], Props) :-
    get_class_props(Rest, Props).

% Get property value from instance
get_instance_prop(PropName, instance(_, Props), Value) :-
    member(prop(PropName, Value), Props), !.

% Set property value in instance, returns new instance
set_instance_prop(PropName, Value, instance(Class, Props), instance(Class, NewProps)) :-
    ( list_select(prop(PropName, _), Props, RestProps) ->
        NewProps = [prop(PropName, Value)|RestProps]
    ;   NewProps = [prop(PropName, Value)|Props]
    ).

%------------------------------------------------------------
% Method Lookup (walks inheritance chain)
%------------------------------------------------------------

find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    state_procs(State, Procs),
    member(MethodImpl, Procs),
    MethodImpl = method_impl(ClassName, MethodName, _, _, _), !.
find_method_impl(ClassName, MethodName, State, MethodImpl) :-
    get_class_def(ClassName, State, class_def(ClassName, ParentClass, _, _)),
    ParentClass \= none,
    find_method_impl(ParentClass, MethodName, State, MethodImpl).
