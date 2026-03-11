%============================================================
% storage_odbc.lgt - ODBC Database Storage Backend (Logtalk)
%
% Delegates core record operations to storage_memory,
% adds ODBC database I/O with dirty-tracking.
%============================================================

:- object(storage_odbc,
    implements(istorage_backend)).

    :- public([
        connect_dsn/2,
        disconnect/1
    ]).

    % ODBC state tracked via assertz/retract
    :- private(odbc_conn/3).  % odbc_conn(TableName, Connection, Dirty)
    :- dynamic(odbc_conn/3).

    open(FSIn, FSOut) :-
        open('', FSIn, FSOut).

    open(FileName, file_state(Name,Pre,K,Fields,_,B,_,_), file_state(Name,Pre,K,Fields,Records,B,-1,true)) :-
        ( get_odbc_dsn(DSN)
        -> ( connect_dsn(DSN, Connection)
           -> get_table_name(FileName, Name, TableName),
              load_table_records(Connection, TableName, Fields, Records),
              length(Records, Count),
              format("  [ODBC: Connected to ~w, loaded ~w records from ~w]~n", [DSN, Count, TableName]),
              ::retractall(odbc_conn(TableName, _, _)),
              ::assertz(odbc_conn(TableName, Connection, false))
           ;  Records = [],
              format("  [ODBC: Connection failed, using memory]~n", [])
           )
        ;  Records = [],
           format("  [ODBC: No DSN configured, using memory]~n", [])
        ).

    close(file_state(Name,Pre,K,Fields,Records,B,P,_), file_state(Name,Pre,K,Fields,Records,B,P,false)) :-
        get_table_name(Name, Name, TableName),
        ( ::odbc_conn(TableName, Connection, true)
        -> sync_table_records(Connection, TableName, Fields, Records),
           length(Records, Count),
           format("  [ODBC: Synced ~w records to ~w]~n", [Count, TableName]),
           disconnect(Connection),
           format("  [ODBC: Disconnected]~n", [])
        ; ::odbc_conn(TableName, Connection, false)
        -> disconnect(Connection),
           format("  [ODBC: Disconnected]~n", [])
        ;  true
        ),
        ::retractall(odbc_conn(TableName, _, _)).

    create(FS, FS).

    add(FSIn, FSOut) :-
        storage_memory::add(FSIn, FSOut),
        FSIn = file_state(Name,_,_,_,_,_,_,_),
        get_table_name(Name, Name, TableName),
        mark_dirty(TableName).

    get(KeyInfo, FSIn, FSOut) :- storage_memory::get(KeyInfo, FSIn, FSOut).

    put(FSIn, FSOut) :-
        storage_memory::put(FSIn, FSOut),
        FSIn = file_state(Name,_,_,_,_,_,_,_),
        get_table_name(Name, Name, TableName),
        mark_dirty(TableName).

    delete(FSIn, FSOut) :-
        storage_memory::delete(FSIn, FSOut),
        FSIn = file_state(Name,_,_,_,_,_,_,_),
        get_table_name(Name, Name, TableName),
        mark_dirty(TableName).

    next(FSIn, FSOut) :- storage_memory::next(FSIn, FSOut).
    set(FSIn, FSOut) :- storage_memory::set(FSIn, FSOut).
    records(FS, Count) :- storage_memory::records(FS, Count).

    empty(FSIn, FSOut) :-
        storage_memory::empty(FSIn, FSOut),
        FSIn = file_state(Name,_,_,_,_,_,_,_),
        get_table_name(Name, Name, TableName),
        mark_dirty(TableName).

    clear(FSIn, FSOut) :- storage_memory::clear(FSIn, FSOut).

    % Public ODBC helpers
    connect_dsn(DSN, Connection) :-
        catch(odbc_connect(DSN, Connection, []),
              Error, (format(user_error, "ODBC error: ~w~n", [Error]), fail)).

    disconnect(Connection) :-
        catch(odbc_disconnect(Connection), _, true).

    % Private helpers
    :- private([
        get_odbc_dsn/1,
        get_table_name/3,
        mark_dirty/1,
        load_table_records/4,
        sync_table_records/4,
        insert_all_records/4,
        field_names/2,
        format_values/3,
        format_single_value/3,
        is_string_type/1,
        convert_rows_to_buffers/3,
        pad_or_trim_values/3,
        get_default_padding/4
    ]).

    get_odbc_dsn(DSN) :- getenv('CLARION_ODBC_DSN', DSN), !.
    get_odbc_dsn(_) :-
        format(user_error, "Warning: CLARION_ODBC_DSN not set~n", []), fail.

    get_table_name(FileName, FallbackName, TableName) :-
        ( atom(FileName), FileName \= FallbackName -> TableName = FileName ; TableName = FallbackName ).

    mark_dirty(TableName) :-
        ( ::retract(odbc_conn(TableName, Conn, _))
        -> ::assertz(odbc_conn(TableName, Conn, true))
        ;  true
        ).

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
        nth0(SI, Fields, field(_, Type, Size)),
        simulator_classes::default_value(Type, Size, D),
        N1 is N - 1, SI1 is SI + 1, get_default_padding(N1, Fields, SI1, R).

:- end_object.
