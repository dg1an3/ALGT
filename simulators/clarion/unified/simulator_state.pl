%============================================================
% simulator_state.pl - State Management for Clarion Simulator
%
% Handles simulator state, variable access, and file state.
%============================================================

:- module(simulator_state, [
    declare_type/4,
    declared_type/4,
    get_cursor/3,
    set_cursor/4,
    is_queue/2,
    % State creation
    empty_state/1,
    empty_ui_state/1,

    % State accessors
    get_vars/2,
    get_procs/2,
    get_output/2,
    get_files/2,
    get_error/2,
    get_classes/2,
    get_self/2,
    get_ui_state/2,
    get_continuation/2,

    % State setters
    set_ui_state/3,
    set_continuation/3,
    clear_continuation/2,

    % Variable operations
    get_var/3,
    set_var/4,

    % Procedure lookup
    get_proc/3,

    % MAP prototype operations
    get_map_protos/2,
    get_map_proto/3,
    is_external_proc/2,
    resolve_name_alias/3,

    % Output
    add_output/3,
    get_output_list/2,

    % Error handling
    set_error/3,

    % Self context (for methods)
    set_self/3,

    % File state operations
    get_file_state/3,
    set_file_state/4,
    find_file_by_prefix/3,

    % Buffer operations
    get_buffer_field/3,
    set_buffer_field/4,
    create_empty_buffer/2,

    % Prefixed name parsing
    parse_prefixed_name/3,

    % List utilities
    replace_nth0/4
]).

:- use_module(clarion_types).

%------------------------------------------------------------
% State Structure
%------------------------------------------------------------
% state(Vars, Procs, Output, Files, ErrorCode, Classes, Self, UIState, Continuation)
%
% Extended state with UI and continuation support:
%   - UIState: UI backend state (window stack, event queue, mode)
%   - Continuation: For pausable ACCEPT loop (none or continuation{...})

empty_state(state([], [], [], [], 0, [], none, UIState, none)) :-
    empty_ui_state(UIState).

% UI State structure (SWI-Prolog dict):
% ui_state{
%     backend: atom,              % simulation | tui | remote
%     windows: [window_state{}],  % Stack of open windows
%     event_queue: [],            % Pending events (FIFO)
%     current_event: none,        % Event being processed
%     mode: sync | async          % Execution mode
% }

empty_ui_state(ui_state{
    backend: simulation,
    windows: [],
    event_queue: [],
    current_event: none,
    mode: sync
}).

% State accessors (9-tuple)
get_vars(state(Vars, _, _, _, _, _, _, _, _), Vars).
get_procs(state(_, Procs, _, _, _, _, _, _, _), Procs).
get_output(state(_, _, Out, _, _, _, _, _, _), Out).
get_files(state(_, _, _, Files, _, _, _, _, _), Files).
get_error(state(_, _, _, _, Err, _, _, _, _), Err).
get_classes(state(_, _, _, _, _, Classes, _, _, _), Classes).
get_self(state(_, _, _, _, _, _, Self, _, _), Self).
get_ui_state(state(_, _, _, _, _, _, _, UIState, _), UIState).
get_continuation(state(_, _, _, _, _, _, _, _, Cont), Cont).

% UI State and Continuation setters
set_ui_state(NewUIState,
    state(Vars, Procs, Out, Files, Err, Classes, Self, _, Cont),
    state(Vars, Procs, Out, Files, Err, Classes, Self, NewUIState, Cont)).

set_continuation(NewCont,
    state(Vars, Procs, Out, Files, Err, Classes, Self, UI, _),
    state(Vars, Procs, Out, Files, Err, Classes, Self, UI, NewCont)).

clear_continuation(StateIn, StateOut) :-
    set_continuation(none, StateIn, StateOut).

%------------------------------------------------------------
% Variable Operations
%------------------------------------------------------------

