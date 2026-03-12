%============================================================
% storage_backend.pl - Storage Backend Dispatcher (Logtalk Bridge)
%
% Thin Prolog module wrapper that delegates to Logtalk
% storage_dispatcher and storage_memory objects.
%
% Routes file operations to appropriate backend based on
% DRIVER attribute:
%   - ODBC/ADO → storage_odbc (database)
%   - ASCII/BASIC → storage_csv (CSV files)
%   - TOPSPEED/none → storage_memory (in-memory)
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
    get_backend/2,
    ensure_logtalk_backends/0
]).

:- use_module(library(logtalk)).

%% ensure_logtalk_backends is det.
%  Loads the Logtalk storage/UI backend objects if not already loaded.
:- dynamic logtalk_backends_loaded/0.

ensure_logtalk_backends :-
    logtalk_backends_loaded, !.
ensure_logtalk_backends :-
    logtalk_load([
        storage_protocol,
        ui_protocol,
        storage_memory,
        storage_csv,
        storage_odbc,
        storage_dispatcher,
        ui_simulation,
        ui_dispatcher
    ]),
    assert(logtalk_backends_loaded).

:- ensure_logtalk_backends.

% Backend Selection — delegates to storage_dispatcher Logtalk object
get_backend(Driver, Backend) :-
    storage_dispatcher::get_backend(Driver, BackendObj),
    backend_atom(BackendObj, Backend).

backend_atom(storage_memory, memory).
backend_atom(storage_csv, csv).
backend_atom(storage_odbc, odbc).

% All operations delegate to storage_dispatcher Logtalk object
storage_open(Driver, FileName, FSIn, FSOut) :-
    storage_dispatcher::open(Driver, FileName, FSIn, FSOut).

storage_close(Driver, FSIn, FSOut) :-
    storage_dispatcher::close(Driver, FSIn, FSOut).

storage_create(Driver, FSIn, FSOut) :-
    storage_dispatcher::create(Driver, FSIn, FSOut).

storage_add(Driver, FSIn, FSOut) :-
    storage_dispatcher::add(Driver, FSIn, FSOut).

storage_get(Driver, KeyInfo, FSIn, FSOut) :-
    storage_dispatcher::get(Driver, KeyInfo, FSIn, FSOut).

storage_put(Driver, FSIn, FSOut) :-
    storage_dispatcher::put(Driver, FSIn, FSOut).

storage_delete(Driver, FSIn, FSOut) :-
    storage_dispatcher::delete(Driver, FSIn, FSOut).

storage_next(Driver, FSIn, FSOut) :-
    storage_dispatcher::next(Driver, FSIn, FSOut).

storage_set(Driver, FSIn, FSOut) :-
    storage_dispatcher::set(Driver, FSIn, FSOut).

storage_records(Driver, FS, Count) :-
    storage_dispatcher::records(Driver, FS, Count).

storage_empty(Driver, FSIn, FSOut) :-
    storage_dispatcher::empty(Driver, FSIn, FSOut).

storage_clear(Driver, FSIn, FSOut) :-
    storage_dispatcher::clear(Driver, FSIn, FSOut).
