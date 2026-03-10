%============================================================
% interpreter_builtins.pl - Built-in Functions
%
% Implements Clarion built-in functions: string functions,
% file I/O operations, and window event functions.
%============================================================

:- module(interpreter_builtins, [
    builtin_call/5,
    error_message/2,
    get_event_phase/2,
    set_event_phase/3
]).

:- use_module(interpreter_state).
:- use_module(interpreter_eval).

:- discontiguous builtin_call/5.

%------------------------------------------------------------
% String Functions
%------------------------------------------------------------

% MESSAGE(text) or MESSAGE(text, title)
builtin_call('MESSAGE', Args, StateIn, StateOut, none) :-
    ( Args = [TextExpr]
    -> eval_expr(TextExpr, StateIn, Text),
       format("MESSAGE: ~w~n", [Text])
    ; Args = [TextExpr, TitleExpr]
    -> eval_expr(TextExpr, StateIn, Text),
       eval_expr(TitleExpr, StateIn, Title),
       format("MESSAGE [~w]: ~w~n", [Title, Text])
    ; Args = [TextExpr, TitleExpr | _Rest]
    -> eval_expr(TextExpr, StateIn, Text),
       eval_expr(TitleExpr, StateIn, Title),
       format("MESSAGE [~w]: ~w~n", [Title, Text])
    ),
    add_output(message(Text), StateIn, StateOut).

% CLIP(string) - remove trailing spaces
builtin_call('CLIP', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_string(Str, S) ; S = Str ),
    string_codes(S, Codes),
    reverse(Codes, Rev),
    drop_spaces(Rev, TrimmedRev),
    reverse(TrimmedRev, Trimmed),
    string_codes(Result, Trimmed).

drop_spaces([32|Rest], Result) :- !, drop_spaces(Rest, Result).
drop_spaces(List, List).

% LEN(string) - string length
builtin_call('LEN', [Expr], StateIn, StateIn, Len) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_length(Str, Len) ; string_length(Str, Len) ).

% CHR(code) - character from code
builtin_call('CHR', [Expr], StateIn, StateIn, Char) :-
    eval_expr(Expr, StateIn, Code),
    char_code(Char, Code).

% VAL(char) - code from character
builtin_call('VAL', [Expr], StateIn, StateIn, Code) :-
    eval_expr(Expr, StateIn, Char),
    ( atom(Char) -> atom_codes(Char, [Code|_]) ; string_codes(Char, [Code|_]) ).

% TODAY() - current date (mock Clarion date value)
builtin_call('TODAY', [], StateIn, StateIn, 80000).

% CLOCK() - current time (returns 0 for now)
builtin_call('CLOCK', [], StateIn, StateIn, 0).

% SIZE(var) - returns byte size of a GROUP or FILE record
builtin_call('SIZE', [var(Name)], StateIn, StateIn, Size) :-
    ( get_file_state(Name, StateIn, file_state(_, _, _, Fields, _, _, _, _))
    -> length(Fields, NFields), Size is NFields * 4
    ; get_var(Name, StateIn, group_val(_, Fields, _))
    -> length(Fields, NFields), Size is NFields * 4
    ; get_var(Name, StateIn, group_val(Fields, _))
    -> length(Fields, NFields), Size is NFields * 4
    ; Size = 0
    ).

% ADDRESS(var) - returns mock memory address
builtin_call('ADDRESS', [_], StateIn, StateIn, 1234).

% POINTER(file) - returns current file pointer position
builtin_call('POINTER', [var(FileName)], StateIn, StateIn, Pos) :-
    ( get_file_state(FileName, StateIn, file_state(_, _, _, _, _, _, P, _))
    -> Pos is P + 1  % Clarion POINTER is 1-based
    ; Pos = 0
    ).

% CHOICE(control) - returns list control selection index
builtin_call('CHOICE', [ControlRef], StateIn, StateIn, Value) :-
    ( ControlRef = control_ref(Name) ->
        atom_concat('__CHOICE__', Name, ChoiceKey),
        ( get_var(ChoiceKey, StateIn, Value) -> true ; Value = 1 )
    ; Value = 1
    ).