% Get variable value from state
% Handles both regular variables and prefixed file fields (Prefix:Field)
% A colon name whose prefix matches no file, group or instance (e.g. the
% label 'Copy:Record' or the equate 'NT::THIS_MODULE') is a plain variable.
get_var(Name, State, Value) :-
    ( parse_prefixed_name(Name, Prefix, FieldName),
      get_prefixed_var(Prefix, FieldName, State, Value)
    -> true
    ;  get_vars(State, Vars),
       member(var(Name, Value), Vars)
    ), !.
get_var(Name, _, _) :-
    format(user_error, "Error: Undefined variable '~w'~n", [Name]),
    fail.

% Set variable value in state
% Handles both regular variables and prefixed file fields (Prefix:Field)
set_var(Name, Value, StateIn, StateOut) :-
    ( parse_prefixed_name(Name, Prefix, FieldName),
      set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut)
    -> true
    ;  StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
       ( atom(Name), memberchk(var('$type'(Name), type(Type, Size)), Vars)
       -> coerce(Type, Size, Value, Stored)
       ;  Stored = Value
       ),
       ( selectchk(var(Name, _), Vars, RestVars)
       -> NewVars = [var(Name, Stored)|RestVars]
       ;  NewVars = [var(Name, Stored)|Vars]
       ),
       StateOut = state(NewVars, Procs, Out, Files, Err, Classes, Self, UI, Cont)
    ).

%% declare_type(+Name, +TypeTerm, +StateIn, -StateOut)
%  Values later assigned to Name are converted to this type.
declare_type(Name, TypeTerm, StateIn, StateOut) :-
    split_type(TypeTerm, Type, Size),
    ( atom(Type)
    -> set_var('$type'(Name), type(Type, Size), StateIn, StateOut)
    ;  StateOut = StateIn          % LIKE(...) and classes: not resolved
    ).

declared_type(Name, State, Type, Size) :-
    get_vars(State, Vars),
    memberchk(var('$type'(Name), type(Type, Size)), Vars).

% Parse a prefixed name like 'Cust:CustomerID' or 'Queue.Field' into prefix and field
parse_prefixed_name(Name, Prefix, FieldName) :-
    atom(Name),
    atom_string(Name, NameStr),
    ( sub_string(NameStr, Before, 1, After, ":")
    ; sub_string(NameStr, Before, 1, After, ".")
    ),
    Before > 0, After > 0, !,
    sub_string(NameStr, 0, Before, _, PrefixStr),
    SepPos is Before + 1,
    sub_string(NameStr, SepPos, After, 0, FieldStr),
    atom_string(Prefix, PrefixStr),
    atom_string(FieldName, FieldStr).

% Get value of prefixed variable (file field, group field, or instance property)
% Tries: file by prefix (colon), then file/queue by name (dot), then instance, then group
get_prefixed_var(Prefix, FieldName, State, Value) :-
    ( find_file_by_prefix(Prefix, State, FileState) ->
        ( FieldName = 'Record'
        -> FileState = file_state(_, _, _, _, _, Value, _, _)
        ;  get_buffer_field(FieldName, FileState, Value)
        )
    ; get_file_state(Prefix, State, FileState) ->
        ( FieldName = 'Record'
        -> FileState = file_state(_, _, _, _, _, Value, _, _)
        ;  get_buffer_field(FieldName, FileState, Value)
        )
    ; get_vars(State, Vars), member(var(Prefix, instance(_, Props)), Vars) ->
        member(prop(FieldName, Value), Props)
    ; get_group_field(Prefix, FieldName, State, Value)
    ).

