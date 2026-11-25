%============================================================
% simulator_state.pl - State Management for Clarion Simulator
%
% Handles simulator state, variable access, and file state.
%============================================================

:- module(simulator_state, [
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
    bind_raw/4,
    alias_of/3,
    same_name/2,

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
% Implicit LONG variable (name ends in '#', e.g. SAV:ITM:EDIT_DATE#): never a
% file/group field, and reads as 0 before its first assignment.
% A by-reference parameter is an alias: read the variable it stands for
get_var(Name, State, Value) :-
    get_vars(State, Vars), alias_of(Name, Vars, Target), !,
    get_var(Target, State, Value).
get_var(Name, State, Value) :-
    implicit_long_name(Name), !,
    get_vars(State, Vars),
    ( memberchk(var(Name, V0), Vars) -> Value = V0 ; Value = 0 ).
get_var(Name, State, Value) :-
    ( parse_prefixed_name(Name, Prefix, FieldName),
      get_prefixed_var(Prefix, FieldName, State, Value)
    -> true
    ;  get_vars(State, Vars),
       ( member(var(Name, Value), Vars)
       ;  ci_var(Name, Vars, var(_, Value))
       )
    ), !.
% Implicit EQUATES.CLW constants, used only when no variable of that name exists
get_var(Name, _, Value) :-
    atom(Name), upcase_atom(Name, U), implicit_equate(U, Value), !.
get_var(Name, _, _) :-
    format(user_error, "Error: Undefined variable '~w'~n", [Name]),
    fail.

% Set variable value in state
% Handles both regular variables and prefixed file fields (Prefix:Field)
% Implicit LONG (Name#): plain variable, value truncated to an integer.
% ...and assignments to it write the aliased variable or record field
set_var(Name, Value, StateIn, StateOut) :-
    Value \= alias(_),
    get_vars(StateIn, Vars), memberchk(var(Name, alias(Target)), Vars), !,
    set_var(Target, Value, StateIn, StateOut).
set_var(Name, Value, StateIn, StateOut) :-
    implicit_long_name(Name), !,
    implicit_long_value(Value, Long),
    StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
    ( select(var(Name, _), Vars, RestVars) -> true ; RestVars = Vars ),
    StateOut = state([var(Name, Long)|RestVars], Procs, Out, Files, Err, Classes, Self, UI, Cont).
set_var(Name, Value, StateIn, StateOut) :-
    ( parse_prefixed_name(Name, Prefix, FieldName),
      set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut)
    -> true
    ;  StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
       ( select(var(Name, _), Vars, RestVars)
       -> NewVars = [var(Name, Value)|RestVars]
       ;  ci_var(Name, Vars, var(Existing, _)),
          select(var(Existing, _), Vars, RestVars)
       -> NewVars = [var(Existing, Value)|RestVars]
       ;  NewVars = [var(Name, Value)|Vars]
       ),
       StateOut = state(NewVars, Procs, Out, Files, Err, Classes, Self, UI, Cont)
    ).

%% Clarion names are case-insensitive. Lookups try the exact name first and
%% fall back to these (e.g. code that reads O:OPtionsMask for a parameter
%% declared as O:OptionsMask, or writes PRE:EDIT_DATE to a field Edit_Date).
same_name(A, A) :- !.
same_name(A, B) :- atom(A), atom(B), upcase_atom(A, U), upcase_atom(B, U).

ci_var(Name, Vars, var(N, V)) :-
    atom(Name), upcase_atom(Name, U),
    member(var(N, V), Vars), atom(N), upcase_atom(N, U), !.

field_index(FieldName, Fields, Index) :-
    nth0(Index, Fields, field(FieldName, _, _)), !.
field_index(FieldName, Fields, Index) :-
    nth0(Index, Fields, field(F, _, _)), same_name(FieldName, F), !.
% Group.Field (PRE:Edit_DtTm.Edit_Date): record groups are flattened, so use
% the last component
field_index(FieldName, Fields, Index) :-
    atom(FieldName), atomic_list_concat(Parts, '.', FieldName), Parts = [_, _|_],
    last(Parts, Last), field_index(Last, Fields, Index).

% Bind Name exactly (no prefix, alias or case-insensitive resolution)
bind_raw(Name, Value, state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
         state([var(Name, Value)|Rest], Procs, Out, Files, Err, Classes, Self, UI, Cont)) :-
    ( select(var(Name, _), Vars, Rest) -> true ; Rest = Vars ).

% alias_of(+Name, +Vars, -Target): Name is a by-reference parameter (exact
% name first, then case-insensitively, like every other lookup)
alias_of(Name, Vars, Target) :- memberchk(var(Name, alias(Target)), Vars), !.
alias_of(Name, Vars, Target) :-
    atom(Name), upcase_atom(Name, U),
    member(var(N, alias(Target)), Vars), atom(N), upcase_atom(N, U), !.

implicit_equate('TRUE', 1).
implicit_equate('FALSE', 0).

implicit_long_name(Name) :-
    atom(Name), sub_atom(Name, _, 1, 0, '#').

% Clarion LONG conversion: reals truncate toward zero, numeric text converts,
% anything else is 0.
implicit_long_value(V, L) :- integer(V), !, L = V.
implicit_long_value(V, L) :- number(V), !, L is truncate(V).
implicit_long_value(V, L) :-
    ( atom(V) ; string(V) ), !,
    ( normalize_space(atom(A), V), atom_number(A, N) -> L is truncate(N) ; L = 0 ).
implicit_long_value(_, 0).

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
        ( same_name(FieldName, 'Record')
        -> FileState = file_state(_, _, _, _, _, Value, _, _)
        ;  get_buffer_field(FieldName, FileState, Value)
        )
    ; get_file_state(Prefix, State, FileState) ->
        ( same_name(FieldName, 'Record')
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
        ( same_name(FieldName, 'Record')
        -> StateOut = StateIn
        ;  set_buffer_field(FieldName, Value, FileState, NewFileState),
           set_file_state(FileName, NewFileState, StateIn, StateOut)
        )
    ; get_file_state(Prefix, StateIn, FileState) ->
        ( same_name(FieldName, 'Record')
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
    replace_nth1(Idx, Values, Value, NewValues),
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
    ; % Clarion names are case-insensitive (lookup(...) calls Lookup)
      atom(Name),
      member(Proc, Procs), Proc = procedure(PName, _, _, _), same_name(Name, PName), !
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
get_file_state(Name, State, FileState) :-
    atom(Name),
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(N, _, _, _, _, _, _, _), same_name(Name, N), !.

set_file_state(Name, NewFileState,
               state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
               state(Vars, Procs, Out, NewFiles, Err, Classes, Self, UI, Cont)) :-
    % The stored name is canonical; Name may differ in case (add(item))
    NewFileState = file_state(CName, _, _, _, _, _, _, _),
    ( CName == Name -> true ; same_name(Name, CName) ),
    ( select(file_state(CName, _, _, _, _, _, _, _), Files, RestFiles)
    -> NewFiles = [NewFileState|RestFiles]
    ;  NewFiles = [NewFileState|Files]
    ).

find_file_by_prefix(Prefix, State, FileState) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(_, Prefix, _, _, _, _, _, _), !.
find_file_by_prefix(Prefix, State, FileState) :-
    atom(Prefix),
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(_, P, _, _, _, _, _, _), same_name(Prefix, P), !.

%------------------------------------------------------------
% Record Buffer Operations
%------------------------------------------------------------

get_buffer_field(FieldName, file_state(_, _, _, Fields, _, Buffer, _, _), Value) :-
    field_index(FieldName, Fields, Index),
    nth0(Index, Buffer, Value), !.
get_buffer_field(FieldName, _, _) :-
    format(user_error, "Error: Unknown field '~w'~n", [FieldName]),
    fail.

set_buffer_field(FieldName, Value,
                 file_state(Name, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
                 file_state(Name, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open)) :-
    field_index(FieldName, Fields, Index),
    replace_nth0(Index, Buffer, Value, NewBuffer), !.

create_empty_buffer([], []).
create_empty_buffer([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_empty_buffer(Rest, Values).

%------------------------------------------------------------
% Default Values
%------------------------------------------------------------

default_value(byref(T), Size, V) :- !, default_value(T, Size, V).
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

%------------------------------------------------------------
% List Utilities
%------------------------------------------------------------

replace_nth0(0, [_|T], X, [X|T]) :- !.
replace_nth0(N, [H|T], X, [H|R]) :-
    N > 0,
    N1 is N - 1,
    replace_nth0(N1, T, X, R).
