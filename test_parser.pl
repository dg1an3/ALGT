#!/usr/bin/env swipl
%============================================================
% test_parser.pl - Test the Clarion parser
% Run with: swipl test_parser.pl
%============================================================

:- use_module(src/clarion).
:- use_module(src/lexer).
:- use_module(src/parser).

%------------------------------------------------------------
% Test tokenizer
%------------------------------------------------------------
test_tokenizer :-
    format("~n=== Testing Tokenizer ===~n~n", []),
    tokenize_file('examples/hello_world.clw', Tokens),
    format("Tokens:~n", []),
    print_tokens(Tokens).

print_tokens([]).
print_tokens([T|Ts]) :-
    format("  ~w~n", [T]),
    print_tokens(Ts).

%------------------------------------------------------------
% Test parser
%------------------------------------------------------------
test_parser :-
    format("~n=== Testing Parser ===~n~n", []),
    analyze_file('examples/hello_world.clw').

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
