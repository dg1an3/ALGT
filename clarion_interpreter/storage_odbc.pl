%============================================================
% storage_odbc.pl - ODBC Database Storage Backend
% Uses tuple format with ODBC connection stored separately
%============================================================

:- module(storage_odbc, [
    odbc_open/3, odbc_close/2, odbc_add/2, odbc_get/3,
    odbc_put/2, odbc_delete/2, odbc_next/2, odbc_set/2,
    odbc_records/2, odbc_empty/2, odbc_clear/2,
    odbc_connect_dsn/2, do_odbc_disconnect/1
]).

:- use_module(library(odbc)).
:- use_module(storage_memory).
:- use_module(interpreter_classes, [default_value/3]).

% ODBC state tracked via assertz/retract
:- dynamic odbc_conn/3.  % odbc_conn(TableName, Connection, dirty)

get_odbc_dsn(DSN) :- getenv('CLARION_ODBC_DSN', DSN), !.
get_odbc_dsn(_) :-
    format(user_error, "Warning: CLARION_ODBC_DSN not set~n", []), fail.

odbc_connect_dsn(DSN, Connection) :-
    catch(odbc_connect(DSN, Connection, []),
          Error, (format(user_error, "ODBC error: ~w~n", [Error]), fail)).

do_odbc_disconnect(Connection) :-
    catch(odbc_disconnect(Connection), _, true).

odbc_open(FileName, file_state(Name,Pre,K,Fields,_,B,_,_), file_state(Name,Pre,K,Fields,Records,B,-1,true)) :-
    ( get_odbc_dsn(DSN)
    -> ( odbc_connect_dsn(DSN, Connection)
       -> get_table_name(FileName, Name, TableName),
          load_table_records(Connection, TableName, Fields, Records),
          length(Records, Count),
          format("  [ODBC: Connected to ~w, loaded ~w records from ~w]~n", [DSN, Count, TableName]),
          retractall(odbc_conn(TableName, _, _)),
          assertz(odbc_conn(TableName, Connection, false))
       ;  Records = [],
          format("  [ODBC: Connection failed, using memory]~n", [])
       )
    ;  Records = [],
       format("  [ODBC: No DSN configured, using memory]~n", [])
    ).

odbc_close(file_state(Name,Pre,K,Fields,Records,B,P,_), file_state(Name,Pre,K,Fields,Records,B,P,false)) :-
    get_table_name(Name, Name, TableName),
    ( odbc_conn(TableName, Connection, true)
    -> sync_table_records(Connection, TableName, Fields, Records),
       length(Records, Count),
       format("  [ODBC: Synced ~w records to ~w]~n", [Count, TableName]),
       do_odbc_disconnect(Connection),
       format("  [ODBC: Disconnected]~n", [])
    ; odbc_conn(TableName, Connection, false)
    -> do_odbc_disconnect(Connection),
       format("  [ODBC: Disconnected]~n", [])
    ;  true
    ),
    retractall(odbc_conn(TableName, _, _)).

odbc_add(FSIn, FSOut) :- 
    storage_memory:mem_add(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_table_name(Name, Name, TableName),
    mark_dirty_odbc(TableName).

odbc_get(KeyInfo, FSIn, FSOut) :- storage_memory:mem_get(KeyInfo, FSIn, FSOut).

odbc_put(FSIn, FSOut) :- 
    storage_memory:mem_put(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_table_name(Name, Name, TableName),
    mark_dirty_odbc(TableName).

odbc_delete(FSIn, FSOut) :- 
    storage_memory:mem_delete(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_table_name(Name, Name, TableName),
    mark_dirty_odbc(TableName).

odbc_next(FSIn, FSOut) :- storage_memory:mem_next(FSIn, FSOut).
odbc_set(FSIn, FSOut) :- storage_memory:mem_set(FSIn, FSOut).
odbc_records(FS, Count) :- storage_memory:mem_records(FS, Count).

odbc_empty(FSIn, FSOut) :- 
    storage_memory:mem_empty(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_table_name(Name, Name, TableName),
    mark_dirty_odbc(TableName).

odbc_clear(FSIn, FSOut) :- storage_memory:mem_clear(FSIn, FSOut).

mark_dirty_odbc(TableName) :-
    ( retract(odbc_conn(TableName, Conn, _))
    -> assertz(odbc_conn(TableName, Conn, true))
    ;  true
    ).

get_table_name(FileName, FallbackName, TableName) :-
    ( atom(FileName), FileName \= FallbackName -> TableName = FileName ; TableName = FallbackName ).

load_table_records(Connection, TableName, Fields, Records) :-
    field_names(Fields, FieldNames),
    atomic_list_concat(FieldNames, ', ', FieldList),
    format(atom(SQL), 'SELECT ~w FROM ~w', [FieldList, TableName]),
    catch(
        (odbc_query(Connection, SQL, Rows, [findall(Row, Row)]),
         convert_rows_to_buffers(Rows, Fields, Records)),
        Error,
        (format(user_error, "ODBC select error: ~w~n", [Error]), Records = [])
    ).

sync_table_records(Connection, TableName, Fields, Records) :-
    format(atom(DelSQL), 'DELETE FROM ~w', [TableName]),
    catch(odbc_query(Connection, DelSQL, _), _, true),
    insert_all_records(Connection, TableName, Fields, Records).

insert_all_records(_, _, _, []).
insert_all_records(Connection, TableName, Fields, [Record|Records]) :-
    field_names(Fields, FieldNames),
    atomic_list_concat(FieldNames, ', ', FieldList),
    format_values(Record, Fields, ValueList),
    format(atom(SQL), 'INSERT INTO ~w (~w) VALUES (~w)', [TableName, FieldList, ValueList]),
    catch(odbc_query(Connection, SQL, _), Error, format(user_error, "ODBC insert: ~w~n", [Error])),
    insert_all_records(Connection, TableName, Fields, Records).

field_names([], []).
field_names([field(Name, _, _)|Rest], [Name|Names]) :- field_names(Rest, Names).

format_values([], [], "").
format_values([V], [field(_, Type, _)], F) :- format_single_value(V, Type, F), !.
format_values([V|Vs], [field(_, Type, _)|Fs], Result) :-
    format_single_value(V, Type, F),
    format_values(Vs, Fs, Rest),
    ( Rest = "" -> Result = F ; atomic_list_concat([F, ', ', Rest], Result) ).

format_single_value(V, Type, F) :-
    ( is_string_type(Type) -> format(atom(F), "'~w'", [V]) ; format(atom(F), "~w", [V]) ).

is_string_type('STRING'). is_string_type('CSTRING'). is_string_type('PSTRING').

convert_rows_to_buffers([], _, []).
convert_rows_to_buffers([Row|Rows], Fields, [Buffer|Buffers]) :-
    Row =.. [row|Values],
    pad_or_trim_values(Values, Fields, Buffer),
    convert_rows_to_buffers(Rows, Fields, Buffers).

pad_or_trim_values(Values, Fields, Buffer) :-
    length(Fields, FC), length(Values, VC),
    ( VC >= FC -> length(Buffer, FC), append(Buffer, _, Values)
    ;  PC is FC - VC, get_default_padding(PC, Fields, VC, Padding), append(Values, Padding, Buffer)
    ).

get_default_padding(0, _, _, []) :- !.
get_default_padding(N, Fields, SI, [D|R]) :-
    nth0(SI, Fields, field(_, Type, Size)), default_value(Type, Size, D),
    N1 is N - 1, SI1 is SI + 1, get_default_padding(N1, Fields, SI1, R).