% Set value of prefixed variable (file field, group field, or instance property)
% Tries: file by prefix (colon), then file/queue by name (dot), then instance, then group
set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut) :-
    ( find_file_by_prefix(Prefix, StateIn, FileState) ->
        FileState = file_state(FileName, _, _, _, _, _, _, _),
        ( FieldName = 'Record'
        -> StateOut = StateIn
        ;  set_buffer_field(FieldName, Value, FileState, NewFileState),
           set_file_state(FileName, NewFileState, StateIn, StateOut)
        )
    ; get_file_state(Prefix, StateIn, FileState) ->
        ( FieldName = 'Record'
        -> StateOut = StateIn
        ;  set_buffer_field(FieldName, Value, FileState, NewFileState),
           set_file_state(Prefix, NewFileState, StateIn, StateOut)
        )
    ; get_vars(StateIn, Vars), member(var(Prefix, instance(Class, Props)), Vars) ->
        ( select(prop(FieldName, _), Props, RestProps)
        -> NewProps = [prop(FieldName, Value)|RestProps]
        ;  NewProps = [prop(FieldName, Value)|Props]
        ),
        set_var(Prefix, instance(Class, NewProps), StateIn, StateOut)
    ; set_group_field_by_prefix(Prefix, FieldName, Value, StateIn, StateOut)
    ).

% Group field access by prefix
get_group_field(Prefix, FieldName, State, Value) :-
    get_vars(State, Vars),
    member(var(group_prefix(Prefix), GroupName), Vars),
    member(var(GroupName, group_val(Prefix, Fields, Values)), Vars),
    nth1_field_index(FieldName, Fields, Idx),
    nth1(Idx, Values, Value).

set_group_field_by_prefix(Prefix, FieldName, Value, StateIn, StateOut) :-
    get_vars(StateIn, Vars),
    member(var(group_prefix(Prefix), GroupName), Vars),
    member(var(GroupName, group_val(Prefix, Fields, Values)), Vars),
    nth1_field_index(FieldName, Fields, Idx),
    nth1(Idx, Fields, field(_, Type, Size)),
    coerce(Type, Size, Value, Stored),
    replace_nth1(Idx, Values, Stored, NewValues),
    set_var(GroupName, group_val(Prefix, Fields, NewValues), StateIn, StateOut).

nth1_field_index(FieldName, Fields, Idx) :-
    nth1_field_index_(FieldName, Fields, 1, Idx).
nth1_field_index_(FieldName, [field(FieldName, _, _)|_], N, N) :- !.
nth1_field_index_(FieldName, [_|Rest], N, Idx) :-
    N1 is N + 1,
    nth1_field_index_(FieldName, Rest, N1, Idx).

replace_nth1(1, [_|Rest], Value, [Value|Rest]) :- !.
replace_nth1(N, [H|T], Value, [H|NewT]) :-
    N > 1, N1 is N - 1,
    replace_nth1(N1, T, Value, NewT).

%------------------------------------------------------------
% Procedure Lookup
%------------------------------------------------------------

get_proc(Name, State, Proc) :-
    get_procs(State, Procs),
    ( member(Proc, Procs), Proc = procedure(Name, _, _, _), !
    ; % Try NAME alias: look up the alias in MAP protos, find the Clarion name
      resolve_name_alias(Name, State, ClarionName),
      member(Proc, Procs), Proc = procedure(ClarionName, _, _, _), !
    ).
get_proc(Name, _, _) :-
    format(user_error, "Error: Undefined procedure '~w'~n", [Name]),
    fail.

%------------------------------------------------------------
% MAP Prototype Operations
%------------------------------------------------------------

% Get all MAP prototypes from state
get_map_protos(State, Protos) :-
    get_vars(State, Vars),
    ( member(var('__MAP_PROTOS__', Protos), Vars) -> true ; Protos = [] ).

% Get MAP prototype by name (tries direct name, then NAME alias)
get_map_proto(Name, State, Proto) :-
    get_map_protos(State, Protos),
    ( member(Proto, Protos),
      ( Proto = map_proto(Name, _, _, _)
      ; Proto = external_proc(Name, _, _, _, _)
      ), !
    ; % Try finding by NAME alias
      member(Proto, Protos),
      ( Proto = map_proto(_, _, _, Attrs)
      ; Proto = external_proc(_, _, _, _, Attrs)
      ),
      member(name(Name), Attrs), !
    ).

