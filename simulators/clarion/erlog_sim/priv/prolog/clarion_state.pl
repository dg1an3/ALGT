%============================================================
% clarion_state.pl - State Management for Erlog Clarion Simulator
%
% State is a Prolog term — variables can be unbound (open).
% This enables backward execution via Prolog backtracking.
%
% Erlog-compatible: no modules, no dicts, ISO-standard predicates.
%============================================================

%------------------------------------------------------------
% State Structure
%------------------------------------------------------------
% state(Vars, Procs, Output, Files, Err, Classes, Self, UI, Cont)
%
% Vars    = [Name-Value | ...]   Values can be unbound Prolog variables!
% Procs   = [procedure(Name, Params, Locals, code(Body)) | routine(...) | ...]
% Output  = [Msg | ...]  (reversed — newest first)
% Files   = [file_state(Name, Prefix, Keys, Fields, Records, Buffer, Pos, IsOpen) | ...]
% Err     = integer (last error code)
% Classes = [class_def(Name, Parent, Attrs, Members) | ...]
% Self    = none | self_context(VarName, ImplClass, ParentClass)
% UI      = ui_state(Backend, Windows, EventQueue, CurrentEvent, Mode)
% Cont    = none | continuation(...)

empty_state(State) :-
    empty_ui_state(UI),
    State = state([], [], [], [], 0, [], none, UI, none).

empty_ui_state(ui_state(simulation, [], [], none, sync)).

%------------------------------------------------------------
% State Accessors
%------------------------------------------------------------

state_vars(state(V, _, _, _, _, _, _, _, _), V).
state_procs(state(_, P, _, _, _, _, _, _, _), P).
state_output(state(_, _, O, _, _, _, _, _, _), O).
state_files(state(_, _, _, F, _, _, _, _, _), F).
state_error(state(_, _, _, _, E, _, _, _, _), E).
state_classes(state(_, _, _, _, _, C, _, _, _), C).
state_self(state(_, _, _, _, _, _, S, _, _), S).
state_ui(state(_, _, _, _, _, _, _, U, _), U).
state_cont(state(_, _, _, _, _, _, _, _, K), K).

%------------------------------------------------------------
% State Setters (return new state)
%------------------------------------------------------------

