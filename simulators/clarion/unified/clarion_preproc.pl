%============================================================
% clarion_preproc.pl - Conditional-compile pre-pass for Clarion source
%
% Handles the COMPILE / OMIT directives before the DCG parser sees
% the source:
%
%   COMPILE('term' [, expr])   lines up to the line containing 'term'
%                              are kept if expr is true (or no expr)
%   OMIT('term' [, expr])      lines up to the line containing 'term'
%                              are dropped if expr is true (or no expr)
%
% Line numbers are preserved: removed lines become empty lines, so
% parser positions still map back to the original file.
%
% Terminator line: when the block is kept, a terminator line that holds
% nothing but the terminator (e.g. a column-1 label __ENDCODECOVERAGE__)
% is blanked; any other terminator line (e.g. a comment) is kept.
% When the block is dropped, the terminator line is dropped with it.
%
% Expressions: Name, Number, Name = N, Name <> N, Name > N, Name < N,
% Name >= N, Name <= N. Names are looked up in Defines (Name=Value
% pairs, case-insensitive); undefined names are 0. An expression that
% cannot be parsed is treated as false (with a warning on user_error).
%============================================================

:- module(clarion_preproc, [
    preprocess_codes/3        % preprocess_codes(+Codes, +Defines, -OutCodes)
]).

:- use_module(library(assoc)).
:- use_module(library(apply)).

:- set_prolog_flag(double_quotes, codes).

preprocess_codes(Codes, Defines, Out) :-
    split_lines(Codes, Lines),
    process_lines(Lines, Defines, [], OutLines),
    join_lines(OutLines, Conditional),
    canonical_case(Conditional, Out).

%------------------------------------------------------------
% Case folding
%
% Clarion labels ignore case, but everything after the parser compares
% atoms. Respell each word one way, so 'ABC' and 'abc' become one name:
% the spelling of its first label (Clarion labels start in column 1), else
% its first use. String literals and comments are untouched.
% A:B and A.B are respelled part by part.
%------------------------------------------------------------

canonical_case(Codes, Out) :-
    empty_assoc(Empty),
    findall(W, seed_word(W), Seeds),
    foldl(seed_spelling, Seeds, Empty, Seeded),
    column_labels(Codes, Labels),
    foldl(label_spelling, Labels, Seeded, Spellings),
    respell(Codes, Spellings, Out).

% Spellings the simulator itself matches on
seed_word('Record').
seed_word('EVENT').
seed_word('BUTTON').
seed_word('ICON').
seed_word('PROP').
seed_word('Accepted').
seed_word('NewSelection').
seed_word('OpenWindow').
seed_word('CloseWindow').
seed_word('MemCopy').
seed_word('Result').

seed_spelling(Word, A0, A) :-
    upcase_atom(Word, Key),
    atom_codes(Word, Codes),
    put_assoc(Key, A0, Codes, A).

% Words of the label at the start of each line (both parts of A:B)
column_labels(Codes, Words) :-
    split_lines(Codes, Lines),
    findall(Word,
            ( member([C|Line], Lines), label_start(C),
              label_word([C|Line], Word) ),
            Words).

