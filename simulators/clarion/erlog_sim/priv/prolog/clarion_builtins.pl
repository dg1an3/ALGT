%============================================================
% clarion_builtins.pl - Built-in Functions for Erlog Simulator
%
% Implements Clarion built-in functions: string operations,
% file I/O, window events, math, and error handling.
%
% Storage operations are implemented directly in Prolog
% (in-memory list manipulation) — no external callbacks needed.
% This keeps all state in Prolog for backward execution.
%
% Erlog-compatible: no modules, no dicts, ISO-standard.
%============================================================

%------------------------------------------------------------
% String Functions
%------------------------------------------------------------

% MESSAGE(text) or MESSAGE(text, title)
builtin_call('MESSAGE', Args, StateIn, StateOut, none) :-
    ( Args = [TextExpr] ->
        eval_full_expr(TextExpr, StateIn, Text)
    ; Args = [TextExpr|_] ->
        eval_full_expr(TextExpr, StateIn, Text)
    ),
    add_output(message(Text), StateIn, StateOut).

% CLIP(string) - remove trailing spaces
builtin_call('CLIP', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Str),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    reverse(Codes, Rev),
    drop_leading_spaces(Rev, TrimmedRev),
    reverse(TrimmedRev, Trimmed),
    atom_codes(Result, Trimmed).

drop_leading_spaces([32|Rest], Result) :- !, drop_leading_spaces(Rest, Result).
drop_leading_spaces(List, List).

% TRIM(string) - same as CLIP in Clarion
builtin_call('TRIM', [Expr], StateIn, StateIn, Result) :-
    builtin_call('CLIP', [Expr], StateIn, StateIn, Result).

% LEFT(string) - remove leading spaces
builtin_call('LEFT', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Str),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    drop_leading_spaces(Codes, Trimmed),
    atom_codes(Result, Trimmed).

% RIGHT(string) - remove trailing spaces
builtin_call('RIGHT', [Expr], StateIn, StateIn, Result) :-
    builtin_call('CLIP', [Expr], StateIn, StateIn, Result).

% LEN(string) - string length
builtin_call('LEN', [Expr], StateIn, StateIn, Len) :-
    eval_full_expr(Expr, StateIn, Str),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    length(Codes, Len).

% CHR(code) - character from code
builtin_call('CHR', [Expr], StateIn, StateIn, Char) :-
    eval_full_expr(Expr, StateIn, Code),
    atom_codes(Char, [Code]).

% VAL(char) - code from character
builtin_call('VAL', [Expr], StateIn, StateIn, Code) :-
    eval_full_expr(Expr, StateIn, Char),
    to_string_val(Char, S),
    atom_codes(S, [Code|_]).

% UPPER(string) - convert to uppercase
builtin_call('UPPER', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Str),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    upcase_codes(Codes, Upper),
    atom_codes(Result, Upper).

upcase_codes([], []).
upcase_codes([C|Cs], [U|Us]) :-
    ( C >= 97, C =< 122 -> U is C - 32 ; U = C ),
    upcase_codes(Cs, Us).

% LOWER(string) - convert to lowercase
builtin_call('LOWER', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Str),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    downcase_codes(Codes, Lower),
    atom_codes(Result, Lower).

downcase_codes([], []).
downcase_codes([C|Cs], [L|Ls]) :-
    ( C >= 65, C =< 90 -> L is C + 32 ; L = C ),
    downcase_codes(Cs, Ls).

% INSTRING(needle, haystack [, start])
builtin_call('INSTRING', Args, StateIn, StateIn, Result) :-
    ( Args = [NeedleExpr, HaystackExpr] ->
        eval_full_expr(NeedleExpr, StateIn, Needle),
        eval_full_expr(HaystackExpr, StateIn, Haystack),
        Start = 1
    ; Args = [NeedleExpr, HaystackExpr, StartExpr] ->
        eval_full_expr(NeedleExpr, StateIn, Needle),
        eval_full_expr(HaystackExpr, StateIn, Haystack),
        eval_full_expr(StartExpr, StateIn, Start)
    ),
    to_string_val(Needle, NS),
    to_string_val(Haystack, HS),
    atom_codes(NS, NCodes),
    atom_codes(HS, HCodes),
    Offset is Start - 1,
    ( Offset >= 0, drop_n(Offset, HCodes, SubHCodes),
      find_sublist(NCodes, SubHCodes, Pos) ->
        Result is Pos + Start
    ;   Result = 0
    ).

