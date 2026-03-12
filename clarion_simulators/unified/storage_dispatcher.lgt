%============================================================
% storage_dispatcher.lgt - Storage Backend Dispatcher (Logtalk)
%
% Routes file operations to appropriate backend object based on
% DRIVER attribute:
%   - ODBC/ADO    → storage_odbc
%   - ASCII/BASIC → storage_csv
%   - TOPSPEED/none → storage_memory
%
% Usage:
%   storage_dispatcher::get_backend('ODBC', Backend),
%   Backend::open(FileName, FSIn, FSOut).
%
% Or use convenience predicates that dispatch automatically:
%   storage_dispatcher::open('ODBC', FileName, FSIn, FSOut).
%============================================================

:- object(storage_dispatcher).

    :- public([
        get_backend/2,     % (Driver, BackendObject)
        open/4,            % (Driver, FileName, FSIn, FSOut)
        close/3,           % (Driver, FSIn, FSOut)
        create/3,          % (Driver, FSIn, FSOut)
        add/3,             % (Driver, FSIn, FSOut)
        get/4,             % (Driver, KeyInfo, FSIn, FSOut)
        put/3,             % (Driver, FSIn, FSOut)
        delete/3,          % (Driver, FSIn, FSOut)
        next/3,            % (Driver, FSIn, FSOut)
        set/3,             % (Driver, FSIn, FSOut)
        records/3,         % (Driver, FS, Count)
        empty/3,           % (Driver, FSIn, FSOut)
        clear/3            % (Driver, FSIn, FSOut)
    ]).

    % Backend Selection
    get_backend(Driver, storage_odbc) :-
        atom(Driver), atom_string(Driver, DriverStr),
        ( DriverStr = "ODBC" ; DriverStr = "ADO" ), !.
    get_backend(Driver, storage_csv) :-
        atom(Driver), atom_string(Driver, DriverStr),
        ( DriverStr = "ASCII" ; DriverStr = "BASIC" ), !.
    get_backend(_, storage_memory).

    % Dispatched operations
    open(Driver, FileName, FSIn, FSOut) :-
        get_backend(Driver, B), B::open(FileName, FSIn, FSOut).

    close(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::close(FSIn, FSOut).

    create(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::create(FSIn, FSOut).

    add(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::add(FSIn, FSOut).

    get(Driver, KeyInfo, FSIn, FSOut) :-
        get_backend(Driver, B), B::get(KeyInfo, FSIn, FSOut).

    put(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::put(FSIn, FSOut).

    delete(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::delete(FSIn, FSOut).

    next(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::next(FSIn, FSOut).

    set(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::set(FSIn, FSOut).

    records(Driver, FS, Count) :-
        get_backend(Driver, B), B::records(FS, Count).

    empty(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::empty(FSIn, FSOut).

    clear(Driver, FSIn, FSOut) :-
        get_backend(Driver, B), B::clear(FSIn, FSOut).

:- end_object.
