%============================================================
% storage_memory.lgt - In-Memory Storage Backend (Logtalk)
%
% Uses 8-element tuple:
%   file_state(Name, Prefix, Keys, Fields, Records, Buffer, Position, IsOpen)
%============================================================

:- object(storage_memory,
    implements(istorage_backend)).

    :- public([
        replace_nth0/4,
        delete_nth0/3,
        create_default_buffer/2
    ]).

    open(file_state(N,Pre,K,F,R,B,_,_), file_state(N,Pre,K,F,R,B,-1,true)).

    open(_, FSIn, FSOut) :-
        open(FSIn, FSOut).

    close(file_state(N,Pre,K,F,R,B,P,_), file_state(N,Pre,K,F,R,B,P,false)).

    create(FS, FS).

    add(file_state(N,Pre,K,F,Records,Buffer,_,O), file_state(N,Pre,K,F,NewRecords,Buffer,-1,O)) :-
        append(Records, [Buffer], NewRecords).

    get(key_search(KeyName, KeyFields, SearchValues),
        file_state(N,Pre,Keys,Fields,Records,_,_,O),
        file_state(N,Pre,Keys,Fields,Records,FoundRecord,FoundPos,O)) :-
        member(key(KeyName, KeyFields), Keys),
        find_record_by_key(KeyFields, Fields, SearchValues, Records, 0, FoundRecord, FoundPos).

    put(file_state(N,Pre,K,F,Records,Buffer,Pos,O), file_state(N,Pre,K,F,NewRecords,Buffer,Pos,O)) :-
        Pos >= 0, length(Records, NumRecords), Pos < NumRecords,
        replace_nth0(Pos, Records, Buffer, NewRecords).

    delete(file_state(N,Pre,K,F,Records,B,Pos,O), file_state(N,Pre,K,F,NewRecords,B,-1,O)) :-
        Pos >= 0, delete_nth0(Pos, Records, NewRecords).

    next(file_state(N,Pre,K,F,Records,_,Pos,O), file_state(N,Pre,K,F,Records,NewBuffer,NextPos,O)) :-
        NextPos is Pos + 1, length(Records, NumRecords),
        NextPos < NumRecords, nth0(NextPos, Records, NewBuffer).

    set(file_state(N,Pre,K,F,R,B,_,O), file_state(N,Pre,K,F,R,B,-1,O)).

    records(file_state(_,_,_,_,Records,_,_,_), Count) :- length(Records, Count).

    empty(file_state(N,Pre,K,F,_,B,_,O), file_state(N,Pre,K,F,[],B,-1,O)).

    clear(file_state(N,Pre,K,Fields,R,_,P,O), file_state(N,Pre,K,Fields,R,NewBuffer,P,O)) :-
        create_default_buffer(Fields, NewBuffer).

    % Helpers (public for reuse by csv/odbc backends)
    create_default_buffer([], []).
    create_default_buffer([field(_, Type, Size)|Rest], [Value|Values]) :-
        simulator_classes::default_value(Type, Size, Value),
        create_default_buffer(Rest, Values).

    replace_nth0(0, [_|T], Elem, [Elem|T]) :- !.
    replace_nth0(N, [H|T], Elem, [H|R]) :-
        N > 0, N1 is N - 1, replace_nth0(N1, T, Elem, R).

    delete_nth0(0, [_|T], T) :- !.
    delete_nth0(N, [H|T], [H|R]) :-
        N > 0, N1 is N - 1, delete_nth0(N1, T, R).

    % Private helpers
    :- private([
        find_record_by_key/7,
        get_key_values_from_record/4,
        get_field_value/4
    ]).

    find_record_by_key(KeyFields, Fields, SearchValues, [Record|_], Pos, Record, Pos) :-
        get_key_values_from_record(KeyFields, Fields, Record, RecordValues),
        SearchValues = RecordValues, !.
    find_record_by_key(KeyFields, Fields, SearchValues, [_|Rest], Pos, FoundRecord, FoundPos) :-
        NextPos is Pos + 1,
        find_record_by_key(KeyFields, Fields, SearchValues, Rest, NextPos, FoundRecord, FoundPos).

    get_key_values_from_record([], _, _, []).
    get_key_values_from_record([KeyField|Rest], Fields, Buffer, [Value|Values]) :-
        get_field_value(KeyField, Fields, Buffer, Value),
        get_key_values_from_record(Rest, Fields, Buffer, Values).

    get_field_value(FieldName, Fields, Buffer, Value) :-
        nth0(Index, Fields, field(FieldName, _, _)), nth0(Index, Buffer, Value), !.
    get_field_value(PrefixedName, Fields, Buffer, Value) :-
        atom(PrefixedName), atom_string(PrefixedName, NameStr),
        sub_string(NameStr, Before, 1, After, ":"), Before > 0, After > 0,
        sub_string(NameStr, _, After, 0, FieldStr), atom_string(FieldName, FieldStr),
        nth0(Index, Fields, field(FieldName, _, _)), nth0(Index, Buffer, Value), !.

:- end_object.
