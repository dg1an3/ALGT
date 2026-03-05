% clarion.pl — Convenience re-export of parser + interpreter
%
% Imports both clarion_parser and clarion_interpreter so existing code
% that does `:- use_module(clarion).` continues to work unchanged.

:- module(clarion, [
    parse_clarion/2,
    exec_procedure/4,
    init_file_io/0,
    set_trace/1,
    get_trace/1,
    clear_trace/0,
    print_trace/0,
    program//1
]).

:- use_module(clarion_parser).
:- use_module(clarion_interpreter).

:- reexport(clarion_parser).
:- reexport(clarion_interpreter).