% Check if a procedure name refers to an external (MODULE) procedure
is_external_proc(Name, State) :-
    get_map_protos(State, Protos),
    ( member(external_proc(Name, _, _, _, _), Protos), !
    ; % Check by NAME alias
      member(external_proc(_, _, _, _, Attrs), Protos),
      member(name(Name), Attrs), !
    ).

% Resolve a NAME alias to the Clarion procedure name
% E.g., NAME('RtlMoveMemory') on MemCopy -> resolves 'RtlMoveMemory' to 'MemCopy'
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

add_output(Text, state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
                 state(Vars, Procs, [Text|Out], Files, Err, Classes, Self, UI, Cont)).

get_output_list(State, Output) :-
    get_output(State, Out),
    reverse(Out, Output).

%------------------------------------------------------------
% Error and Self Context
%------------------------------------------------------------

set_error(ErrCode, state(Vars, Procs, Out, Files, _, Classes, Self, UI, Cont),
                   state(Vars, Procs, Out, Files, ErrCode, Classes, Self, UI, Cont)).

set_self(NewSelf, state(Vars, Procs, Out, Files, Err, Classes, _, UI, Cont),
                  state(Vars, Procs, Out, Files, Err, Classes, NewSelf, UI, Cont)).

%------------------------------------------------------------
% File State Management
%------------------------------------------------------------

% File state structure:
% file_state(Name, Prefix, Keys, Fields, Records, Buffer, Position, IsOpen)

get_file_state(Name, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(Name, _, _, _, _, _, _, _), !.

set_file_state(Name, NewFileState,
               state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
               state(Vars, Procs, Out, NewFiles, Err, Classes, Self, UI, Cont)) :-
    NewFileState = file_state(Name, _, _, _, _, _, _, _),
    ( select(file_state(Name, _, _, _, _, _, _, _), Files, RestFiles)
    -> NewFiles = [NewFileState|RestFiles]
    ;  NewFiles = [NewFileState|Files]
    ).

% Sequential position, kept with the files so it survives procedure return:
% cursor(Key, At). Key is none (record order) or a key name. At is start,
% from(KeyValues) or at(KeyValues, RecordIndex).
get_cursor(File, State, Cursor) :-
    get_files(State, Files),
    ( memberchk(file_cursor(File, Cursor0), Files) -> Cursor = Cursor0 ; Cursor = cursor(none, start) ).

set_cursor(File, Cursor,
           state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
           state(Vars, Procs, Out, NewFiles, Err, Classes, Self, UI, Cont)) :-
    ( selectchk(file_cursor(File, _), Files, Rest) -> true ; Rest = Files ),
    append(Rest, [file_cursor(File, Cursor)], NewFiles).

is_queue(Name, State) :-
    get_vars(State, Vars),
    \+ memberchk(var(file_driver(Name), _), Vars).

find_file_by_prefix(Prefix, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(_, Prefix, _, _, _, _, _, _), !.

%------------------------------------------------------------
% Record Buffer Operations
%------------------------------------------------------------

get_buffer_field(FieldName, file_state(_, _, _, Fields, _, Buffer, _, _), Value) :-
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Buffer, Value), !.
get_buffer_field(FieldName, _, _) :-
    format(user_error, "Error: Unknown field '~w'~n", [FieldName]),
    fail.

set_buffer_field(FieldName, Value,
                 file_state(Name, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
                 file_state(Name, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open)) :-
    nth0(Index, Fields, field(FieldName, Type, Size)),
    coerce(Type, Size, Value, Stored),
    replace_nth0(Index, Buffer, Stored, NewBuffer), !.

create_empty_buffer([], []).
create_empty_buffer([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_empty_buffer(Rest, Values).

%------------------------------------------------------------
% Default Values
%------------------------------------------------------------

default_value(Type, Size, Value) :- type_default(Type, Size, Value).

%------------------------------------------------------------
% List Utilities
%------------------------------------------------------------

replace_nth0(0, [_|T], X, [X|T]) :- !.
replace_nth0(N, [H|T], X, [H|R]) :-
    N > 0,
    N1 is N - 1,
    replace_nth0(N1, T, X, R).
