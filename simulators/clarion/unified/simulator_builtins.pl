%============================================================
% simulator_builtins.pl - Built-in Functions
%
% Implements Clarion built-in functions: string functions,
% file I/O operations, and window event functions.
%============================================================

:- module(simulator_builtins, [
    builtin_call/5,
    error_message/2,
    get_event_phase/2,
    set_event_phase/3
]).

:- use_module(simulator_state).
:- use_module(simulator_eval).
:- use_module(storage_backend).
:- use_module(clarion_types).

:- discontiguous builtin_call/5.

%------------------------------------------------------------
% Storage Backend Helper
%------------------------------------------------------------

get_file_driver(FileName, StateIn, Driver) :-
    ( get_vars(StateIn, Vars),
      member(var(file_driver(FileName), D), Vars)
    -> Driver = D
    ;  Driver = memory
    ).

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

% UPPER(string) - convert to uppercase
builtin_call('UPPER', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_string(Str, S) ; S = Str ),
    upcase_atom(S, Result).

% LOWER(string) - convert to lowercase
builtin_call('LOWER', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_string(Str, S) ; S = Str ),
    downcase_atom(S, Result).

% TRIM(string) - remove trailing spaces (same as CLIP in Clarion)
builtin_call('TRIM', [Expr], StateIn, StateIn, Result) :-
    builtin_call('CLIP', [Expr], StateIn, StateIn, Result).

% LEFT(string) - left-justify (remove leading spaces)
builtin_call('LEFT', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Str),
    ( atom(Str) -> atom_string(Str, S) ; S = Str ),
    string_codes(S, Codes),
    drop_spaces(Codes, Trimmed),
    string_codes(Result, Trimmed).

% RIGHT(string) - right-justify (remove trailing spaces)
builtin_call('RIGHT', [Expr], StateIn, StateIn, Result) :-
    builtin_call('CLIP', [Expr], StateIn, StateIn, Result).

% INSTRING(needle, haystack [, start]) - find substring, return position (1-based) or 0
builtin_call('INSTRING', Args, StateIn, StateIn, Result) :-
    ( Args = [NeedleExpr, HaystackExpr]
    -> eval_expr(NeedleExpr, StateIn, Needle),
       eval_expr(HaystackExpr, StateIn, Haystack),
       Start = 1
    ; Args = [NeedleExpr, HaystackExpr, StartExpr]
    -> eval_expr(NeedleExpr, StateIn, Needle),
       eval_expr(HaystackExpr, StateIn, Haystack),
       eval_expr(StartExpr, StateIn, Start)
    ),
    to_string(Needle, NS),
    to_string(Haystack, HS),
    Offset is Start - 1,
    ( Offset >= 0, string_length(HS, HLen), Offset < HLen,
      sub_string(HS, Offset, _, 0, SubHS),
      sub_string(SubHS, Pos, _, _, NS)
    -> Result is Pos + Start
    ;  Result = 0
    ).

% SUB(string, position, length) - extract substring (1-based position)
builtin_call('SUB', [StrExpr, PosExpr, LenExpr], StateIn, StateIn, Result) :-
    eval_expr(StrExpr, StateIn, Str),
    eval_expr(PosExpr, StateIn, Pos),
    eval_expr(LenExpr, StateIn, Len),
    to_string(Str, S),
    string_length(S, SLen),
    Start is Pos - 1,
    ( Start >= 0, Start < SLen
    -> ActualLen is min(Len, SLen - Start),
       sub_string(S, Start, ActualLen, _, Result)
    ;  Result = ""
    ).

% TODAY() - current date (mock Clarion date value)
builtin_call('TODAY', [], StateIn, StateIn, 80000).

% CLOCK() - current time (returns 0 for now)
builtin_call('CLOCK', [], StateIn, StateIn, 0).

% BAND/BOR/BXOR(a, b) - bitwise AND/OR/XOR
builtin_call('BAND', [A, B], StateIn, StateIn, R) :-
    eval_expr(A, StateIn, VA), eval_expr(B, StateIn, VB), R is integer(VA) /\ integer(VB).