drop_n(0, L, L) :- !.
drop_n(N, [_|T], R) :- N > 0, N1 is N - 1, drop_n(N1, T, R).
drop_n(_, [], []).

find_sublist(Needle, Haystack, Pos) :-
    find_sublist_(Needle, Haystack, 0, Pos).
find_sublist_(Needle, Haystack, N, N) :-
    append(Needle, _, Haystack), !.
find_sublist_(Needle, [_|Rest], N, Pos) :-
    N1 is N + 1,
    find_sublist_(Needle, Rest, N1, Pos).

% SUB(string, position, length) - extract substring (1-based)
builtin_call('SUB', [StrExpr, PosExpr, LenExpr], StateIn, StateIn, Result) :-
    eval_full_expr(StrExpr, StateIn, Str),
    eval_full_expr(PosExpr, StateIn, Pos),
    eval_full_expr(LenExpr, StateIn, Len),
    to_string_val(Str, S),
    atom_codes(S, Codes),
    Start is Pos - 1,
    ( Start >= 0 ->
        drop_n(Start, Codes, AfterStart),
        take_n(Len, AfterStart, SubCodes),
        atom_codes(Result, SubCodes)
    ;   Result = ''
    ).

take_n(0, _, []) :- !.
take_n(_, [], []) :- !.
take_n(N, [H|T], [H|R]) :- N > 0, N1 is N - 1, take_n(N1, T, R).

%------------------------------------------------------------
% Math Functions
%------------------------------------------------------------

% ABS(number)
builtin_call('ABS', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Val),
    Result is abs(Val).

% INT(number) - truncate to integer
builtin_call('INT', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Val),
    Result is truncate(Val).

% ROUND(number) or ROUND(number, decimals)
builtin_call('ROUND', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Val),
    Result is round(Val).
builtin_call('ROUND', [Expr, DecExpr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Val),
    eval_full_expr(DecExpr, StateIn, Dec),
    Factor is 10 ** Dec,
    Result is round(Val * Factor) / Factor.

% SQRT(number)
builtin_call('SQRT', [Expr], StateIn, StateIn, Result) :-
    eval_full_expr(Expr, StateIn, Val),
    ( Val >= 0 ->
        FResult is sqrt(Val),
        IResult is truncate(FResult),
        ( FResult =:= IResult -> Result = IResult ; Result = FResult )
    ;   Result = 0
    ).

% POWER(base, exponent)
builtin_call('POWER', [BaseExpr, ExpExpr], StateIn, StateIn, Result) :-
    eval_full_expr(BaseExpr, StateIn, Base),
    eval_full_expr(ExpExpr, StateIn, Exp),
    Result is Base ** Exp.

% TODAY() - mock Clarion date
builtin_call('TODAY', [], StateIn, StateIn, 80000).

% CLOCK() - mock Clarion time
builtin_call('CLOCK', [], StateIn, StateIn, 0).

%------------------------------------------------------------
% Size/Address/Pointer Functions
%------------------------------------------------------------

% SIZE(var) - byte size of GROUP or FILE record
builtin_call('SIZE', [var(Name)], StateIn, StateIn, Size) :-
    ( get_file_state(Name, StateIn, FS) ->
        file_state_fields(FS, Fields),
        length(Fields, NF), Size is NF * 4
    ; get_var(Name, StateIn, group_val(_, Fields, _)) ->
        length(Fields, NF), Size is NF * 4
    ; get_var(Name, StateIn, group_val(Fields, _)) ->
        length(Fields, NF), Size is NF * 4
    ;   Size = 0
    ).

% ADDRESS(var) - simulated address
builtin_call('ADDRESS', [var(Name)], StateIn, StateIn, Addr) :- !,
    atom_codes(Name, Codes),
    sum_list(Codes, Sum),
    Addr is (Sum * 1000) + 65536.
builtin_call('ADDRESS', [_], StateIn, StateIn, 65536).

sum_list([], 0).
sum_list([H|T], Sum) :- sum_list(T, Rest), Sum is H + Rest.

% POINTER(file) - current file pointer position
builtin_call('POINTER', [var(FileName)], StateIn, StateIn, Pos) :-
    ( get_file_state(FileName, StateIn, FS) ->
        file_state_position(FS, P),
        Pos is P + 1
    ;   Pos = 0
    ).

% ERRORCODE() - last error code
builtin_call('ERRORCODE', [], StateIn, StateIn, ErrCode) :-
    state_error(StateIn, ErrCode).

% ERROR() - error message
builtin_call('ERROR', [], StateIn, StateIn, ErrMsg) :-
    state_error(StateIn, ErrCode),
    error_message(ErrCode, ErrMsg).

error_message(0, '').
error_message(2, 'File not found').
error_message(33, 'Record not found').
error_message(47, 'Invalid key').
error_message(_, 'Unknown error').

%------------------------------------------------------------
% File I/O Functions (direct in-memory implementation)
%------------------------------------------------------------

% CREATE(file)
builtin_call('CREATE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, _FS) ->
        set_state_error(0, StateIn, StateOut)
    ;   set_state_error(0, StateIn, StateOut)
    ).

% OPEN(file)
builtin_call('OPEN', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, _),
        NewFS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, true),
        set_file_state(FileName, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ;   set_state_error(2, StateIn, StateOut)
    ).