% FORMAT(value, picture) - Format a value according to picture
builtin_call('FORMAT', [ValueExpr, PictureExpr], StateIn, StateIn, Result) :-
    eval_expr(ValueExpr, StateIn, Value),
    eval_expr(PictureExpr, StateIn, Picture),
    format_value(Value, Picture, Result).

format_value(Value, picture(Pic), Result) :-
    format_with_picture(Value, Pic, Result), !.
format_value(Value, Pic, Result) :-
    atom(Pic),
    format_with_picture(Value, Pic, Result), !.
format_value(Value, _, Result) :-
    to_string(Value, Result).

format_with_picture(Value, 'D2', Result) :-
    to_string(Value, Result).
format_with_picture(Value, 'D1', Result) :-
    to_string(Value, Result).
format_with_picture(Value, Pic, Result) :-
    atom_codes(Pic, [78|_]),  % Starts with 'N'
    to_string(Value, Result).
format_with_picture(Value, _, Result) :-
    to_string(Value, Result).

%------------------------------------------------------------
% File I/O Functions
%------------------------------------------------------------

% CREATE(file) - Create a file (in-memory, always succeeds)
builtin_call('CREATE', [var(FileName)], StateIn, StateOut, none) :-
    set_error(0, StateIn, StateOut),
    format("  [CREATE ~w]~n", [FileName]).