builtin_call('BOR', [A, B], StateIn, StateIn, R) :-
    eval_expr(A, StateIn, VA), eval_expr(B, StateIn, VB), R is integer(VA) \/ integer(VB).
builtin_call('BXOR', [A, B], StateIn, StateIn, R) :-
    eval_expr(A, StateIn, VA), eval_expr(B, StateIn, VB), R is integer(VA) xor integer(VB).

% DATE(month, day, year) - Clarion standard date: days since 28 Dec 1800
% (so DATE(1,1,1801) = 4). Month overflow (13 -> January next year) is
% normalised by SWI's date arithmetic.
builtin_call('DATE', [M, D, Y], StateIn, StateIn, R) :-
    eval_expr(M, StateIn, VM), eval_expr(D, StateIn, VD), eval_expr(Y, StateIn, VY),
    date_time_stamp(date(VY, VM, VD, 0, 0, 0, 0, -, -), S),
    date_time_stamp(date(1800, 12, 28, 0, 0, 0, 0, -, -), S0),
    R is round((S - S0) / 86400).

% NAME(file) - the file's label (the NAME() attribute is not kept)
builtin_call('NAME', [var(FileName)], StateIn, StateIn, FileName) :-
    get_file_state(FileName, StateIn, _), !.

% OMITTED(param) - true when the caller passed no argument for that parameter
builtin_call('OMITTED', [var(Name)], StateIn, StateIn, R) :-
    get_vars(StateIn, Vars),
    ( memberchk(var('$omitted'(Name), O), Vars) -> R = O
    ; atom(Name), upcase_atom(Name, U),
      member(var('$omitted'(N), O), Vars), atom(N), upcase_atom(N, U) -> R = O
    ; R = 0 ), !.

% DISPOSE(ref) - releases a NEW'd object; the reference becomes NULL
builtin_call('DISPOSE', [var(Name)], StateIn, StateOut, none) :-
    set_var(Name, null, StateIn, StateOut), !.

% ASSERT(condition [, message]) - logs a failed assertion and continues
builtin_call('ASSERT', [C|Msg], StateIn, StateIn, none) :-
    eval_expr(C, StateIn, V),
    ( V \== 0, V \== '', V \== "" -> true
    ; ( Msg = [ME], catch(eval_expr(ME, StateIn, MV), _, fail) -> true ; MV = '' ),
      format("  [ASSERT failed: ~w]~n", [MV])
    ).

% ABS(number) - absolute value
builtin_call('ABS', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Val),
    Result is abs(Val).

% INT(number) - truncate to integer
builtin_call('INT', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Val),
    Result is truncate(Val).