% CLOSE(file)
builtin_call('CLOSE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, _),
        NewFS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, false),
        set_file_state(FileName, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ;   set_state_error(2, StateIn, StateOut)
    ).

% ADD(file) - add buffer as new record
builtin_call('ADD', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
        append(Records, [Buffer], NewRecords),
        NewFS = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, Pos, Open),
        set_file_state(FileName, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ;   set_state_error(2, StateIn, StateOut)
    ).

% GET(file, index) - get record by 1-based position
builtin_call('GET', [var(FileName), IndexExpr], StateIn, StateOut, none) :-
    IndexExpr \= var(_),
    eval_full_expr(IndexExpr, StateIn, Index),
    integer(Index),
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, _, _, Open),
        Pos is Index - 1,
        length(Records, NumRecords),
        ( Pos >= 0, Pos < NumRecords ->
            nth0_list(Pos, Records, NewBuffer),
            NewFS = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, Pos, Open),
            set_file_state(FileName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(33, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

% GET(file, key) - get record by key
builtin_call('GET', [var(FileName), var(KeyRef)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, _, Open),
        ( parse_prefixed_name(KeyRef, Prefix, KeyName) -> true ; KeyName = KeyRef ),
        ( member(key(KeyName, KeyFields), Keys) ->
            get_key_values(KeyFields, Prefix, Fields, Buffer, SearchValues),
            ( find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Records, 0, FoundRecord, FoundPos) ->
                NewFS = file_state(FileName, Prefix, Keys, Fields, Records, FoundRecord, FoundPos, Open),
                set_file_state(FileName, NewFS, StateIn, State1),
                set_state_error(0, State1, StateOut)
            ;   set_state_error(33, StateIn, StateOut)
            )
        ;   set_state_error(47, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

% PUT(file) - update current record
builtin_call('PUT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
        ( Pos >= 0 ->
            replace_nth0(Pos, Records, Buffer, NewRecords),
            NewFS = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, Pos, Open),
            set_file_state(FileName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(33, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

% DELETE(file) - delete current record
builtin_call('DELETE', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
        ( Pos >= 0 ->
            delete_nth0(Pos, Records, NewRecords),
            NewFS = file_state(FileName, Prefix, Keys, Fields, NewRecords, Buffer, -1, Open),
            set_file_state(FileName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(33, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

delete_nth0(0, [_|T], T) :- !.
delete_nth0(N, [H|T], [H|R]) :- N > 0, N1 is N - 1, delete_nth0(N1, T, R).

% SET(file/key) - set position to beginning
builtin_call('SET', [var(Ref)], StateIn, StateOut, none) :-
    ( get_file_state(Ref, StateIn, FS) ->
        FS = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, _, Open),
        NewFS = file_state(Ref, Prefix, Keys, Fields, Records, Buffer, -1, Open),
        set_file_state(Ref, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ; parse_prefixed_name(Ref, Prefix, _) ->
        find_file_by_prefix(Prefix, StateIn, FS),
        file_state_name(FS, FileName),
        FS = file_state(FileName, Pfx, Keys, Fields, Records, Buffer, _, Open),
        NewFS = file_state(FileName, Pfx, Keys, Fields, Records, Buffer, -1, Open),
        set_file_state(FileName, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ;   set_state_error(2, StateIn, StateOut)
    ).

% NEXT(file) - read next record
builtin_call('NEXT', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
        NextPos is Pos + 1,
        length(Records, NumRecords),
        ( NextPos < NumRecords ->
            nth0_list(NextPos, Records, NewBuffer),
            NewFS = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, NextPos, Open),
            set_file_state(FileName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(33, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

% PREVIOUS(file) - read previous record
builtin_call('PREVIOUS', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, Records, _, Pos, Open),
        ( Pos < 0 ->
            length(Records, NumRecords),
            PrevPos is NumRecords - 1
        ;   PrevPos is Pos - 1
        ),
        ( PrevPos >= 0 ->
            nth0_list(PrevPos, Records, NewBuffer),
            NewFS = file_state(FileName, Prefix, Keys, Fields, Records, NewBuffer, PrevPos, Open),
            set_file_state(FileName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(33, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

% RECORDS(file) - count records
builtin_call('RECORDS', [var(FileName)], StateIn, StateIn, Count) :-
    ( get_file_state(FileName, StateIn, FS) ->
        file_state_records(FS, Records),
        length(Records, Count)
    ;   Count = 0
    ).

% CLEAR(record) - clear buffer to defaults
builtin_call('CLEAR', [var(RecordRef)], StateIn, StateOut, none) :-
    ( parse_prefixed_name(RecordRef, Prefix, 'Record') ->
        find_file_by_prefix(Prefix, StateIn, FS),
        file_state_name(FS, FileName),
        clear_buffer(FS, NewFS),
        set_file_state(FileName, NewFS, StateIn, StateOut)
    ;   StateOut = StateIn
    ).

% EMPTY(file) - delete all records
builtin_call('EMPTY', [var(FileName)], StateIn, StateOut, none) :-
    ( get_file_state(FileName, StateIn, FS) ->
        FS = file_state(FileName, Prefix, Keys, Fields, _, Buffer, _, Open),
        NewFS = file_state(FileName, Prefix, Keys, Fields, [], Buffer, -1, Open),
        set_file_state(FileName, NewFS, StateIn, State1),
        set_state_error(0, State1, StateOut)
    ;   set_state_error(2, StateIn, StateOut)
    ).

% FREE(queue) - clear all records
builtin_call('FREE', [var(QueueName)], StateIn, StateOut, none) :-
    builtin_call('EMPTY', [var(QueueName)], StateIn, StateOut, none).

% SORT(queue, field) - sort by field
builtin_call('SORT', [var(QueueName), SortKey], StateIn, StateOut, none) :-
    ( get_file_state(QueueName, StateIn, FS) ->
        FS = file_state(QueueName, Prefix, Keys, Fields, Records, Buffer, Pos, Open),
        ( SortKey = var(QualifiedName) ->
            ( parse_prefixed_name(QualifiedName, _, SortFieldName) -> true
            ; SortFieldName = QualifiedName
            )
        ; SortFieldName = SortKey
        ),
        ( nth0_field_index(SortFieldName, Fields, FieldIdx) ->
            sort_records_by_field(FieldIdx, Records, SortedRecords),
            NewFS = file_state(QueueName, Prefix, Keys, Fields, SortedRecords, Buffer, Pos, Open),
            set_file_state(QueueName, NewFS, StateIn, State1),
            set_state_error(0, State1, StateOut)
        ;   set_state_error(0, StateIn, StateOut)
        )
    ;   set_state_error(2, StateIn, StateOut)
    ).

sort_records_by_field(FieldIdx, Records, Sorted) :-
    tag_records(FieldIdx, Records, Tagged),
    sort(Tagged, SortedTagged),
    untag_records(SortedTagged, Sorted).

tag_records(_, [], []).
tag_records(Idx, [Rec|Recs], [Key-Rec|Tagged]) :-
    nth0_list(Idx, Rec, Key),
    tag_records(Idx, Recs, Tagged).

untag_records([], []).
untag_records([_-Rec|Rest], [Rec|Recs]) :-
    untag_records(Rest, Recs).

%------------------------------------------------------------
% Window Event Functions
%------------------------------------------------------------

% EVENT() - get current window event
builtin_call('EVENT', [], StateIn, StateIn, EventCode) :-
    get_event_phase(StateIn, Phase),
    phase_to_event(Phase, EventCode).

phase_to_event(open_window, 'EVENT:OpenWindow').
phase_to_event(close_window, 'EVENT:CloseWindow').
phase_to_event(accepted, 'EVENT:Accepted').
phase_to_event(_, 0).

% ACCEPTED() - get last accepted control equate number
builtin_call('ACCEPTED', [], StateIn, StateIn, Value) :-
    ( get_var('__ACCEPTED__', StateIn, Value) -> true ; Value = 0 ).

% CHOICE(control)
builtin_call('CHOICE', [ControlRef], StateIn, StateIn, Value) :-
    ( ControlRef = control_ref(Name) ->
        atom_concat('__CHOICE__', Name, ChoiceKey),
        ( get_var(ChoiceKey, StateIn, Value) -> true ; Value = 1 )
    ; Value = 1
    ).

% SELECT(control) - no-op
builtin_call('SELECT', [_], StateIn, StateIn, none).
% SELECT(control, index) - store choice
builtin_call('SELECT', [ControlRef, IndexExpr], StateIn, StateOut, none) :-
    eval_full_expr(IndexExpr, StateIn, Index),
    ( ControlRef = control_ref(Name) ->
        atom_concat('__CHOICE__', Name, ChoiceKey),
        set_var(ChoiceKey, Index, StateIn, StateOut)
    ;   StateOut = StateIn
    ).

% FORMAT(value, picture)
builtin_call('FORMAT', [ValueExpr, _PictureExpr], StateIn, StateIn, Result) :-
    eval_full_expr(ValueExpr, StateIn, Value),
    to_string_val(Value, Result).

% BEEP - no-op
builtin_call('BEEP', [], StateIn, StateIn, none).

% DISPLAY - no-op
builtin_call('DISPLAY', [], StateIn, StateIn, none).

%------------------------------------------------------------
% File I/O Helpers
%------------------------------------------------------------

get_key_values([], _, _, _, []).
get_key_values([KeyFieldRef|Rest], Prefix, Fields, Buffer, [Value|Values]) :-
    ( parse_prefixed_name(KeyFieldRef, Prefix, FieldName) -> true
    ; FieldName = KeyFieldRef
    ),
    nth0_field_index(FieldName, Fields, Index),
    nth0_list(Index, Buffer, Value),
    get_key_values(Rest, Prefix, Fields, Buffer, Values).

find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [Record|_], Pos, Record, Pos) :-
    get_key_values(KeyFields, Prefix, Fields, Record, RecordValues),
    SearchValues = RecordValues, !.
find_record_by_key(KeyFields, Prefix, Fields, SearchValues, [_|Rest], Pos, FoundRecord, FoundPos) :-
    NextPos is Pos + 1,
    find_record_by_key(KeyFields, Prefix, Fields, SearchValues, Rest, NextPos, FoundRecord, FoundPos).

% atom_concat/3 — fallback if not built-in
% (Most Prolog implementations including Erlog have this)
