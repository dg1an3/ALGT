%============================================================
% clarion_types.pl - Clarion value conversion and comparison
%
% coerce/4 converts a value to a declared type on assignment:
% fixed-length padding and truncation, integer wrap-around, and
% string/number conversion. Values that are not text or numbers
% (arrays, groups, instances, '$null$') pass through unchanged.
%============================================================

:- module(clarion_types, [
    coerce/4,            % +Type, +Size, +Value, -Coerced
    split_type/3,        % +TypeTerm, -Type, -Size
    type_bytes/3,        % +Type, +Size, -Bytes
    type_default/3,      % +Type, +Size, -Value
    compare_values/3,    % -Order, +A, +B
    same_values/3,       % +As, +Bs, +KeyAttrs
    compare_keys/4,      % -Order, +As, +Bs, +KeyAttrs
    text_number/2,       % +Text, -Number (fails if not numeric)
    to_number/2,         % +Value, -Number (non-numeric text is 0)
    clip_text/2,         % +Text, -String without trailing spaces
    is_text/1,
    text_type/1
]).

text_type('STRING').
text_type('CSTRING').
text_type('PSTRING').

is_text(V) :- string(V), !.
is_text(V) :- atom(V), V \== '$null$', V \== none, V \== omitted, V \== [].

% Type terms: 'LONG', typed('STRING', size(20)), ref(Type)
split_type(ref(T), Type, Size) :- !, split_type(T, Type, Size).
split_type(typed(Type, Size), Type, Size) :- !.
split_type(Type, Type, none).

type_default(Type, Size, Value) :-
    text_type(Type), !,
    coerce(Type, Size, "", Value).
type_default('REAL', _, 0.0) :- !.
type_default('SREAL', _, 0.0) :- !.
type_default(_, _, 0).

type_bytes('BYTE', _, 1) :- !.
type_bytes('SHORT', _, 2) :- !.
type_bytes('USHORT', _, 2) :- !.
type_bytes('REAL', _, 8) :- !.
type_bytes(Type, size(N), N) :- text_type(Type), !.
type_bytes(Type, size(Digits), N) :-          % packed two digits to a byte
    ( Type == 'DECIMAL' ; Type == 'PDECIMAL' ), !,
    N is Digits // 2 + 1.
type_bytes(_, _, 4).

%------------------------------------------------------------
% Assignment conversion
%------------------------------------------------------------

coerce(Type, Size, Value, Coerced) :-
    ( is_text(Value) ; number(Value) ), !,
    coerce_(Type, Size, Value, Coerced).
coerce(_, _, Value, Value).

coerce_('STRING', Size, V, S) :- !,
    text_string(V, S0),
    ( Size = size(N) -> fit(N, S0, S) ; S = S0 ).
coerce_(Type, Size, V, S) :-
    ( Type == 'CSTRING' ; Type == 'PSTRING' ), !,   % one byte is the terminator / length
    text_string(V, S0),
    ( Size = size(N), Max is N - 1, string_length(S0, L), L > Max
    -> sub_string(S0, 0, Max, _, S)
    ;  S = S0
    ).
coerce_(Type, _, V, N) :-
    integer_range(Type, Bits, Signed), !,
    to_number(V, N0),
    I is truncate(N0),
    wrap(Signed, Bits, I, N).
coerce_(Type, _, V, N) :-
    member(Type, ['REAL', 'SREAL', 'DECIMAL', 'PDECIMAL']), !,
    to_number(V, N).
coerce_(_, _, V, V).

integer_range('BYTE', 8, unsigned).
integer_range('SHORT', 16, signed).
integer_range('USHORT', 16, unsigned).
integer_range('LONG', 32, signed).
integer_range('ULONG', 32, unsigned).
integer_range('DATE', 32, signed).
integer_range('TIME', 32, signed).