% ROUND(number, decimals) - round to N decimal places
builtin_call('ROUND', [Expr, DecExpr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Val),
    eval_expr(DecExpr, StateIn, Dec),
    Factor is 10 ** Dec,
    Result is round(Val * Factor) / Factor.

% ROUND(number) - round to nearest integer
builtin_call('ROUND', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Val),
    Result is round(Val).

% SQRT(number) - square root
builtin_call('SQRT', [Expr], StateIn, StateIn, Result) :-
    eval_expr(Expr, StateIn, Val),
    ( Val >= 0
    -> FResult is sqrt(Val),
       IResult is truncate(FResult),
       ( FResult =:= IResult -> Result = IResult ; Result = FResult )
    ;  Result = 0
    ).

% POWER(base, exponent) - exponentiation (Clarion doesn't have POWER but useful)
builtin_call('POWER', [BaseExpr, ExpExpr], StateIn, StateIn, Result) :-
    eval_expr(BaseExpr, StateIn, Base),
    eval_expr(ExpExpr, StateIn, Exp),
    Result is Base ** Exp.

% SIZE(x) - bytes in a record (PRE:Record or file), group, field or variable
builtin_call('SIZE', [var(Name)], StateIn, StateIn, Size) :-
    ( size_of(Name, StateIn, Size0) -> Size = Size0
    ; throw(error(unknown_size(Name), context('SIZE', 'Cannot tell how many bytes this is')))
    ).

size_of(Name, State, Size) :-
    get_file_state(Name, State, file_state(_, _, _, Fields, _, _, _, _)),
    fields_bytes(Fields, Size).
size_of(Name, State, Size) :-
    parse_prefixed_name(Name, Prefix, Field),
    ( find_file_by_prefix(Prefix, State, FileState) ; get_file_state(Prefix, State, FileState) ),
    FileState = file_state(_, _, _, Fields, _, _, _, _), !,
    ( Field == 'Record'
    -> fields_bytes(Fields, Size)
    ;  memberchk(field(Field, Type, FieldSize), Fields),
       type_bytes(Type, FieldSize, Size)
    ).
size_of(Name, State, Size) :-
    get_vars(State, Vars),
    memberchk(var(Name, Value), Vars),
    ( Value = group_val(_, Fields, _) -> fields_bytes(Fields, Size)
    ; Value = group_val(Fields, _) -> fields_bytes(Fields, Size)
    ; declared_type(Name, State, Type, TypeSize),
      type_bytes(Type, TypeSize, Each),
      ( Value = array(Elements) -> length(Elements, Count), Size is Each * Count ; Size = Each )
    ).

fields_bytes(Fields, Size) :-
    findall(B, ( member(field(_, Type, FieldSize), Fields), type_bytes(Type, FieldSize, B) ), Bytes),
    sum_list(Bytes, Size).

% The DOS driver addresses records by byte position, others by record number
record_pointer(FileName, State, Index, Pointer) :-
    byte_addressed(FileName, State, RecordSize), !,
    Pointer is Index * RecordSize + 1.
record_pointer(_, _, Index, Pointer) :-
    Pointer is Index + 1.

pointer_record(FileName, State, Pointer, Index) :-
    byte_addressed(FileName, State, RecordSize), !,
    (Pointer - 1) mod RecordSize =:= 0,
    Index is (Pointer - 1) // RecordSize.
pointer_record(_, _, Pointer, Index) :-
    Index is Pointer - 1.

byte_addressed(FileName, State, RecordSize) :-
    get_file_driver(FileName, State, 'DOS'),
    get_file_state(FileName, State, file_state(_, _, _, Fields, _, _, _, _)),
    fields_bytes(Fields, RecordSize),
    RecordSize > 0.

% ADDRESS(var) - returns a unique simulated address per variable name.
% The upper-cased name read as a base-256 number (+65536): deterministic,
% case-insensitive and injective. (It used to be the sum of the character
% codes, so anagram names collided: ADDRESS(Listen) = ADDRESS(Silent)
% sent a `case address(P:File)` dispatch to the wrong file's branch.)
builtin_call('ADDRESS', [var(Name)], StateIn, StateIn, Addr) :-
    !,
    upcase_atom(Name, U),
    atom_codes(U, Codes),
    foldl([C, A0, A1]>>(A1 is A0 * 256 + C), Codes, 0, N),
    Addr is N + 65536.
builtin_call('ADDRESS', [_], StateIn, StateIn, 65536).

% POINTER(file) - returns current file pointer position
builtin_call('POINTER', [var(FileName)], StateIn, StateIn, Pos) :-
    ( get_file_state(FileName, StateIn, file_state(_, _, _, _, _, _, P, _))
    -> ( P >= 0 -> record_pointer(FileName, StateIn, P, Pos) ; Pos = 0 )
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

% CREATE(file) - Create a file (dispatches to storage backend)
builtin_call('CREATE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> get_file_driver(FileName, StateIn, Driver),
       storage_call(storage_create(Driver, FileState, NewFileState), Code),
       finish_storage(Code, FileName, NewFileState, StateIn, StateOut),
       ( Code =:= 0 -> format("  [CREATE ~w]~n", [FileName]) ; true )
    ;  set_error(0, StateIn, StateOut),
       format("  [CREATE ~w]~n", [FileName])
    ).

% OPEN(file) - Open a file (dispatches to storage backend)
builtin_call('OPEN', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> get_file_driver(FileName, StateIn, Driver),
       ( FileState = file_state(_, _, _, _, _, _, _, true)
       -> set_error(52, StateIn, StateOut)
       ;  storage_call(storage_open(Driver, FileName, FileState, NewFileState), Code),
          finish_storage(Code, FileName, NewFileState, StateIn, State1),
          ( Code =:= 0
          -> set_cursor(FileName, cursor(none, start), State1, StateOut),
             format("  [OPEN ~w]~n", [FileName])
          ;  StateOut = State1
          )
       )
    ;  set_error(2, StateIn, StateOut)
    ).

% CLOSE(file) - Close a file (dispatches to storage backend)
builtin_call('CLOSE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> get_file_driver(FileName, StateIn, Driver),
       storage_call(storage_close(Driver, FileState, NewFileState), Code),
       finish_storage(Code, FileName, NewFileState, StateIn, StateOut),
       ( Code =:= 0 -> format("  [CLOSE ~w]~n", [FileName]) ; true )
    ;  set_error(2, StateIn, StateOut)
    ).

% CLEAR(record) - Clear record buffer to default values (dispatches to storage backend)
builtin_call('CLEAR', [var(RecordRef)], StateIn, StateOut, none) :-
    ( parse_prefixed_name(RecordRef, Prefix, 'Record')
    -> find_file_by_prefix(Prefix, StateIn, FileState),
       FileState = file_state(FileName, _, _, _, _, _, _, _),
       get_file_driver(FileName, StateIn, Driver),
       storage_clear(Driver, FileState, NewFileState),
       set_file_state(FileName, NewFileState, StateIn, StateOut)
    ;  StateOut = StateIn
    ).

% EMPTY(file) - Delete all records from file (dispatches to storage backend)
builtin_call('EMPTY', [var(FileName)], StateIn, StateOut, none) :-
    open_file(FileName, StateIn, FileState, Code0),
    ( Code0 =:= 0
    -> get_file_driver(FileName, StateIn, Driver),
       storage_call(storage_empty(Driver, FileState, NewFileState), Code),
       finish_storage(Code, FileName, NewFileState, StateIn, State1),
       ( Code =:= 0
       -> set_cursor(FileName, cursor(none, start), State1, StateOut),
          format("  [EMPTY ~w]~n", [FileName])
       ;  StateOut = State1
       )
    ;  set_error(Code0, StateIn, StateOut)
    ).

% ADD(file) - Add current buffer as new record (dispatches to storage backend).
% The new record becomes the current one for PUT and DELETE.
builtin_call('ADD', [var(FileName)], StateIn, StateOut, none) :-
    open_file(FileName, StateIn, FileState, Code0),
    ( Code0 =\= 0
    -> set_error(Code0, StateIn, StateOut)
    ; duplicate_key(FileState, none)
    -> set_error(40, StateIn, StateOut)
    ;  get_file_driver(FileName, StateIn, Driver),
       storage_call(storage_add(Driver, FileState, NewFileState0), Code),
       ( Code =:= 0
       -> NewFileState0 = file_state(N, P, K, F, Records, B, _, O),
          length(Records, Count), Pos is Count - 1,
          NewFileState = file_state(N, P, K, F, Records, B, Pos, O)
       ;  true
       ),
       finish_storage(Code, FileName, NewFileState, StateIn, StateOut),
       ( Code =:= 0 -> format("  [ADD to ~w]~n", [FileName]) ; true )
    ).

% GET(file, key) - Get record by key (dispatches to storage backend)
% GET(queue, field) - Get queue entry matching a field
% GET(file/queue, pointer) - Get record by 1-based position
% GET does not affect SET/NEXT/PREVIOUS.
builtin_call('GET', [var(FileName), Arg], StateIn, StateOut, none) :-
    open_file(FileName, StateIn, FileState, Code0),
    ( Code0 =\= 0
    -> set_error(Code0, StateIn, StateOut)
    ; get_target(Arg, FileName, FileState, StateIn, Target)
    -> get_record(Target, FileName, FileState, StateIn, StateOut)
    ;  set_error(47, StateIn, StateOut)
    ).

get_target(var(Ref), FileName, FileState, State, Target) :-
    ( file_key(Ref, FileState, KeyName, KeyFields)
    -> Target = key(KeyName, KeyFields)
    ; is_queue(FileName, State), queue_field(Ref, FileName, FileState, Field)
    -> Target = field(Field)
    ; plain_variable(Ref, State)
    -> get_var(Ref, State, Value), to_number(Value, N), Target = pointer(N)
    ).
get_target(Arg, _, _, State, pointer(N)) :-
    Arg \= var(_),
    eval_expr(Arg, State, Value),
    to_number(Value, N).

plain_variable(Name, State) :-
    get_vars(State, Vars),
    memberchk(var(Name, _), Vars).

get_record(key(KeyName, KeyFields), FileName, FileState, StateIn, StateOut) :-
    FileState = file_state(_, Prefix, _, Fields, _, Buffer, _, _),
    get_key_values(KeyFields, Prefix, Fields, Buffer, SearchValues),
    get_file_driver(FileName, StateIn, Driver),
    ( storage_call(storage_get(Driver, key_search(KeyName, KeyFields, SearchValues),
                               FileState, NewFileState), Code)
    -> ( Code =:= 0 -> typed_buffer(NewFileState, Typed) ; Typed = NewFileState ),
       finish_storage(Code, FileName, Typed, StateIn, StateOut)
    ;  set_error(35, StateIn, StateOut)
    ).
get_record(field(Field), FileName, FileState, StateIn, StateOut) :-
    FileState = file_state(_, _, _, Fields, Records, Buffer, _, _),
    nth0(FieldIdx, Fields, field(Field, _, _)), !,
    nth0(FieldIdx, Buffer, Wanted),
    ( nth0(Pos, Records, Record), nth0(FieldIdx, Record, Value),
      compare_values(=, Value, Wanted)
    -> current_record(Pos, FileName, FileState, StateIn, StateOut)
    ;  set_error(30, StateIn, StateOut)
    ).
get_record(pointer(Index), FileName, FileState, StateIn, StateOut) :-
    FileState = file_state(_, _, _, _, Records, _, _, _),
    Pointer is truncate(Index),
    length(Records, Count),
    ( pointer_record(FileName, StateIn, Pointer, Pos), Pos >= 0, Pos < Count
    -> current_record(Pos, FileName, FileState, StateIn, StateOut)
    ; is_queue(FileName, StateIn)
    -> set_error(30, StateIn, StateOut)
    ;  set_error(35, StateIn, StateOut)
    ).

% PUT(file) - Update current record (dispatches to storage backend)
builtin_call('PUT', [var(FileName)], StateIn, StateOut, none) :-
    open_file(FileName, StateIn, FileState, Code0),
    ( Code0 =\= 0
    -> set_error(Code0, StateIn, StateOut)
    ;  FileState = file_state(_, _, _, _, _, _, Pos, _),
       ( duplicate_key(FileState, Pos)
       -> set_error(40, StateIn, StateOut)
       ;  get_file_driver(FileName, StateIn, Driver),
          ( storage_call(storage_put(Driver, FileState, NewFileState), Code)
          -> finish_storage(Code, FileName, NewFileState, StateIn, StateOut),
             ( Code =:= 0 -> format("  [PUT to ~w at position ~w]~n", [FileName, Pos]) ; true )
          ;  set_error(33, StateIn, StateOut)
          )
       )
    ).

% DELETE(file) - Delete current record (dispatches to storage backend)
builtin_call('DELETE', [var(FileName)], StateIn, StateOut, none) :-
    open_file(FileName, StateIn, FileState, Code0),
    ( Code0 =\= 0
    -> set_error(Code0, StateIn, StateOut)
    ;  FileState = file_state(_, _, _, _, _, _, Pos, _),
       get_file_driver(FileName, StateIn, Driver),
       ( Pos >= 0, storage_call(storage_delete(Driver, FileState, NewFileState), Code)
       -> finish_storage(Code, FileName, NewFileState, StateIn, State1),
          ( Code =:= 0
          -> cursor_after_delete(FileName, Pos, State1, StateOut),
             format("  [DELETE from ~w at position ~w]~n", [FileName, Pos])
          ;  StateOut = State1
          )
       ;  set_error(33, StateIn, StateOut)
       )
    ).

% SET(file)     - record order, from the start
% SET(key)      - key order, from the start
% SET(key, key) - key order, from the key values now in the record buffer
builtin_call('SET', [var(Ref)], StateIn, StateOut, none) :-
    ( get_file_state(Ref, StateIn, _)
    -> set_cursor(Ref, cursor(none, start), StateIn, State1),
       set_error(0, State1, StateOut)
    ; find_key(Ref, StateIn, FileName, KeyName, _)
    -> set_cursor(FileName, cursor(KeyName, start), StateIn, State1),
       set_error(0, State1, StateOut)
    ;  set_error(47, StateIn, StateOut)
    ).
builtin_call('SET', [var(Ref), var(Ref2)], StateIn, StateOut, none) :-
    find_key(Ref, StateIn, FileName, KeyName, KeyFields),
    find_key(Ref2, StateIn, FileName, KeyName, _),
    get_file_state(FileName, StateIn, file_state(_, Prefix, _, Fields, _, Buffer, _, _)),
    get_key_values(KeyFields, Prefix, Fields, Buffer, Values),
    set_cursor(FileName, cursor(KeyName, from(Values)), StateIn, State1),
    set_error(0, State1, StateOut).

% NEXT(file) / PREVIOUS(file) - read along the order chosen by SET
builtin_call('NEXT', [var(FileName)], StateIn, StateOut, none) :-
    step_cursor(next, FileName, StateIn, StateOut).
builtin_call('PREVIOUS', [var(FileName)], StateIn, StateOut, none) :-
    step_cursor(previous, FileName, StateIn, StateOut).

% RECORDS(file) - Get number of records (dispatches to storage backend)
builtin_call('RECORDS', [var(FileName)], StateIn, StateIn, Count) :-
    ( get_file_state(FileName, StateIn, FileState)
    -> get_file_driver(FileName, StateIn, Driver),
       storage_records(Driver, FileState, Count)
    ;  Count = 0
    ).

% ERRORCODE() - Get last error code
builtin_call('ERRORCODE', [], StateIn, StateIn, ErrCode) :-
    get_error(StateIn, ErrCode).

% ERROR() - Get error message for last error
builtin_call('ERROR', [], StateIn, StateIn, ErrMsg) :-
    get_error(StateIn, ErrCode),
    error_message(ErrCode, ErrMsg).

% FREE(queue) - Clear all records from a queue (dispatches to storage backend)
builtin_call('FREE', [var(QueueName)], StateIn, StateOut, none) :-
    ( get_file_state(QueueName, StateIn, FileState)
    -> get_file_driver(QueueName, StateIn, Driver),
       storage_empty(Driver, FileState, NewFileState),
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

% EVENT() - Get current event code (set by ACCEPT loop event handlers)
% Falls back to phase-based lookup for legacy integer-event path
builtin_call('EVENT', [], StateIn, StateIn, Value) :-
    ( get_var('__EVENT__', StateIn, Value) -> true
    ; get_event_phase(StateIn, Phase),
      phase_to_event(Phase, Value)
    ).

phase_to_event(open_window, 4).   % EVENT:OpenWindow
phase_to_event(close_window, 5).  % EVENT:CloseWindow
phase_to_event(accepted, 1).      % EVENT:Accepted
phase_to_event(_, 0).

% ACCEPTED() - Get last accepted control equate number
builtin_call('ACCEPTED', [], StateIn, StateIn, Value) :-
    ( get_var('__ACCEPTED__', StateIn, Value) -> true ; Value = 0 ).

% FIELD() - Get control equate number of field that generated the event
% In the simulator, this is the same as ACCEPTED() since events target controls
builtin_call('FIELD', [], StateIn, StateIn, Value) :-
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

% ENABLE/DISABLE - Control visibility (no-op in headless simulation)
builtin_call('ENABLE', [_], StateIn, StateIn, none).
builtin_call('DISABLE', [_], StateIn, StateIn, none).

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
error_message(30, "Entry not found").
error_message(33, "Record not available").
error_message(35, "Record not found").
error_message(37, "File not open").
error_message(40, "Creates duplicate key").
error_message(47, "Invalid key").
error_message(52, "File already open").
error_message(89, "Record changed by another station").
error_message(90, "File system error").
error_message(_, "Unknown error").

%------------------------------------------------------------
% File I/O Helpers
%------------------------------------------------------------

%% open_file(+Name, +State, -FileState, -Code)
%  Code is 0, 2 (no such file) or 37 (not open).
open_file(Name, State, FileState, Code) :-
    ( get_file_state(Name, State, FileState0)
    -> FileState = FileState0,
       ( FileState = file_state(_, _, _, _, _, _, _, true) -> Code = 0 ; Code = 37 )
    ;  Code = 2
    ).

% Make the record at Pos the current one
current_record(Pos, FileName, file_state(FileName, P, K, F, Records, _, _, O), StateIn, StateOut) :-
    nth0(Pos, Records, Record),
    typed_buffer(file_state(FileName, P, K, F, Records, Record, Pos, O), NewFileState),
    set_file_state(FileName, NewFileState, StateIn, State1),
    set_error(0, State1, StateOut).

% Stored values may come from outside (CSV, database): convert the buffer to
% the declared field types. Records themselves keep the stored form.
typed_buffer(file_state(N, P, K, Fields, R, Buffer, Pos, O),
             file_state(N, P, K, Fields, R, Typed, Pos, O)) :-
    typed_values(Fields, Buffer, Typed).

typed_values([field(_, Type, Size)|Fs], [V|Vs], [T|Ts]) :- !,
    coerce(Type, Size, V, T),
    typed_values(Fs, Vs, Ts).
typed_values(_, _, []).

% A key reference is PRE:Key, or Key when the file has no prefix
file_key(Ref, file_state(_, Prefix, Keys, _, _, _, _, _), KeyName, KeyFields) :-
    ( parse_prefixed_name(Ref, Prefix, KeyName0) -> true ; KeyName0 = Ref ),
    memberchk(key(KeyName0, KeyFields), Keys),
    KeyName = KeyName0.

find_key(Ref, State, FileName, KeyName, KeyFields) :-
    get_files(State, Files),
    member(FileState, Files),
    FileState = file_state(FileName, _, _, _, _, _, _, _),
    file_key(Ref, FileState, KeyName, KeyFields), !.

queue_field(Ref, FileName, file_state(_, Prefix, _, Fields, _, _, _, _), Field) :-
    parse_prefixed_name(Ref, Qualifier, Field),
    ( Qualifier == FileName ; Qualifier == Prefix ), !,
    memberchk(field(Field, _, _), Fields).

key_attributes(KeyName, Keys, Attrs) :-
    ( memberchk(key_attrs(KeyName, Attrs0), Keys) -> Attrs = Attrs0 ; Attrs = [] ).

% The buffer repeats a unique key of some record other than the one at Pos.
% A key is unique unless DUP; OPT ignores blank key values.
duplicate_key(file_state(_, Prefix, Keys, Fields, Records, Buffer, _, _), Pos) :-
    member(key_attrs(KeyName, Attrs), Keys),
    \+ memberchk(dup, Attrs),
    memberchk(key(KeyName, KeyFields), Keys),
    get_key_values(KeyFields, Prefix, Fields, Buffer, Values),
    \+ ( memberchk(opt, Attrs), forall(member(V, Values), blank_value(V)) ),
    nth0(Index, Records, Record),
    Index \== Pos,
    get_key_values(KeyFields, Prefix, Fields, Record, Others),
    same_values(Values, Others, Attrs), !.

blank_value(V) :- number(V), !, V =:= 0.
blank_value('$null$') :- !.
blank_value(V) :- clip_text(V, "").

%------------------------------------------------------------
% Sequential access
%------------------------------------------------------------
% Entries are KeyValues-Index, ordered by key values then record index.
% Record order is the same thing with no key values.

step_cursor(Direction, FileName, StateIn, StateOut) :-
    open_file(FileName, StateIn, FileState, Code),
    ( Code =\= 0
    -> set_error(Code, StateIn, StateOut)
    ;  get_cursor(FileName, StateIn, cursor(Key, At)),
       FileState = file_state(_, _, Keys, _, _, _, _, _),
       key_attributes(Key, Keys, Attrs),
       findall(Entry,
               ( cursor_entry(Key, FileState, Entry), beyond(Direction, At, Entry, Attrs) ),
               Entries),
       ( nearest(Direction, Entries, Attrs, Values-Index)
       -> current_record(Index, FileName, FileState, StateIn, State1),
          set_cursor(FileName, cursor(Key, at(Values, Index)), State1, StateOut)
       ;  set_error(33, StateIn, StateOut)
       )
    ).

cursor_entry(none, file_state(_, _, _, _, Records, _, _, _), []-Index) :- !,
    nth0(Index, Records, _).
cursor_entry(Key, file_state(_, Prefix, Keys, Fields, Records, _, _, _), Values-Index) :-
    memberchk(key(Key, KeyFields), Keys),
    nth0(Index, Records, Record),
    get_key_values(KeyFields, Prefix, Fields, Record, Values).

beyond(_, start, _, _).
beyond(next, from(Values), V-_, Attrs) :- compare_keys(O, V, Values, Attrs), O \== (<).
beyond(previous, from(Values), V-_, Attrs) :- compare_keys(O, V, Values, Attrs), O \== (>).
beyond(next, at(Values, Index), E, Attrs) :- compare_entries(>, E, Values-Index, Attrs).
beyond(previous, at(Values, Index), E, Attrs) :- compare_entries(<, E, Values-Index, Attrs).

compare_entries(Order, V1-I1, V2-I2, Attrs) :-
    compare_keys(O, V1, V2, Attrs),
    ( O == (=) -> compare(Order0, I1, I2) ; Order0 = O ),
    Order = Order0.

nearest(Direction, [E|Es], Attrs, Nearest) :-
    ( Direction == next -> Better = (<) ; Better = (>) ),
    foldl([X, Best0, Best]>>( compare_entries(Better, X, Best0, Attrs) -> Best = X ; Best = Best0 ),
          Es, E, Nearest).

% Records after the deleted one move down by one
cursor_after_delete(FileName, Pos, StateIn, StateOut) :-
    get_cursor(FileName, StateIn, cursor(Key, At)),
    ( At = at(Values, Index), Pos =< Index
    -> Index1 is Index - 1,
       set_cursor(FileName, cursor(Key, at(Values, Index1)), StateIn, StateOut)
    ;  StateOut = StateIn
    ).

%% storage_call(:Goal, -Code)
%  Code is 0 if Goal succeeds, or the code of a storage_error/1 it throws.
%  Fails if Goal fails.
storage_call(Goal, Code) :-
    catch((call(Goal), Code0 = 0), storage_error(Code0), true),
    Code = Code0.

%% finish_storage(+Code, +FileName, +NewFileState, +StateIn, -StateOut)
%  Keep the new file state only if the operation succeeded; set ERRORCODE().
finish_storage(0, FileName, NewFileState, StateIn, StateOut) :- !,
    set_file_state(FileName, NewFileState, StateIn, State1),
    set_error(0, State1, StateOut).
finish_storage(Code, _, _, StateIn, StateOut) :-
    set_error(Code, StateIn, StateOut).

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