label_word(Line, Word) :-
    take_word(Line, W, Rest),
    (   Word = W
    ;   Rest = [0':, C|More], label_start(C), label_word([C|More], Word)
    ).

label_spelling(Word, A0, A) :-
    atom_codes(Atom, Word),
    upcase_atom(Atom, Key),
    ( get_assoc(Key, A0, _) -> A = A0 ; put_assoc(Key, A0, Word, A) ).

respell([], _, []).
respell([0'\'|T], A, [0'\'|Out]) :- !,
    copy_literal(T, Rest, Out, OutRest),
    respell(Rest, A, OutRest).
respell([0'!|T], A, [0'!|Out]) :- !,
    copy_line(T, Rest, Out, OutRest),
    respell(Rest, A, OutRest).
respell([C|T], A, Out) :-
    label_start(C), !,
    take_word([C|T], Word, Rest),
    atom_codes(Atom, Word),
    upcase_atom(Atom, Key),
    ( get_assoc(Key, A, Spelling)
    -> A1 = A
    ;  Spelling = Word, put_assoc(Key, A, Word, A1)
    ),
    append(Spelling, OutRest, Out),
    respell(Rest, A1, OutRest).
respell([C|T], A, Out) :-
    code_type(C, digit), !,       % numbers, including 0FFh: copy whole
    take_word([C|T], Word, Rest),
    append(Word, OutRest, Out),
    respell(Rest, A, OutRest).
respell([C|T], A, [C|Out]) :-
    respell(T, A, Out).

label_start(0'_).
label_start(C) :- code_type(C, alpha).

take_word([C|T], [C|W], Rest) :-
    ( C =:= 0'_ ; code_type(C, alnum) ), !,
    take_word(T, W, Rest).
take_word(Rest, [], Rest).

% Inside '...': copy to the closing quote (a doubled quote reopens it), but
% never past the end of the line.
copy_literal([], [], Out, Out).
copy_literal([C|T], T, [C|Out], Out) :- ( C =:= 0'\' ; C =:= 10 ), !.
copy_literal([C|T], Rest, [C|Out], OutRest) :- copy_literal(T, Rest, Out, OutRest).

copy_line([], [], Out, Out).
copy_line([10|T], T, [10|Out], Out) :- !.
copy_line([C|T], Rest, [C|Out], OutRest) :- copy_line(T, Rest, Out, OutRest).

%------------------------------------------------------------
% Line splitting (keeps \r so output is byte-identical where untouched)
%------------------------------------------------------------

split_lines(Codes, Lines) :-
    (   append(Line, [0'\n|Rest], Codes)
    ->  Lines = [Line|Ls], split_lines(Rest, Ls)
    ;   Lines = [Codes]
    ).

join_lines([L], L) :- !.
join_lines([L|Ls], Out) :-
    join_lines(Ls, Rest),
    append(L, [0'\n|Rest], Out).

blank_line(Line, Blank) :-                 % keep a trailing \r for CRLF files
    ( append(_, [0'\r], Line) -> Blank = [0'\r] ; Blank = [] ).

%------------------------------------------------------------
% Main loop. Stack holds terminators of COMPILE/OMIT blocks that are
% currently being kept (so their terminator line can be handled).
%------------------------------------------------------------

process_lines([], _, _, []).
process_lines([Line|Rest], Defines, Stack, [Out|Outs]) :-
    (   directive(Line, Kind, Term, Cond0)
    ->  eval_cond(Cond0, Defines, Cond),
        keep_block(Kind, Cond, Keep),
        blank_line(Line, Out),
        (   Keep == true
        ->  process_lines(Rest, Defines, [Term|Stack], Outs)
        ;   drop_until(Rest, Term, Dropped, After),
            append(Dropped, Outs1, Outs),
            process_lines(After, Defines, Stack, Outs1)
        )
    ;   select_term(Line, Stack, Term, Stack1)
    ->  ( only_terminator(Line, Term) -> blank_line(Line, Out) ; Out = Line ),
        process_lines(Rest, Defines, Stack1, Outs)
    ;   Out = Line,
        process_lines(Rest, Defines, Stack, Outs)
    ).

keep_block(compile, Cond, Cond).
keep_block(omit, true, false).
keep_block(omit, false, true).

% Drop lines up to and including the one containing Term
drop_until([], _, [], []).
drop_until([L|Ls], Term, [B|Bs], After) :-
    blank_line(L, B),
    (   contains(L, Term)
    ->  Bs = [], After = Ls
    ;   drop_until(Ls, Term, Bs, After)
    ).

select_term(Line, Stack, Term, Stack1) :-
    select(Term, Stack, Stack1),
    contains(Line, Term), !.

contains(Line, Term) :- append(_, Suffix, Line), append(Term, _, Suffix), !.

only_terminator(Line, Term) :-
    trim(Line, T), T == Term.

trim(L, T) :-
    exclude_leading_ws(L, L1),
    reverse(L1, R1), exclude_leading_ws(R1, R2), reverse(R2, T).
exclude_leading_ws([C|Cs], T) :- C =< 32, !, exclude_leading_ws(Cs, T).
exclude_leading_ws(T, T).

%------------------------------------------------------------
% Directive recognition: [ws] COMPILE|OMIT ( 'term' [, expr] ) [! comment]
%------------------------------------------------------------

directive(Line, Kind, Term, Cond) :-
    phrase((sp, dir_kw(Kind), sp, "(", sp, "'", qchars(Term), "'", sp,
            dir_cond(Cond), sp, ")", sp, rest_ok), Line).

dir_kw(compile) --> ci("COMPILE"), \+ ident_char.
dir_kw(omit)    --> ci("OMIT"), \+ ident_char.

dir_cond(Cs) --> ",", sp, cond_chars(Cs).
dir_cond(none) --> [].

cond_chars([C|Cs]) --> [C], { C \== 0') }, !, cond_chars(Cs).
cond_chars([]) --> [].

rest_ok --> "!", remainder_any.
rest_ok --> "\r".
rest_ok --> [].
remainder_any --> [_], !, remainder_any.
remainder_any --> [].

ident_char, [C] --> [C], { code_type(C, csym) }.

ci([]) --> [].
ci([K|Ks]) --> [C], { upcase(C, U), U == K }, ci(Ks).
upcase(C, U) :- C >= 0'a, C =< 0'z, !, U is C - 32.
upcase(C, C).

sp --> [C], { C == 0' ; C == 0'\t }, !, sp.
sp --> [].

qchars([0''|Cs]) --> "''", !, qchars(Cs).
qchars([C|Cs]) --> [C], { C \== 0'' }, !, qchars(Cs).
qchars([]) --> [].

%------------------------------------------------------------
% Condition evaluation
%------------------------------------------------------------

eval_cond(none, _, true) :- !.
eval_cond(Codes, Defines, Result) :-
    (   phrase((sp, cond_expr(E), sp), Codes)
    ->  ( cond_value(E, Defines) -> Result = true ; Result = false )
    ;   format(user_error, "Warning: clarion_preproc: cannot evaluate condition '~s', treated as false~n", [Codes]),
        Result = false
    ).

cond_expr(cmp(Op, L, R)) --> operand(L), sp, cmp_op(Op), sp, operand(R), !.
cond_expr(truthy(X)) --> operand(X).

cmp_op(>=) --> ">=".
cmp_op(=<) --> "<=".
cmp_op(\=) --> "<>".
cmp_op(=)  --> "=".
cmp_op(>)  --> ">".
cmp_op(<)  --> "<".

operand(num(N)) --> digits1(Ds), !, { number_codes(N, Ds) }.
operand(name(A)) --> name_chars(Cs), { Cs \== [], atom_codes(A0, Cs), upcase_atom(A0, A) }.

digits1([D|Ds]) --> [D], { code_type(D, digit) }, digits0(Ds).
digits0([D|Ds]) --> [D], { code_type(D, digit) }, !, digits0(Ds).
digits0([]) --> [].
name_chars([C|Cs]) --> [C], { code_type(C, csym) ; C == 0': }, !, name_chars(Cs).
name_chars([]) --> [].

operand_value(num(N), _, N).
operand_value(name(A), Defines, V) :-
    (   member(K=V0, Defines), upcase_atom(K, A) -> V = V0 ; V = 0 ).

cond_value(truthy(X), Defines) :- operand_value(X, Defines, V), V \== 0.
cond_value(cmp(Op, L, R), Defines) :-
    operand_value(L, Defines, LV), operand_value(R, Defines, RV),
    compare_values(Op, LV, RV).

compare_values(=,  A, B) :- A =:= B.
compare_values(\=, A, B) :- A =\= B.
compare_values(>,  A, B) :- A > B.
compare_values(<,  A, B) :- A < B.
compare_values(>=, A, B) :- A >= B.
compare_values(=<, A, B) :- A =< B.
