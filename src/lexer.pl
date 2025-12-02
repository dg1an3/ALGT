%============================================================
% lexer.pl - Clarion Lexer
% Tokenizes Clarion source code into a list of tokens
%============================================================

:- module(lexer, [
    tokenize/2,
    tokenize_file/2
]).

%------------------------------------------------------------
% tokenize_file(+FileName, -Tokens)
% Read a file and tokenize its contents
%------------------------------------------------------------
tokenize_file(FileName, Tokens) :-
    read_file_to_string(FileName, String, []),
    string_codes(String, Codes),
    tokenize(Codes, Tokens).

%------------------------------------------------------------
% tokenize(+Codes, -Tokens)
% Convert character codes to tokens
%------------------------------------------------------------
tokenize(Codes, Tokens) :-
    phrase(tokens(Tokens), Codes).

%------------------------------------------------------------
% Token DCG rules
%------------------------------------------------------------
tokens([]) --> [].
tokens(Tokens) --> whitespace, tokens(Tokens).
tokens(Tokens) --> comment, tokens(Tokens).
tokens(Tokens) --> line_continuation, tokens(Tokens).
tokens([Token|Tokens]) --> token(Token), tokens(Tokens).

%------------------------------------------------------------
% Whitespace handling
%------------------------------------------------------------
whitespace --> [C], { code_type(C, space) }, whitespace_rest.
whitespace_rest --> [C], { code_type(C, space) }, whitespace_rest.
whitespace_rest --> [].

%------------------------------------------------------------
% Comment handling (! to end of line)
%------------------------------------------------------------
comment --> "!", comment_rest.
comment_rest --> "\n", !.
comment_rest --> "\r\n", !.
comment_rest --> [_], comment_rest.
comment_rest --> [].  % EOF

%------------------------------------------------------------
% Line continuation (| followed by optional whitespace and newline)
%Clarion uses | at end of line to continue statement on next line
%------------------------------------------------------------
line_continuation --> "|", line_cont_ws, line_cont_nl.

line_cont_ws --> [C], { C \= 10, C \= 13, code_type(C, space) }, line_cont_ws.
line_cont_ws --> [].

line_cont_nl --> "\r\n".
line_cont_nl --> "\n".

%------------------------------------------------------------
% Individual token types
%------------------------------------------------------------
token(Token) --> keyword_or_identifier(Token).
token(Token) --> string_literal(Token).
token(Token) --> number_literal(Token).
token(Token) --> operator(Token).
token(Token) --> punctuation(Token).

%------------------------------------------------------------
% Keywords and Identifiers
%------------------------------------------------------------
keyword_or_identifier(Token) -->
    identifier_chars(Chars),
    {
        Chars \= [],
        atom_codes(Atom, Chars),
        upcase_atom(Atom, Upper),
        ( keyword(Upper)
          -> Token = keyword(Upper)
          ;  Token = identifier(Atom)
        )
    }.

identifier_chars([C|Cs]) -->
    [C], { identifier_start(C) },
    identifier_rest(Cs).

identifier_rest([C|Cs]) -->
    [C], { identifier_cont(C) },
    !,
    identifier_rest(Cs).
identifier_rest([]) --> [].

identifier_start(C) :- code_type(C, alpha).
identifier_start(95).  % underscore

identifier_cont(C) :- code_type(C, alnum).
identifier_cont(95).  % underscore
identifier_cont(58).  % colon - Clarion uses : in prefixed names like Cust:Name
identifier_cont(35).  % hash - Clarion uses # suffix for auto-increment vars like i#

%------------------------------------------------------------
% Clarion Keywords
%------------------------------------------------------------
keyword('PROGRAM').
keyword('MAP').
keyword('END').
keyword('CODE').
keyword('PROCEDURE').
keyword('FUNCTION').
keyword('RETURN').
keyword('IF').
keyword('THEN').
keyword('ELSIF').
keyword('ELSE').
keyword('LOOP').
keyword('WHILE').
keyword('UNTIL').
keyword('TO').
keyword('BY').
keyword('BREAK').
keyword('CYCLE').
keyword('CASE').
keyword('OF').
keyword('DO').
keyword('ROUTINE').
keyword('EXIT').
keyword('MODULE').
keyword('MEMBER').
keyword('INCLUDE').
keyword('EQUATE').
keyword('GROUP').
keyword('QUEUE').
keyword('FILE').
keyword('RECORD').
keyword('KEY').
keyword('WINDOW').
keyword('REPORT').
keyword('CLASS').
keyword('INTERFACE').
keyword('VIRTUAL').
keyword('TYPE').
keyword('LIKE').
keyword('STRING').
keyword('LONG').
keyword('SHORT').
keyword('BYTE').
keyword('DECIMAL').
keyword('DATE').
keyword('TIME').
keyword('TRUE').
keyword('FALSE').
keyword('SELF').
keyword('PARENT').
keyword('AND').
keyword('OR').
keyword('NOT').
% Report keywords
keyword('HEADER').
keyword('FOOTER').
keyword('DETAIL').
keyword('PRINT').
keyword('BOX').
keyword('PAGE').
% Window keywords
keyword('ACCEPT').
keyword('SELECT').
keyword('BEEP').
keyword('DISPLAY').
keyword('PROMPT').
keyword('ENTRY').
keyword('BUTTON').
keyword('SPIN').