% OPEN(file) - Open a file
builtin_call('OPEN', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, _),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, -1, true),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [OPEN ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% CLOSE(file) - Close a file
builtin_call('CLOSE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, _),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, false),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [CLOSE ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% CLEAR(record) - Clear record buffer to default values
builtin_call('CLEAR', [var(RecordRef)], StateIn, StateOut, none) :-
    ( parse_prefixed_name(RecordRef, Prefix, 'Record')
    -> find_file_by_prefix(Prefix, StateIn, FileState),
       FileState = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
       create_empty_buffer(Fields, NewBuffer),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open),
       set_file_state(FileName, NewFileState, StateIn, StateOut)
    ;  StateOut = StateIn
    ).

% EMPTY(file) - Delete all records from file
builtin_call('EMPTY', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, _, Buffer, _, Open),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, [], Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [EMPTY ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% ADD(file) - Add current buffer as new record
builtin_call('ADD', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       append(Records, [Buffer], NewRecords),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [ADD to ~w]~n", [FileName])
    ;  set_error(2, StateIn, StateOut)
    ).

% GET(file/queue, index) - Get record by 1-based position
builtin_call('GET', [var(FileName), IndexExpr], StateIn, StateOut, none) :-
    IndexExpr \= var(_),
    eval_expr(IndexExpr, StateIn, Index),
    integer(Index),
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, _, _, Open),
       Pos is Index - 1,  % Convert 1-based to 0-based
       length(Records, NumRecords),
       ( Pos >= 0, Pos < NumRecords
       -> nth0(Pos, Records, NewBuffer),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut)
       ;  set_error(33, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% GET(file, key) - Get record by key
builtin_call('GET', [var(FileName), var(KeyRef)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       ( parse_prefixed_name(KeyRef, Prefix, KeyName)
       -> true
       ; KeyName = KeyRef
       ),
       ( member(key(KeyName, KeyFields), Keys)
       -> get_key_values(KeyFields, Prefix, Fields, Buffer, SearchValues),
          ( find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Records, 0, FoundRecord, FoundPos)
          -> NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, FoundRecord, FoundPos, Open),
             set_file_state(FileName, NewFileState, StateIn, State1),
             set_error(0, State1, StateOut)
          ;  set_error(33, StateIn, StateOut)
          )
       ;  set_error(47, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% PUT(file) - Update current record
builtin_call('PUT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
       length(Records, NumRecords),
       ( Pos >= 0, Pos < NumRecords
       -> replace_nth0(Pos, Records, Buffer, NewRecords),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, Pos, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut),
          format("  [PUT to ~w at position ~w]~n", [FileName, Pos])
       ;  set_error(33, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% DELETE(file) - Delete current record
builtin_call('DELETE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
       ( Pos >= 0
       -> delete_nth0(Pos, Records, NewRecords),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, -1, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut),
          format("  [DELETE from ~w at position ~w]~n", [FileName, Pos])
       ;  set_error(33, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% SET(file) or SET(key) - Set file position to beginning
builtin_call('SET', [var(Ref)], StateIn, StateOut, none) :-
    ( get_file_state(Ref, StateIn, FileState)
    -> FileState = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, _, Open),
       NewFileState = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, -1, Open),
       set_file_state(Ref, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut)
    ; parse_prefixed_name(Ref, Prefix, _KeyName)
    -> find_file_by_prefix(Prefix, StateIn, FileState),
       FileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
       NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, -1, Open),
       set_file_state(FileName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut)
    ;  set_error(2, StateIn, StateOut)
    ).

% NEXT(file) - Read next record
builtin_call('NEXT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
       NextPos is Pos + 1,
       length(Records, NumRecords),
       ( NextPos < NumRecords
       -> nth0(NextPos, Records, NewBuffer),
          NewFileState = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, NextPos, Open),
          set_file_state(FileName, NewFileState, StateIn, State1),
          set_error(0, State1, StateOut)
       ;  set_error(33, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% RECORDS(file) - Get number of records
builtin_call('RECORDS', [var(FileName)], StateIn, StateIn, Count) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> FileState = file_state(_, _, _, _, Records, _, _, _),
       length(Records, Count)
    ;  Count = 0
    ).

% ERRORCODE() - Get last error code
builtin_call('ERRORCODE', [], StateIn, StateIn, ErrCode) :-
    get_error(StateIn, ErrCode).

% ERROR() - Get error message for last error
builtin_call('ERROR', [], StateIn, StateIn, ErrMsg) :-
    get_error(StateIn, ErrCode),
    error_message(ErrCode, ErrMsg).

% FREE(queue) - Clear all records from a queue
builtin_call('FREE', [var(QueueName)], StateIn, StateOut, none) :-
    ( get_file_state(QueueName, StateIn, FileState)
    -> FileState = file_state(QueueName, Prefix, Keys, Fields, _, Buffer, _, Open),
       NewFileState = file_state(QueueName, Prefix, Keys, Fields, [], Buffer, -1, Open),
       set_file_state(QueueName, NewFileState, StateIn, State1),
       set_error(0, State1, StateOut),
       format("  [FREE ~w]~n", [QueueName])
    ;  set_error(2, StateIn, StateOut)
    ).

% SORT(queue, field) - Sort a queue by field
builtin_call('SORT', [var(QueueName), SortKey], StateIn, StateOut, none) :-
    ( get_file_state(QueueName, StateIn, FileState)
    -> FileState = file_state(QueueName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
       % Extract field name from sort key (e.g., var('MyQueue.Age') -> 'Age')
       ( SortKey = var(QualifiedName) ->
           ( parse_prefixed_name(QualifiedName, _, SortFieldName) -> true
           ; SortFieldName = QualifiedName
           )
       ; SortFieldName = SortKey
       ),
       % Find field index
       ( nth0(FieldIdx, Fields, field(SortFieldName, _, _)) ->
           sort_records_by_field(FieldIdx, Records, SortedRecords),
           NewFileState = file_state(QueueName, Prefix, Keys, Fields, SortedRecords, Buffer, Pos, Open),
           set_file_state(QueueName, NewFileState, StateIn, State1),
           set_error(0, State1, StateOut),
           format("  [SORT ~w by ~w]~n", [QueueName, SortFieldName])
       ;  format("  [SORT ~w - field ~w not found]~n", [QueueName, SortFieldName]),
          set_error(0, StateIn, StateOut)
       )
    ;  set_error(2, StateIn, StateOut)
    ).

sort_records_by_field(FieldIdx, Records, Sorted) :-
    map_list_to_pairs(nth0_key(FieldIdx), Records, Pairs),
    msort(Pairs, SortedPairs),
    pairs_values(SortedPairs, Sorted).

nth0_key(Idx, Record, Key) :-
    nth0(Idx, Record, Key).

%------------------------------------------------------------
% Window Event Functions
%------------------------------------------------------------

% EVENT() - Get current window event (for ACCEPT loop simulation)
builtin_call('EVENT', [], StateIn, StateIn, EventCode) :-
    get_event_phase(StateIn, Phase),
    phase_to_event(Phase, EventCode).

phase_to_event(open_window, 'EVENT:OpenWindow').
phase_to_event(close_window, 'EVENT:CloseWindow').
phase_to_event(accepted, 'EVENT:Accepted').
phase_to_event(_, 0).

% ACCEPTED() - Get last accepted control equate number
builtin_call('ACCEPTED', [], StateIn, StateIn, Value) :-
    ( get_var('__ACCEPTED__', StateIn, Value) -> true ; Value = 0 ).

% SELECT(control) - Select a control (no-op for non-GUI)
builtin_call('SELECT', [_Control], StateIn, StateIn, none).
% SELECT(control, index) - Select item in list control, store choice
builtin_call('SELECT', [ControlRef, IndexExpr], StateIn, StateOut, none) :-
    eval_expr(IndexExpr, StateIn, Index),
    ( ControlRef = control_ref(Name) ->
        atom_concat('__CHOICE__', Name, ChoiceKey),
        set_var(ChoiceKey, Index, StateIn, StateOut)
    ; StateOut = StateIn
    ).

% BEEP - Make a beep sound (no-op for non-GUI)
builtin_call('BEEP', [], StateIn, StateIn, none).

% DISPLAY - Refresh window display (no-op for non-GUI)
builtin_call('DISPLAY', [], StateIn, StateIn, none).

%------------------------------------------------------------
% Event Phase Management
%------------------------------------------------------------

set_event_phase(Phase, state(Vars, Procs, Out, Files, Err, Classes, Self, UI, Cont),
                       state([var('__EVENT_PHASE__', Phase)|Vars1], Procs, Out, Files, Err, Classes, Self, UI, Cont)) :-
    exclude(is_event_phase_var, Vars, Vars1).

is_event_phase_var(var('__EVENT_PHASE__', _)).

get_event_phase(state(Vars, _, _, _, _, _, _, _, _), Phase) :-
    member(var('__EVENT_PHASE__', Phase), Vars), !.
get_event_phase(_, none).

%------------------------------------------------------------
% Error Messages
%------------------------------------------------------------

error_message(0, "").
error_message(2, "File not found").
error_message(33, "Record not found").
error_message(47, "Invalid key").
error_message(_, "Unknown error").

%------------------------------------------------------------
% File I/O Helpers
%------------------------------------------------------------

get_key_values([], _, _, _, []).
get_key_values([KeyFieldRef|Rest], Prefix, Fields, Buffer, [Value|Values]) :-
    ( parse_prefixed_name(KeyFieldRef, Prefix, FieldName)
    -> true
    ; FieldName = KeyFieldRef
    ),
    nth0(Index, Fields, field(FieldName, _, _)),
    nth0(Index, Buffer, Value),
    get_key_values(Rest, Prefix, Fields, Buffer, Values).

find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [Record|_], Pos, Record, Pos) :-
    get_key_values(KeyFields, Prefix, Fields, Record, RecordValues),
    SearchValues = RecordValues, !.
find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [_|Rest], Pos, FoundRecord, FoundPos) :-
    NextPos is Pos + 1,
    find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Rest, NextPos, FoundRecord, FoundPos).

delete_nth0(0, [_|T], T) :- !.
delete_nth0(N, [H|T], [H|R]) :-
    N > 0,
    N1 is N - 1,
    delete_nth0(N1, T, R).