set_state_vars(V, state(_, P, O, F, E, C, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_procs(P, state(V, _, O, F, E, C, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_output(O, state(V, P, _, F, E, C, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_files(F, state(V, P, O, _, E, C, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_error(E, state(V, P, O, F, _, C, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_classes(C, state(V, P, O, F, E, _, S, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_self(S, state(V, P, O, F, E, C, _, U, K), state(V, P, O, F, E, C, S, U, K)).
set_state_ui(U, state(V, P, O, F, E, C, S, _, K), state(V, P, O, F, E, C, S, U, K)).
set_state_cont(K, state(V, P, O, F, E, C, S, U, _), state(V, P, O, F, E, C, S, U, K)).

%------------------------------------------------------------
% UI State Accessors
%------------------------------------------------------------

ui_backend(ui_state(B, _, _, _, _), B).
ui_windows(ui_state(_, W, _, _, _), W).
ui_event_queue(ui_state(_, _, EQ, _, _), EQ).
ui_current_event(ui_state(_, _, _, CE, _), CE).
ui_mode(ui_state(_, _, _, _, M), M).

set_ui_event_queue(EQ, ui_state(B, W, _, CE, M), ui_state(B, W, EQ, CE, M)).
set_ui_current_event(CE, ui_state(B, W, EQ, _, M), ui_state(B, W, EQ, CE, M)).

%------------------------------------------------------------
% Variable Operations
%------------------------------------------------------------

% Get variable value from state
% Key feature: if Value is an unbound Prolog variable in the state,
% it stays unbound — this enables open-variable reasoning.
get_var(Name, State, Value) :-
    ( parse_prefixed_name(Name, Prefix, FieldName) ->
        get_prefixed_var(Prefix, FieldName, State, Value)
    ;   state_vars(State, Vars),
        assoc_get(Name, Vars, Value)
    ).

% Set variable value in state
set_var(Name, Value, StateIn, StateOut) :-
    ( parse_prefixed_name(Name, Prefix, FieldName) ->
        set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut)
    ;   state_vars(StateIn, Vars),
        assoc_set(Name, Value, Vars, NewVars),
        set_state_vars(NewVars, StateIn, StateOut)
    ).

%------------------------------------------------------------
% Association List Helpers
%------------------------------------------------------------

assoc_get(Key, [Key-Value|_], Value) :- !.
assoc_get(Key, [_|Rest], Value) :- assoc_get(Key, Rest, Value).

assoc_set(Key, Value, [], [Key-Value]).
assoc_set(Key, Value, [Key-_|Rest], [Key-Value|Rest]) :- !.
assoc_set(Key, Value, [Other|Rest], [Other|NewRest]) :-
    assoc_set(Key, Value, Rest, NewRest).

assoc_remove(_, [], []).
assoc_remove(Key, [Key-_|Rest], Rest) :- !.
assoc_remove(Key, [Other|Rest], [Other|NewRest]) :-
    assoc_remove(Key, Rest, NewRest).

%------------------------------------------------------------
% Prefixed Name Parsing (Prefix:Field or Prefix.Field)
%------------------------------------------------------------

parse_prefixed_name(Name, Prefix, FieldName) :-
    atom(Name),
    atom_codes(Name, Codes),
    append(PrefixCodes, [Sep|FieldCodes], Codes),
    (Sep =:= 58 ; Sep =:= 46),  % 58=':' 46='.'
    PrefixCodes \= [],
    FieldCodes \= [],
    !,
    atom_codes(Prefix, PrefixCodes),
    atom_codes(FieldName, FieldCodes).

%------------------------------------------------------------
% Prefixed Variable Access (file fields, group fields, instances)
%------------------------------------------------------------

get_prefixed_var(Prefix, FieldName, State, Value) :-
    ( find_file_by_prefix(Prefix, State, FileState) ->
        ( FieldName = 'Record' ->
            file_state_buffer(FileState, Value)
        ;   get_buffer_field(FieldName, FileState, Value)
        )
    ; get_file_state(Prefix, State, FileState) ->
        ( FieldName = 'Record' ->
            file_state_buffer(FileState, Value)
        ;   get_buffer_field(FieldName, FileState, Value)
        )
    ; state_vars(State, Vars),
      assoc_get(Prefix, Vars, instance(_, Props)) ->
        member(prop(FieldName, Value), Props)
    ; get_group_field_by_prefix(Prefix, FieldName, State, Value)
    ).

set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut) :-
    ( find_file_by_prefix(Prefix, StateIn, FileState) ->
        file_state_name(FileState, FileName),
        ( FieldName = 'Record' ->
            StateOut = StateIn
        ;   set_buffer_field(FieldName, Value, FileState, NewFS),
            set_file_state(FileName, NewFS, StateIn, StateOut)
        )
    ; get_file_state(Prefix, StateIn, FileState) ->
        ( FieldName = 'Record' ->
            StateOut = StateIn
        ;   set_buffer_field(FieldName, Value, FileState, NewFS),
            set_file_state(Prefix, NewFS, StateIn, StateOut)
        )
    ; state_vars(StateIn, Vars),
      assoc_get(Prefix, Vars, instance(Class, Props)) ->
        ( list_select(prop(FieldName, _), Props, RestProps) ->
            NewProps = [prop(FieldName, Value)|RestProps]
        ;   NewProps = [prop(FieldName, Value)|Props]
        ),
        set_var(Prefix, instance(Class, NewProps), StateIn, StateOut)
    ; set_group_field_by_prefix(Prefix, FieldName, Value, StateIn, StateOut)
    ).

%------------------------------------------------------------
% Group Field Access
%------------------------------------------------------------

get_group_field_by_prefix(Prefix, FieldName, State, Value) :-
    state_vars(State, Vars),
    assoc_get(group_prefix(Prefix), Vars, GroupName),
    assoc_get(GroupName, Vars, group_val(Prefix, Fields, Values)),
    nth1_field_index(FieldName, Fields, Idx),
    nth1_list(Idx, Values, Value).

set_group_field_by_prefix(Prefix, FieldName, Value, StateIn, StateOut) :-
    state_vars(StateIn, Vars),
    assoc_get(group_prefix(Prefix), Vars, GroupName),
    assoc_get(GroupName, Vars, group_val(Prefix, Fields, Values)),
    nth1_field_index(FieldName, Fields, Idx),
    replace_nth1(Idx, Values, Value, NewValues),
    set_var(GroupName, group_val(Prefix, Fields, NewValues), StateIn, StateOut).

set_group_field(FieldName, Value, Fields, Values, NewValues) :-
    nth0_field_index(FieldName, Fields, Idx),
    replace_nth0(Idx, Values, Value, NewValues), !.
set_group_field(_, _, _, Values, Values).

get_group_field(FieldName, Fields, Values, Value) :-
    nth0_field_index(FieldName, Fields, Idx),
    nth0_list(Idx, Values, Value), !.
get_group_field(_, _, _, 0).

nth1_field_index(FieldName, Fields, Idx) :-
    nth1_field_index_(FieldName, Fields, 1, Idx).
nth1_field_index_(FieldName, [field(FieldName, _, _)|_], N, N) :- !.
nth1_field_index_(FieldName, [_|Rest], N, Idx) :-
    N1 is N + 1,
    nth1_field_index_(FieldName, Rest, N1, Idx).

nth0_field_index(FieldName, Fields, Idx) :-
    nth0_field_index_(FieldName, Fields, 0, Idx).
nth0_field_index_(FieldName, [field(FieldName, _, _)|_], N, N) :- !.
nth0_field_index_(FieldName, [_|Rest], N, Idx) :-
    N1 is N + 1,
    nth0_field_index_(FieldName, Rest, N1, Idx).

%------------------------------------------------------------
% Procedure Lookup
%------------------------------------------------------------

get_proc(Name, State, Proc) :-
    state_procs(State, Procs),
    member(Proc, Procs),
    Proc = procedure(Name, _, _, _), !.
get_proc(Name, State, Proc) :-
    resolve_name_alias(Name, State, ClarionName),
    state_procs(State, Procs),
    member(Proc, Procs),
    Proc = procedure(ClarionName, _, _, _), !.

%------------------------------------------------------------
% MAP Prototype Operations
%------------------------------------------------------------

get_map_protos(State, Protos) :-
    state_vars(State, Vars),
    ( assoc_get('__MAP_PROTOS__', Vars, Protos) -> true ; Protos = [] ).

get_map_proto(Name, State, Proto) :-
    get_map_protos(State, Protos),
    ( member(Proto, Protos),
      ( Proto = map_proto(Name, _, _, _)
      ; Proto = external_proc(Name, _, _, _, _)
      ), !
    ; member(Proto, Protos),
      ( Proto = map_proto(_, _, _, Attrs)
      ; Proto = external_proc(_, _, _, _, Attrs)
      ),
      member(name(Name), Attrs), !
    ).

is_external_proc(Name, State) :-
    get_map_protos(State, Protos),
    ( member(external_proc(Name, _, _, _, _), Protos), !
    ; member(external_proc(_, _, _, _, Attrs), Protos),
      member(name(Name), Attrs), !
    ).

resolve_name_alias(AliasName, State, ClarionName) :-
    get_map_protos(State, Protos),
    member(Proto, Protos),
    ( Proto = map_proto(ClarionName, _, _, Attrs)
    ; Proto = external_proc(ClarionName, _, _, _, Attrs)
    ),
    member(name(AliasName), Attrs), !.

%------------------------------------------------------------
% Output Management
%------------------------------------------------------------

add_output(Text, StateIn, StateOut) :-
    state_output(StateIn, Out),
    set_state_output([Text|Out], StateIn, StateOut).

get_output_list(State, Output) :-
    state_output(State, Out),
    reverse(Out, Output).

%------------------------------------------------------------
% File State Management
%------------------------------------------------------------

% file_state(Name, Prefix, Keys, Fields, Records, Buffer, Position, IsOpen)

file_state_name(file_state(N, _, _, _, _, _, _, _), N).
file_state_prefix(file_state(_, P, _, _, _, _, _, _), P).
file_state_keys(file_state(_, _, K, _, _, _, _, _), K).
file_state_fields(file_state(_, _, _, F, _, _, _, _), F).
file_state_records(file_state(_, _, _, _, R, _, _, _), R).
file_state_buffer(file_state(_, _, _, _, _, B, _, _), B).
file_state_position(file_state(_, _, _, _, _, _, P, _), P).
file_state_is_open(file_state(_, _, _, _, _, _, _, O), O).

get_file_state(Name, State, FileState) :-
    state_files(State, Files),
    member(FileState, Files),
    file_state_name(FileState, Name), !.

set_file_state(Name, NewFS, StateIn, StateOut) :-
    state_files(StateIn, Files),
    ( list_select_file(Name, Files, RestFiles) ->
        NewFiles = [NewFS|RestFiles]
    ;   NewFiles = [NewFS|Files]
    ),
    set_state_files(NewFiles, StateIn, StateOut).

list_select_file(Name, [file_state(Name, _, _, _, _, _, _, _)|Rest], Rest) :- !.
list_select_file(Name, [H|T], [H|Rest]) :- list_select_file(Name, T, Rest).

find_file_by_prefix(Prefix, State, FileState) :-
    state_files(State, Files),
    member(FileState, Files),
    file_state_prefix(FileState, Prefix), !.

%------------------------------------------------------------
% Record Buffer Operations
%------------------------------------------------------------

get_buffer_field(FieldName, FileState, Value) :-
    file_state_fields(FileState, Fields),
    file_state_buffer(FileState, Buffer),
    nth0_field_index(FieldName, Fields, Idx),
    nth0_list(Idx, Buffer, Value), !.

set_buffer_field(FieldName, Value, FileState, NewFS) :-
    FileState = file_state(Name, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
    nth0_field_index(FieldName, Fields, Idx),
    replace_nth0(Idx, Buffer, Value, NewBuffer),
    NewFS = file_state(Name, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open).

create_empty_buffer([], []).
create_empty_buffer([field(_, Type, _)|Rest], [Value|Values]) :-
    default_value(Type, Value),
    create_empty_buffer(Rest, Values).

clear_buffer(FileState, NewFS) :-
    FileState = file_state(Name, Prefix, Keys, Fields, Records, _, Pos, Open),
    create_empty_buffer(Fields, NewBuffer),
    NewFS = file_state(Name, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open).

%------------------------------------------------------------
% Default Values
%------------------------------------------------------------

default_value('STRING', "").
default_value('CSTRING', "").
default_value('PSTRING', "").
default_value('LONG', 0).
default_value('SHORT', 0).
default_value('BYTE', 0).
default_value('DECIMAL', 0).
default_value('PDECIMAL', 0).
default_value('REAL', 0.0).
default_value('SREAL', 0.0).
default_value('DATE', 0).
default_value('TIME', 0).
default_value('void', 0).
default_value(_, 0).

% 3-arity version for compatibility with bridge output
default_value_3(Type, _, Value) :- default_value(Type, Value).

%------------------------------------------------------------
% List Utilities
%------------------------------------------------------------

list_select(Elem, [Elem|Rest], Rest).
list_select(Elem, [H|T], [H|Rest]) :- list_select(Elem, T, Rest).

nth0_list(0, [H|_], H) :- !.
nth0_list(N, [_|T], Elem) :- N > 0, N1 is N - 1, nth0_list(N1, T, Elem).

nth1_list(1, [H|_], H) :- !.
nth1_list(N, [_|T], Elem) :- N > 1, N1 is N - 1, nth1_list(N1, T, Elem).

replace_nth0(0, [_|T], X, [X|T]) :- !.
replace_nth0(N, [H|T], X, [H|R]) :-
    N > 0, N1 is N - 1,
    replace_nth0(N1, T, X, R).

replace_nth1(1, [_|T], X, [X|T]) :- !.
replace_nth1(N, [H|T], X, [H|R]) :-
    N > 1, N1 is N - 1,
    replace_nth1(N1, T, X, R).

%------------------------------------------------------------
% Event Phase Management
%------------------------------------------------------------

set_event_phase(Phase, StateIn, StateOut) :-
    set_var('__EVENT_PHASE__', Phase, StateIn, StateOut).

get_event_phase(State, Phase) :-
    ( get_var('__EVENT_PHASE__', State, Phase) -> true ; Phase = none ).
