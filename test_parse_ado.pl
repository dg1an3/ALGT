:- consult('src/parser.pl').
:- consult('src/lexer.pl').

% Define the path to the example file
:- dynamic example_file_path/1.
example_file_path('examples/ado_sql_example.clw').

% Goal to parse the example file
test_ado_sql_parsing :-
    example_file_path(Path),
    format('Attempting to tokenize: ~w~n', [Path]),
    (   catch(lexer:tokenize_file(Path, Tokens), E, (print_message(error, E), fail))
    ->  format('Tokenization successful.~n'),
        %format('Tokens: ~w~n', [Tokens]), % Keep this commented for brevity unless needed

        format('Attempting to parse tokens...~n'),
        (   phrase(parser:program(AST), Tokens)
        ->  format('Parsing successful.~nAST: ~w~n', [AST])
        ;   format('Parsing failed for tokens.~n')
        )
    ;   format('Tokenization failed for ~w~n', [Path])
    ).

% Entry point for running the test
:- initialization(test_ado_sql_parsing).
