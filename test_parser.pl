#!/usr/bin/env swipl
%============================================================
% test_parser.pl - Test the Clarion parser
% Run with: swipl test_parser.pl
%============================================================

:- use_module(src/clarion).
:- use_module(src/lexer).
:- use_module(src/parser).

%------------------------------------------------------------
% Test files
%------------------------------------------------------------
test_files([
    'examples/class_example.clw',
    'examples/control_flow.clw',
    'examples/data_types.clw',
    'examples/file_io.clw',
    'examples/hello_world.clw',
    'examples/queue_example.clw',
    'examples/report_example.clw',
    'examples/sql_example.clw',
    'examples/string_functions.clw',
    'examples/window_example.clw'
]).

%------------------------------------------------------------
% Test tokenizer
%------------------------------------------------------------
test_tokenizer_file(File) :-
    format("~n--- Tokenizing ~w ---~n", [File]),
    (   tokenize_file(File, Tokens)
    ->  print_tokens(Tokens)
    ;   format("Failed to tokenize ~w~n", [File])
    ).

test_tokenizer :-
    format("~n=== Testing Tokenizer ===~n", []),
    test_files(Files),
    maplist(test_tokenizer_file, Files).

print_tokens([]).
print_tokens([T|Ts]) :-
    format("  ~w~n", [T]),
    print_tokens(Ts).

%------------------------------------------------------------
% Test parser
%------------------------------------------------------------
test_parser_file(File) :-
    format("~n--- Parsing ~w ---~n", [File]),
    (   analyze_file(File)
    ->  format("Successfully parsed ~w~n", [File])
    ;   format("Failed to parse ~w~n", [File])
    ).

test_parser :-
    format("~n=== Testing Parser ===~n", []),
    test_files(Files),
    maplist(test_parser_file, Files).

%------------------------------------------------------------
% Run all tests
%------------------------------------------------------------
run_tests :-
    format("Clarion Parser Tests~n", []),
    format("====================~n", []),
    test_tokenizer,
    test_parser,
    format("~nAll tests completed.~n", []).

%------------------------------------------------------------
% Auto-run on load
%------------------------------------------------------------
:- initialization(run_tests, main).
