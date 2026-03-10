%============================================================
% storage_csv.pl - CSV File Storage Backend
% Uses tuple format with CSV handle stored separately
%============================================================

:- module(storage_csv, [
    csv_open/3, csv_close/2, csv_create/2, csv_add/2, csv_get/3,
    csv_put/2, csv_delete/2, csv_next/2, csv_set/2,
    csv_records/2, csv_empty/2, csv_clear/2
]).

:- use_module(library(csv)).
:- use_module(storage_memory).
:- use_module(simulator_classes, [default_value/3]).

% CSV state tracked via assertz/retract
:- dynamic csv_state/2.  % csv_state(FilePath, dirty)

csv_open(FileName, file_state(Name,Pre,K,Fields,_,B,_,_), file_state(Name,Pre,K,Fields,Records,B,-1,true)) :-
    get_csv_path(FileName, Name, FilePath),
    ( exists_file(FilePath)
    -> load_csv_records(FilePath, Fields, Records),
       length(Records, Length),
       format("  [CSV: Loaded ~w records from ~w]~n", [Length, FilePath])
    ;  Records = [],
       format("  [CSV: File ~w not found, starting empty]~n", [FilePath])
    ),
    retractall(csv_state(FilePath, _)),
    assertz(csv_state(FilePath, false)).

csv_close(file_state(Name,Pre,K,Fields,Records,B,P,_), file_state(Name,Pre,K,Fields,Records,B,P,false)) :-
    get_csv_path(Name, Name, FilePath),
    ( csv_state(FilePath, true)
    -> save_csv_records(FilePath, Fields, Records),
       length(Records, Length),
       format("  [CSV: Saved ~w records to ~w]~n", [Length, FilePath])
    ;  true
    ),
    retractall(csv_state(FilePath, _)).

csv_create(file_state(Name,Pre,K,Fields,_,B,P,O), file_state(Name,Pre,K,Fields,[],B,P,O)) :-
    get_csv_path(Name, Name, FilePath),
    save_csv_records(FilePath, Fields, []),
    format("  [CSV: Created ~w]~n", [FilePath]),
    retractall(csv_state(FilePath, _)),
    assertz(csv_state(FilePath, false)).

csv_add(FSIn, FSOut) :- 
    storage_memory:mem_add(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_csv_path(Name, Name, FilePath),
    mark_dirty(FilePath).

csv_get(KeyInfo, FSIn, FSOut) :- storage_memory:mem_get(KeyInfo, FSIn, FSOut).

csv_put(FSIn, FSOut) :- 
    storage_memory:mem_put(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_csv_path(Name, Name, FilePath),
    mark_dirty(FilePath).

csv_delete(FSIn, FSOut) :- 
    storage_memory:mem_delete(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_csv_path(Name, Name, FilePath),
    mark_dirty(FilePath).

csv_next(FSIn, FSOut) :- storage_memory:mem_next(FSIn, FSOut).
csv_set(FSIn, FSOut) :- storage_memory:mem_set(FSIn, FSOut).
csv_records(FS, Count) :- storage_memory:mem_records(FS, Count).

csv_empty(FSIn, FSOut) :- 
    storage_memory:mem_empty(FSIn, FSOut),
    FSIn = file_state(Name,_,_,_,_,_,_,_),
    get_csv_path(Name, Name, FilePath),
    mark_dirty(FilePath).

csv_clear(FSIn, FSOut) :- storage_memory:mem_clear(FSIn, FSOut).

mark_dirty(FilePath) :-
    retractall(csv_state(FilePath, _)),
    assertz(csv_state(FilePath, true)).

get_csv_path(FileName, FallbackName, FilePath) :-
    ( atom(FileName), FileName \= FallbackName
    -> atom_string(FileName, FilePath)
    ;  atom_string(FallbackName, NameStr),
       string_lower(NameStr, LowerStr),
       string_concat(LowerStr, ".csv", FilePath)
    ).

load_csv_records(FilePath, Fields, Records) :-
    catch(
        (csv_read_file(FilePath, Rows, [functor(row), separator(0',), convert(true), strip(true)]),
         convert_rows_to_records(Rows, Fields, Records)),
        Error,
        (format(user_error, "CSV read error: ~w~n", [Error]), Records = [])
    ).

save_csv_records(FilePath, _Fields, Records) :-
    convert_records_to_rows(Records, Rows),
    catch(csv_write_file(FilePath, Rows, [separator(0',)]),
          Error, format(user_error, "CSV write error: ~w~n", [Error])).

convert_rows_to_records([], _, []).
convert_rows_to_records([Row|Rows], Fields, [Buffer|Buffers]) :-
    Row =.. [row|Values],
    pad_or_trim_values(Values, Fields, Buffer),
    convert_rows_to_records(Rows, Fields, Buffers).

convert_records_to_rows([], []).
convert_records_to_rows([Buffer|Buffers], [Row|Rows]) :-
    Row =.. [row|Buffer],
    convert_records_to_rows(Buffers, Rows).

pad_or_trim_values(Values, Fields, Buffer) :-
    length(Fields, FieldCount), length(Values, ValueCount),
    ( ValueCount >= FieldCount
    -> length(Buffer, FieldCount), append(Buffer, _, Values)
    ;  PadCount is FieldCount - ValueCount,
       get_default_padding(PadCount, Fields, ValueCount, Padding),
       append(Values, Padding, Buffer)
    ).

get_default_padding(0, _, _, []) :- !.
get_default_padding(N, Fields, StartIdx, [Default|Rest]) :-
    nth0(StartIdx, Fields, field(_, Type, Size)),
    default_value(Type, Size, Default),
    N1 is N - 1, StartIdx1 is StartIdx + 1,
    get_default_padding(N1, Fields, StartIdx1, Rest).
