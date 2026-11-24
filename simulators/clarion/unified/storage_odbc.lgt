%============================================================
% storage_odbc.lgt - ODBC Database Storage Backend (Logtalk)
%
% Records are loaded on OPEN and kept in memory for reading
% (delegated to storage_memory). Every ADD, PUT, DELETE and EMPTY
% is written through to the database immediately, one statement
% per transaction, so only rows the program touched are changed.
% PUT and DELETE match the row by the values last read and are
% refused unless exactly one row matches.
%
% The database column type decides how dates are mapped (clarion_dates.pl).
% A value that would not convert back exactly is refused with error 90.
%
% Failures throw storage_error(Code), which becomes ERRORCODE():
%   37 file not open         52 file already open
%   89 record changed by another station (no single match)
%   90 file system error     (database or driver error)
%
% With CLARION_ODBC_DSN unset, files are purely in-memory.
%============================================================

% library(odbc) is optional (a separate package on some platforms). Calls below
% are odbc:-qualified; unqualified they compile to local predicates of this object.
:- initialization((
    exists_source(library(odbc)) -> use_module(library(odbc), []) ; true
)).

:- object(storage_odbc,
    implements(istorage_backend)).

    :- use_module(library(lists), [nth0/3, append/3, member/2]).

    :- public([
        connect_dsn/2,
        disconnect/1
    ]).

    :- private(odbc_conn/3).  % odbc_conn(TableName, Connection, ColumnKinds)
    :- dynamic(odbc_conn/3).

    open(_, FSIn, FSOut) :-
        open(FSIn, FSOut).

    open(file_state(Name,_,_,_,_,_,_,true), _) :-
        ::odbc_conn(Name, _, _),
        throw(storage_error(52)).
    open(file_state(Name,Pre,K,Fields,_,B,_,_), file_state(Name,Pre,K,Fields,Records,B,-1,true)) :-
        drop_connection(Name),  % left over from a session that never closed
        ( getenv('CLARION_ODBC_DSN', DSN)
        -> open_table(DSN, Name, Fields, Records)
        ;  format(user_error, "Warning: CLARION_ODBC_DSN not set~n", []),
           format("  [ODBC: No DSN configured, using memory]~n", []),
           Records = []
        ).

    % Nothing is pending here: every change was committed when it was made.
    close(file_state(Name,Pre,K,F,R,B,P,_), file_state(Name,Pre,K,F,R,B,P,false)) :-
        ( ::odbc_conn(Name, _, _)
        -> drop_connection(Name),
           format("  [ODBC: Disconnected]~n", [])
        ;  true
        ).

    create(FS, FS).

    add(FSIn, FSOut) :-
        storage_memory::add(FSIn, FSOut),
        FSIn = file_state(_,_,_,_,_,Buffer,_,_),
        write_through(FSIn, insert(Buffer)).

    get(KeyInfo, FSIn, FSOut) :- storage_memory::get(KeyInfo, FSIn, FSOut).

    put(FSIn, FSOut) :-
        storage_memory::put(FSIn, FSOut),
        FSIn = file_state(_,_,_,_,Records,Buffer,Pos,_),
        nth0(Pos, Records, Old),
        write_through(FSIn, update(Old, Buffer)).

    delete(FSIn, FSOut) :-
        storage_memory::delete(FSIn, FSOut),
        FSIn = file_state(_,_,_,_,Records,_,Pos,_),
        nth0(Pos, Records, Old),
        write_through(FSIn, delete(Old)).

    next(FSIn, FSOut) :- storage_memory::next(FSIn, FSOut).
    set(FSIn, FSOut) :- storage_memory::set(FSIn, FSOut).
    records(FS, Count) :- storage_memory::records(FS, Count).

    empty(FSIn, FSOut) :-
        storage_memory::empty(FSIn, FSOut),
        write_through(FSIn, empty).

    clear(FSIn, FSOut) :- storage_memory::clear(FSIn, FSOut).

    % Public ODBC helpers
    connect_dsn(DSN, Connection) :-
        catch(odbc:odbc_connect(DSN, Connection, [auto_commit(false)]),
              Error, (format(user_error, "ODBC error: ~w~n", [Error]), fail)).

    disconnect(Connection) :-
        catch(odbc:odbc_disconnect(Connection), _, true).

    % Private helpers
    :- private([
        open_table/4,
        drop_connection/1,
        load_table_records/4,
        load_table/5,
        column_kinds/4,
        facet_kinds/4,
        column_kind/2,
        field_class/2,
        convert_row/4,
        convert_value/5,
        convert_error/4,
        write_through/2,
        statement/5,
        execute/4,
        check_affected/2,
        transaction/2,
        field_names/2,
        assignments/2,
        placeholders/2,
        match_conditions/4,
        bind_params/3,
        bind_param/3,
        convert_rows_to_buffers/2
    ]).

    open_table(DSN, Table, Fields, Records) :-
        ( connect_dsn(DSN, Connection) -> true ; throw(storage_error(90)) ),
        catch(
            transaction(Connection, load_table(Connection, Table, Fields, Kinds, Records)),
            Error,
            ( disconnect(Connection), throw(Error) )
        ),
        length(Records, Count),
        format("  [ODBC: Connected to ~w, loaded ~w records from ~w]~n", [DSN, Count, Table]),
        ::assertz(odbc_conn(Table, Connection, Kinds)).

    drop_connection(Table) :-
        forall(::retract(odbc_conn(Table, Connection, _)), disconnect(Connection)).

    load_table(Connection, Table, Fields, Kinds, Records) :-
        column_kinds(Connection, Table, Fields, Kinds),
        load_table_records(Connection, Table, Fields, Rows),
        findall(Record, (member(Row, Rows), convert_row(from_column, Fields-Kinds, Row, Record)), Records).

    % One kind per field: date, time, timestamp or other.
    column_kinds(Connection, Table, Fields, Kinds) :-
        findall(Column-Facet, odbc:odbc_table_column(Connection, Table, Column, Facet), Facets),
        upcase_atom(Table, TableUp),
        facet_kinds(Facets, TableUp, none, Columns),
        findall(Kind,
                ( member(field(Name, _, _), Fields),
                  upcase_atom(Name, NameUp),
                  ( member(NameUp-Type, Columns) -> column_kind(Type, Kind) ; Kind = other ) ),
                Kinds).

    % Facets arrive column by column, table_name before data_type. The table
    % name is a pattern to ODBC (_ is a wildcard), so drop other tables' columns.
    facet_kinds([], _, _, []).
    facet_kinds([_-table_name(T)|Rest], TableUp, _, Columns) :- !,
        upcase_atom(T, Current),
        facet_kinds(Rest, TableUp, Current, Columns).
    facet_kinds([Column-data_type(Type)|Rest], TableUp, TableUp, [ColumnUp-Type|Columns]) :- !,
        upcase_atom(Column, ColumnUp),
        facet_kinds(Rest, TableUp, TableUp, Columns).
    facet_kinds([_|Rest], TableUp, Current, Columns) :-
        facet_kinds(Rest, TableUp, Current, Columns).

    column_kind(91, date) :- !.       % SQL_TYPE_DATE
    column_kind(92, time) :- !.       % SQL_TYPE_TIME
    column_kind(93, timestamp) :- !.  % SQL_TYPE_TIMESTAMP
    column_kind(_, other).

    field_class(Type, text) :- member(Type, ['STRING', 'CSTRING', 'PSTRING']), !.
    field_class(_, number).

    % Direction is from_column or to_column.
    convert_row(Direction, Fields-Kinds, Values, Converted) :-
        findall(C, ( nth0(I, Values, V),
                     nth0(I, Fields, Field), nth0(I, Kinds, Kind),
                     convert_value(Direction, Field, Kind, V, C) ), Converted).

    convert_value(_, _, other, V, V) :- !.
    convert_value(Direction, field(Name, Type, _), Kind, V, C) :-
        field_class(Type, Class),
        ( Direction == from_column
        -> ( clarion_dates:from_column(Kind, Class, V, C0) -> C = C0 ; convert_error(Name, Class, Kind, V) )
        ;  ( clarion_dates:to_column(Kind, Class, V, C0) -> C = C0 ; convert_error(Name, Class, Kind, V) )
        ).

    convert_error(Name, Class, Kind, Value) :-
        ( Class == number -> Hint = ' (a STRING field may hold it)' ; Hint = '' ),
        format(user_error, "ODBC error: ~w: cannot convert ~w exactly for a ~w column~w~n",
               [Name, Value, Kind, Hint]),
        throw(storage_error(90)).

    load_table_records(Connection, Table, Fields, Records) :-
        field_names(Fields, Names),
        atomic_list_concat(Names, ', ', Columns),
        format(atom(SQL), 'SELECT ~w FROM ~w', [Columns, Table]),
        findall(Row, odbc:odbc_query(Connection, SQL, Row), Rows),
        convert_rows_to_buffers(Rows, Records).

    write_through(file_state(Table,_,_,Fields,_,_,_,_), Change) :-
        ( ::odbc_conn(Table, Connection, Kinds)
        -> field_names(Fields, Names),
           Change =.. [Op|Rows],
           findall(DbRow, (member(Row, Rows), convert_row(to_column, Fields-Kinds, Row, DbRow)), DbRows),
           DbChange =.. [Op|DbRows],
           statement(DbChange, Table, Names, SQL, Params),
           transaction(Connection, (
               execute(Connection, SQL, Params, Affected),
               check_affected(Change, Affected)
           ))
        ; getenv('CLARION_ODBC_DSN', _)
        -> throw(storage_error(37))
        ;  true  % in-memory mode
        ).

    statement(insert(Values), Table, Names, SQL, Values) :-
        atomic_list_concat(Names, ', ', Columns),
        placeholders(Values, Marks),
        format(atom(SQL), 'INSERT INTO ~w (~w) VALUES (~w)', [Table, Columns, Marks]).
    statement(update(Old, New), Table, Names, SQL, Params) :-
        assignments(Names, Assignments),
        match_conditions(Names, Old, Where, OldParams),
        append(New, OldParams, Params),
        format(atom(SQL), 'UPDATE ~w SET ~w WHERE ~w', [Table, Assignments, Where]).
    statement(delete(Old), Table, Names, SQL, Params) :-
        match_conditions(Names, Old, Where, Params),
        format(atom(SQL), 'DELETE FROM ~w WHERE ~w', [Table, Where]).
    statement(empty, Table, _, SQL, []) :-
        format(atom(SQL), 'DELETE FROM ~w', [Table]).

    execute(Connection, SQL, Values, Affected) :-
        bind_params(Values, Types, Params),
        odbc:odbc_prepare(Connection, SQL, Types, Statement),
        catch(
            odbc:odbc_execute(Statement, Params, affected(Affected)),
            Error,
            ( odbc:odbc_free_statement(Statement), throw(Error) )
        ),
        odbc:odbc_free_statement(Statement).

    check_affected(empty, _) :- !.
    check_affected(_, 1) :- !.
    check_affected(Change, Affected) :-
        functor(Change, Op, _),
        format(user_error, "ODBC ~w: matched ~w rows, expected 1~n", [Op, Affected]),
        throw(storage_error(89)).

    % Commit Goal, or roll back and throw storage_error/1 if it cannot complete.
    :- meta_predicate(transaction(*, 0)).
    transaction(Connection, Goal) :-
        catch(
            ( call(Goal) -> odbc:odbc_end_transaction(Connection, commit)
            ; throw(storage_error(90))
            ),
            Error,
            true
        ),
        ( var(Error)
        -> true
        ;  catch(odbc:odbc_end_transaction(Connection, rollback), _, true),
           ( Error = error(odbc(_, _, _), _)
           -> format(user_error, "ODBC error: ~w~n", [Error]),
              throw(storage_error(90))
           ;  throw(Error)  % storage_error/1, or a bug that must not be hidden
           )
        ).

    field_names([], []).
    field_names([field(Name, _, _)|Rest], [Name|Names]) :- field_names(Rest, Names).

    placeholders(Values, Marks) :-
        findall('?', member(_, Values), List),
        atomic_list_concat(List, ', ', Marks).

    assignments(Names, Assignments) :-
        findall(A, (member(N, Names), atom_concat(N, ' = ?', A)), List),
        atomic_list_concat(List, ', ', Assignments).

    % NULL never compares equal, so it needs IS NULL and takes no parameter.
    match_conditions(Names, Values, Where, Params) :-
        findall(C, ( nth0(I, Names, N), nth0(I, Values, V),
                     ( V == '$null$' -> atom_concat(N, ' IS NULL', C)
                     ; atom_concat(N, ' = ?', C) ) ), Conditions),
        atomic_list_concat(Conditions, ' AND ', Where),
        findall(V, (member(V, Values), V \== '$null$'), Params).

    bind_params([], [], []).
    bind_params([V|Vs], [T|Ts], [P|Ps]) :- bind_param(V, T, P), bind_params(Vs, Ts, Ps).

    % Integers beyond 32 bits go as text: integer/bigint binding truncates them,
    % and an integer bound to a varchar parameter is stored as a timestamp.
    bind_param(V, integer, V) :- integer(V), V >= -2147483648, V =< 2147483647, !.
    bind_param(V, double, V) :- float(V), !.
    bind_param('$null$', varchar(1), '$null$') :- !.
    bind_param(V, Type, V) :- compound(V), functor(V, Type, _), member(Type, [date, time, timestamp]), !.
    bind_param(V, _, _) :- compound(V), !,
        format(user_error, "ODBC error: cannot store ~w~n", [V]),
        throw(storage_error(90)).
    bind_param(V, varchar(Length), Text) :-
        format(atom(Text), '~w', [V]),
        atom_length(Text, L), Length is max(1, 4 * L).  % 4: UTF-8 bytes per character

    convert_rows_to_buffers([], []).
    convert_rows_to_buffers([Row|Rows], [Buffer|Buffers]) :-
        Row =.. [row|Buffer],
        convert_rows_to_buffers(Rows, Buffers).

:- end_object.