%------------------------------------------------------------
% String literals (single quoted)
%------------------------------------------------------------
string_literal(string(String)) -->
    "'", string_chars(Chars), "'",
    {
        atom_codes(String, Chars)
    }.

% Check for escaped quote FIRST (two single quotes = one embedded quote)
string_chars([39|Cs]) --> "''", !, string_chars(Cs).  % Escaped quote (single quote = 39)
% Regular character (not a single quote)
string_chars([C|Cs]) --> [C], { C \= 39 }, string_chars(Cs).  % single quote = 39
% Empty - must be last so escaped quotes at end of string are handled
string_chars([]) --> [].

%------------------------------------------------------------
% Number literals
%------------------------------------------------------------
number_literal(number(N)) -->
    digit_chars([D|Ds]),
    (
        ".", digit_chars(Frac)
        -> {
               append([D|Ds], [46|Frac], All),  % period = 46
               number_codes(N, All)
           }
        ;
        { number_codes(N, [D|Ds]) }
    ).

digit_chars([D|Ds]) -->
    [D], { code_type(D, digit) },
    digit_rest(Ds).

digit_rest([D|Ds]) -->
    [D], { code_type(D, digit) },
    !,
    digit_rest(Ds).
digit_rest([]) --> [].

%------------------------------------------------------------
% Operators
%------------------------------------------------------------
operator(op('<=')) --> "<=".
operator(op('>=')) --> ">=".
operator(op('<>')) --> "<>".
operator(op('+=')) --> "+=".
operator(op('-=')) --> "-=".
operator(op('*=')) --> "*=".
operator(op('/=')) --> "/=".
operator(op('=')) --> "=".
operator(op('<')) --> "<".
operator(op('>')) --> ">".
operator(op('+')) --> "+".
operator(op('-')) --> "-".
operator(op('*')) --> "*".
operator(op('/')) --> "/".
operator(op('%')) --> "%".
operator(op('&')) --> "&".
operator(op('|')) --> "|".
operator(op('^')) --> "^".
operator(op('~')) --> "~".

%------------------------------------------------------------
% Punctuation
%------------------------------------------------------------
punctuation(lparen) --> "(".
punctuation(rparen) --> ")".
punctuation(lbracket) --> "[".
punctuation(rbracket) --> "]".
punctuation(lbrace) --> "{".
punctuation(rbrace) --> "}".
punctuation(comma) --> ",".
punctuation(dot) --> ".".
punctuation(colon) --> ":".
punctuation(semicolon) --> ";".
punctuation(at) --> "@".
punctuation(hash) --> "#".
punctuation(question) --> "?".
punctuation(dollar) --> "$".

%============================================================
% Unit Tests
%============================================================

:- use_module(library(plunit)).

:- begin_tests(lexer).

test(tokenize_empty) :-
    string_codes("", Codes),
    tokenize(Codes, []).

test(tokenize_whitespace) :-
    string_codes("   ", Codes),
    tokenize(Codes, []).

test(tokenize_comment) :-
    string_codes("! this is a comment\n", Codes),
    tokenize(Codes, []).

test(tokenize_keyword) :-
    string_codes("PROGRAM", Codes),
    tokenize(Codes, [keyword('PROGRAM')]).

test(tokenize_keyword_lowercase) :-
    string_codes("program", Codes),
    tokenize(Codes, [keyword('PROGRAM')]).

test(tokenize_identifier) :-
    string_codes("MyVariable", Codes),
    tokenize(Codes, [identifier('MyVariable')]).

test(tokenize_prefixed_identifier) :-
    string_codes("Cust:Name", Codes),
    tokenize(Codes, [identifier('Cust:Name')]).

test(tokenize_string) :-
    string_codes("'hello world'", Codes),
    tokenize(Codes, [string('hello world')]).

test(tokenize_string_escaped_quote) :-
    string_codes("'it''s'", Codes),
    tokenize(Codes, [string('it''s')]).

test(tokenize_integer) :-
    string_codes("12345", Codes),
    tokenize(Codes, [number(12345)]).

test(tokenize_decimal) :-
    string_codes("123.45", Codes),
    tokenize(Codes, [number(123.45)]).

test(tokenize_operators) :-
    string_codes("+ - * / = <> <= >=", Codes),
    tokenize(Codes,
             [op('+'), op('-'), op('*'), op('/'), op('='),
              op('<>'), op('<='), op('>=')]).

test(tokenize_punctuation) :-
    string_codes("( ) [ ] , .", Codes),
    tokenize(Codes,
             [lparen, rparen, lbracket, rbracket, comma, dot]).

test(tokenize_line_continuation) :-
    string_codes("a |\n  b", Codes),
    tokenize(Codes, [identifier(a), identifier(b)]).

test(tokenize_simple_program) :-
    string_codes("PROGRAM\nMAP\nEND\nCODE\n", Codes),
    tokenize(Codes,
             [keyword('PROGRAM'), keyword('MAP'), keyword('END'), keyword('CODE')]).

test(tokenize_file, [nondet]) :-
    tokenize_file('examples/hello_world.clw', Tokens),
    member(keyword('PROGRAM'), Tokens),
    member(keyword('CODE'), Tokens).

:- end_tests(lexer).



:- begin_tests(lexer_files).

test(tokenize_example_files) :-
    test_files(Files),
    forall(member(File, Files),
           assertion(tokenize_file(File, _))).

:- end_tests(lexer_files).