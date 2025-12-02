%============================================================
% storage_backend.pl - Storage Backend Dispatcher
%
% Routes file operations to appropriate backend based on
% DRIVER attribute:
%   - ODBC/ADO → storage_odbc.pl (database)
%   - ASCII/BASIC → storage_csv.pl (CSV files)
%   - TOPSPEED/none → storage_memory.pl (in-memory)
%============================================================

:- module(storage_backend, [
    storage_open/4,
    storage_close/3,
    storage_create/3,
    storage_add/3,
    storage_get/4,
    storage_put/3,
    storage_delete/3,
    storage_next/3,
    storage_set/3,
    storage_records/3,
    storage_empty/3,
    storage_clear/3,
    get_backend/2
]).

:- use_module(storage_memory).
:- use_module(storage_csv).
:- use_module(storage_odbc).

% Backend Selection
get_backend(Driver, odbc) :-
    atom(Driver), atom_string(Driver, DriverStr),
    ( DriverStr = "ODBC" ; DriverStr = "ADO" ), !.
get_backend(Driver, csv) :-
    atom(Driver), atom_string(Driver, DriverStr),
    ( DriverStr = "ASCII" ; DriverStr = "BASIC" ; DriverStr = "DOS" ), !.
get_backend(_, memory).

% OPEN
storage_open(Driver, FileName, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_open(B, FileName, FSIn, FSOut).
dispatch_open(memory, _, FSIn, FSOut) :- storage_memory:mem_open(FSIn, FSOut).
dispatch_open(csv, FN, FSIn, FSOut) :- storage_csv:csv_open(FN, FSIn, FSOut).
dispatch_open(odbc, FN, FSIn, FSOut) :- storage_odbc:odbc_open(FN, FSIn, FSOut).

% CLOSE
storage_close(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_close(B, FSIn, FSOut).
dispatch_close(memory, FSIn, FSOut) :- storage_memory:mem_close(FSIn, FSOut).
dispatch_close(csv, FSIn, FSOut) :- storage_csv:csv_close(FSIn, FSOut).
dispatch_close(odbc, FSIn, FSOut) :- storage_odbc:odbc_close(FSIn, FSOut).

% CREATE
storage_create(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_create(B, FSIn, FSOut).
dispatch_create(memory, FS, FS).
dispatch_create(csv, FSIn, FSOut) :- storage_csv:csv_create(FSIn, FSOut).
dispatch_create(odbc, FS, FS).

% ADD
storage_add(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_add(B, FSIn, FSOut).
dispatch_add(memory, FSIn, FSOut) :- storage_memory:mem_add(FSIn, FSOut).
dispatch_add(csv, FSIn, FSOut) :- storage_csv:csv_add(FSIn, FSOut).
dispatch_add(odbc, FSIn, FSOut) :- storage_odbc:odbc_add(FSIn, FSOut).

% GET
storage_get(Driver, KI, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_get(B, KI, FSIn, FSOut).
dispatch_get(memory, KI, FSIn, FSOut) :- storage_memory:mem_get(KI, FSIn, FSOut).
dispatch_get(csv, KI, FSIn, FSOut) :- storage_csv:csv_get(KI, FSIn, FSOut).
dispatch_get(odbc, KI, FSIn, FSOut) :- storage_odbc:odbc_get(KI, FSIn, FSOut).

% PUT
storage_put(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_put(B, FSIn, FSOut).
dispatch_put(memory, FSIn, FSOut) :- storage_memory:mem_put(FSIn, FSOut).
dispatch_put(csv, FSIn, FSOut) :- storage_csv:csv_put(FSIn, FSOut).
dispatch_put(odbc, FSIn, FSOut) :- storage_odbc:odbc_put(FSIn, FSOut).

% DELETE
storage_delete(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_delete(B, FSIn, FSOut).
dispatch_delete(memory, FSIn, FSOut) :- storage_memory:mem_delete(FSIn, FSOut).
dispatch_delete(csv, FSIn, FSOut) :- storage_csv:csv_delete(FSIn, FSOut).
dispatch_delete(odbc, FSIn, FSOut) :- storage_odbc:odbc_delete(FSIn, FSOut).

% NEXT
storage_next(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_next(B, FSIn, FSOut).
dispatch_next(memory, FSIn, FSOut) :- storage_memory:mem_next(FSIn, FSOut).
dispatch_next(csv, FSIn, FSOut) :- storage_csv:csv_next(FSIn, FSOut).
dispatch_next(odbc, FSIn, FSOut) :- storage_odbc:odbc_next(FSIn, FSOut).

% SET
storage_set(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_set(B, FSIn, FSOut).
dispatch_set(memory, FSIn, FSOut) :- storage_memory:mem_set(FSIn, FSOut).
dispatch_set(csv, FSIn, FSOut) :- storage_csv:csv_set(FSIn, FSOut).
dispatch_set(odbc, FSIn, FSOut) :- storage_odbc:odbc_set(FSIn, FSOut).

% RECORDS
storage_records(Driver, FS, Count) :-
    get_backend(Driver, B), dispatch_records(B, FS, Count).
dispatch_records(memory, FS, C) :- storage_memory:mem_records(FS, C).
dispatch_records(csv, FS, C) :- storage_csv:csv_records(FS, C).
dispatch_records(odbc, FS, C) :- storage_odbc:odbc_records(FS, C).

% EMPTY
storage_empty(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_empty(B, FSIn, FSOut).
dispatch_empty(memory, FSIn, FSOut) :- storage_memory:mem_empty(FSIn, FSOut).
dispatch_empty(csv, FSIn, FSOut) :- storage_csv:csv_empty(FSIn, FSOut).
dispatch_empty(odbc, FSIn, FSOut) :- storage_odbc:odbc_empty(FSIn, FSOut).

% CLEAR
storage_clear(Driver, FSIn, FSOut) :-
    get_backend(Driver, B), dispatch_clear(B, FSIn, FSOut).
dispatch_clear(memory, FSIn, FSOut) :- storage_memory:mem_clear(FSIn, FSOut).
dispatch_clear(csv, FSIn, FSOut) :- storage_csv:csv_clear(FSIn, FSOut).
dispatch_clear(odbc, FSIn, FSOut) :- storage_odbc:odbc_clear(FSIn, FSOut).
