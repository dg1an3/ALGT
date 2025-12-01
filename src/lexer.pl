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
% Clarion uses | at end of line to continue statement on next line
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
    { Chars \= [],
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
    { atom_codes(String, Chars) }.

string_chars([]) --> [].
string_chars([39|Cs]) --> "''", !, string_chars(Cs).  % Escaped quote (single quote = 39)
string_chars([C|Cs]) --> [C], { C \= 39 }, string_chars(Cs).  % single quote = 39

%------------------------------------------------------------
% Number literals
%------------------------------------------------------------
number_literal(number(N)) -->
    digit_chars([D|Ds]),
    ( ".", digit_chars(Frac)
      -> { append([D|Ds], [46|Frac], All),  % period = 46
           number_codes(N, All) }
      ;  { number_codes(N, [D|Ds]) }
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