wrap(unsigned, Bits, I, N) :- N is I mod (1 << Bits).
wrap(signed, Bits, I, N) :-
    Half is 1 << (Bits - 1),
    N is (I + Half) mod (1 << Bits) - Half.

fit(N, S0, S) :-
    string_length(S0, L),
    ( L >= N
    -> sub_string(S0, 0, N, _, S)
    ;  Pad is N - L,
       format(string(S), "~s~*c", [S0, Pad, 0' ])
    ).

text_string(V, S) :- string(V), !, S = V.
text_string(V, S) :- atom(V), !, atom_string(V, S).
text_string(V, S) :- number_text(V, S).

number_text(V, S) :- float(V), V =:= truncate(V), abs(V) < 1.0e15, !,
    I is truncate(V), number_string(I, S).
number_text(V, S) :- number_string(V, S).

clip_text(V, Clipped) :-
    text_string(V, S),
    string_codes(S, Codes),
    reverse(Codes, Rev),
    drop_spaces(Rev, RevClipped),
    reverse(RevClipped, ClippedCodes),
    string_codes(Clipped, ClippedCodes).

drop_spaces([0' |T], Rest) :- !, drop_spaces(T, Rest).
drop_spaces(L, L).

text_number(V, N) :-
    text_string(V, S0),
    normalize_space(string(S), S0),
    ( S == "" -> N = 0
    ; string_concat("+", S1, S) -> number_only(S1, N)
    ; number_only(S, N)
    ).

number_only(S, N) :-
    string_codes(S, Codes),
    forall(member(C, Codes), memberchk(C, `0123456789.-eE`)),
    ( string_concat(".", _, S) -> string_concat("0", S, S1) ; S1 = S ),
    catch(number_string(N, S1), _, fail),
    number(N).

to_number(V, N) :- number(V), !, N = V.
to_number(V, N) :- is_text(V), text_number(V, N0), !, N = N0.
to_number(_, 0).

%------------------------------------------------------------
% Comparison
%------------------------------------------------------------

% Numbers compare numerically. Text ignores trailing spaces. A number and
% numeric text compare as numbers; other text never equals a number.
compare_values(Order, A, B) :-
    number(A), number(B), !,
    compare_numbers(Order, A, B).
compare_values(Order, A, B) :-
    is_text(A), is_text(B), !,
    clip_text(A, CA), clip_text(B, CB),
    string_codes(CA, KA), string_codes(CB, KB),
    compare_padded(Order, KA, KB).
compare_values(Order, A, B) :-
    number(A), is_text(B), text_number(B, NB), !,
    compare_numbers(Order, A, NB).
compare_values(Order, A, B) :-
    is_text(A), number(B), text_number(A, NA), !,
    compare_numbers(Order, NA, B).
compare_values(Order, A, B) :-
    compare(Order, A, B).

compare_numbers(Order, A, B) :-
    ( A =:= B -> Order = (=) ; A < B -> Order = (<) ; Order = (>) ).

% The shorter string compares as if padded with spaces
compare_padded(=, [], []) :- !.
compare_padded(O, [], B) :- !, compare_padded(O, [0' ], B).
compare_padded(O, A, []) :- !, compare_padded(O, A, [0' ]).
compare_padded(O, [X|Xs], [Y|Ys]) :-
    ( X =:= Y -> compare_padded(O, Xs, Ys) ; X < Y -> O = (<) ; O = (>) ).

compare_keys(=, [], [], _).
compare_keys(Order, [A|As], [B|Bs], Attrs) :-
    key_form(A, Attrs, KA), key_form(B, Attrs, KB),
    compare_values(O, KA, KB),
    ( O == (=) -> compare_keys(Order, As, Bs, Attrs) ; Order = O ).

key_form(V, Attrs, K) :-
    ( memberchk(nocase, Attrs), is_text(V) -> text_string(V, S), string_upper(S, K) ; K = V ).

same_values(As, Bs, Attrs) :-
    compare_keys(=, As, Bs, Attrs).
