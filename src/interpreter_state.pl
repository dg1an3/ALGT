%============================================================
% interpreter_state.pl - State Management for Clarion Interpreter
%
% Handles interpreter state, variable access, and file state.
%============================================================

:- module(interpreter_state, [
    % State creation
    empty_state/1,

    % State accessors
    get_vars/2,
    get_procs/2,
    get_output/2,
    get_files/2,
    get_error/2,
    get_classes/2,
    get_self/2,

    % Variable operations
    get_var/3,
    set_var/4,

    % Procedure lookup
    get_proc/3,

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
% state(Vars, Procs, Output, Files, ErrorCode, Classes, Self)

empty_state(state([], [], [], [], 0, [], none)).

% State accessors
get_vars(state(Vars, _, _, _, _, _, _), Vars).
get_procs(state(_, Procs, _, _, _, _, _), Procs).
get_output(state(_, _, Out, _, _, _, _), Out).
get_files(state(_, _, _, Files, _, _, _), Files).
get_error(state(_, _, _, _, Err, _, _), Err).
get_classes(state(_, _, _, _, _, Classes, _), Classes).
get_self(state(_, _, _, _, _, _, Self), Self).

%------------------------------------------------------------
% Variable Operations
%------------------------------------------------------------

% Get variable value from state
% Handles both regular variables and prefixed file fields (Prefix:Field)
get_var(Name, State, Value) :-
    ( parse_prefixed_name(Name, Prefix, FieldName)
    -> get_prefixed_var(Prefix, FieldName, State, Value)
    ;  get_vars(State, Vars),
       member(var(Name, Value), Vars)
    ), !.
get_var(Name, _, _) :-
    format(user_error, "Error: Undefined variable '~w'~n", [Name]),
    fail.

% Set variable value in state
% Handles both regular variables and prefixed file fields (Prefix:Field)
set_var(Name, Value, StateIn, StateOut) :-
    ( parse_prefixed_name(Name, Prefix, FieldName)
    -> set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut)
    ;  StateIn = state(Vars, Procs, Out, Files, Err, Classes, Self),
       ( select(var(Name, _), Vars, RestVars)
       -> NewVars = [var(Name, Value)|RestVars]
       ;  NewVars = [var(Name, Value)|Vars]
       ),
       StateOut = state(NewVars, Procs, Out, Files, Err, Classes, Self)
    ).

% Parse a prefixed name like 'Cust:CustomerID' into prefix and field
parse_prefixed_name(Name, Prefix, FieldName) :-
    atom(Name),
    atom_string(Name, NameStr),
    sub_string(NameStr, Before, 1, After, ":"),
    Before > 0, After > 0,
    sub_string(NameStr, 0, Before, _, PrefixStr),
    ColonPos is Before + 1,
    sub_string(NameStr, ColonPos, After, 0, FieldStr),
    atom_string(Prefix, PrefixStr),
    atom_string(FieldName, FieldStr).

% Get value of prefixed variable (file field)
get_prefixed_var(Prefix, FieldName, State, Value) :-
    find_file_by_prefix(Prefix, State, FileState),
    ( FieldName = 'Record'
    -> FileState = file_state(_, _, _, _, _, Value, _, _)  % Return whole buffer
    ;  get_buffer_field(FieldName, FileState, Value)
    ).

% Set value of prefixed variable (file field)
set_prefixed_var(Prefix, FieldName, Value, StateIn, StateOut) :-
    find_file_by_prefix(Prefix, StateIn, FileState),
    FileState = file_state(FileName, _, _, _, _, _, _, _),
    ( FieldName = 'Record'
    -> % Can't directly set whole record this way
       StateOut = StateIn
    ;  set_buffer_field(FieldName, Value, FileState, NewFileState),
       set_file_state(FileName, NewFileState, StateIn, StateOut)
    ).

%------------------------------------------------------------
% Procedure Lookup
%------------------------------------------------------------

get_proc(Name, State, Proc) :-
    get_procs(State, Procs),
    member(Proc, Procs),
    Proc = procedure(Name, _, _, _), !.
get_proc(Name, _, _) :-
    format(user_error, "Error: Undefined procedure '~w'~n", [Name]),
    fail.

%------------------------------------------------------------
% Output Management
%------------------------------------------------------------

add_output(Text, state(Vars, Procs, Out, Files, Err, Classes, Self),
                 state(Vars, Procs, [Text|Out], Files, Err, Classes, Self)).

get_output_list(State, Output) :-
    get_output(State, Out),
    reverse(Out, Output).

%------------------------------------------------------------
% Error and Self Context
%------------------------------------------------------------

set_error(ErrCode, state(Vars, Procs, Out, Files, _, Classes, Self),
                   state(Vars, Procs, Out, Files, ErrCode, Classes, Self)).

set_self(NewSelf, state(Vars, Procs, Out, Files, Err, Classes, _),
                  state(Vars, Procs, Out, Files, Err, Classes, NewSelf)).

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
               state(Vars, Procs, Out, Files, Err, Classes, Self),
               state(Vars, Procs, Out, NewFiles, Err, Classes, Self)) :-
    NewFileState = file_state(Name, _, _, _, _, _, _, _),
    ( select(file_state(Name, _, _, _, _, _, _, _), Files, RestFiles)
    -> NewFiles = [NewFileState|RestFiles]
    ;  NewFiles = [NewFileState|Files]
    ).

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
    nth0(Index, Fields, field(FieldName, _, _)),
    replace_nth0(Index, Buffer, Value, NewBuffer), !.

create_empty_buffer([], []).
create_empty_buffer([field(_, Type, Size)|Rest], [Value|Values]) :-
    default_value(Type, Size, Value),
    create_empty_buffer(Rest, Values).

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
