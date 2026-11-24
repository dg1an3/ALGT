%% compat.pl — Compatibility predicates for Erlog
%%
%% Provides SWI-Prolog built-ins that Erlog lacks, implemented in
%% pure Prolog or via ecall/2 to Erlang.

%% string_to_list(+String, -Codes) — alias for atom_codes
string_to_list(S, Cs) :- atom_codes(S, Cs).

%% number_codes(+Number, -Codes) / number_codes(-Number, +Codes)
%% Convert between numbers and character code lists.
%% Uses ecall to bridge to Erlang's list_to_integer/integer_to_list.
number_codes(N, Cs) :-
    nonvar(N), !,
    integer_to_codes(N, Cs).
number_codes(N, Cs) :-
    nonvar(Cs),
    codes_to_integer(Cs, N).

integer_to_codes(N, Cs) :-
    ( N < 0 ->
        N1 is 0 - N,
        pos_int_codes(N1, Ds),
        Cs = [45 | Ds]   % 45 = '-'
    ;
        pos_int_codes(N, Cs)
    ).

pos_int_codes(0, [48]) :- !.   % 48 = '0'
pos_int_codes(N, Cs) :-
    N > 0,
    pos_int_codes_acc(N, [], Cs).

pos_int_codes_acc(0, Acc, Acc) :- !.
pos_int_codes_acc(N, Acc, Cs) :-
    N > 0,
    D is N mod 10,
    C is D + 48,
    N1 is N // 10,
    pos_int_codes_acc(N1, [C|Acc], Cs).

codes_to_integer(Cs, N) :-
    ( Cs = [45|Rest] ->   % negative
        codes_to_pos_int(Rest, 0, Abs),
        N is 0 - Abs
    ;
        codes_to_pos_int(Cs, 0, N)
    ).

codes_to_pos_int([], Acc, Acc).
codes_to_pos_int([C|Cs], Acc, N) :-
    C >= 48, C =< 57,
    D is C - 48,
    Acc1 is Acc * 10 + D,
    codes_to_pos_int(Cs, Acc1, N).

%% char_code(+Char, -Code) / char_code(-Char, +Code)
char_code(Char, Code) :-
    nonvar(Char), !,
    atom_codes(Char, [Code]).
char_code(Char, Code) :-
    nonvar(Code),
    atom_codes(Char, [Code]).

%% upcase_atom(+Atom, -Upper)
%% Convert an atom to uppercase.
upcase_atom(Atom, Upper) :-
    atom_codes(Atom, Codes),
    upcase_codes_compat(Codes, UCodes),
    atom_codes(Upper, UCodes).

upcase_codes_compat([], []).
upcase_codes_compat([C|Cs], [U|Us]) :-
    ( C >= 97, C =< 122 ->   % a-z
        U is C - 32
    ;
        U = C
    ),
    upcase_codes_compat(Cs, Us).

%% atomic_list_concat(+List, -Atom)
%% Concatenate a list of atoms into one atom.
atomic_list_concat([], '').
atomic_list_concat([A], A) :- !.
atomic_list_concat([A|As], Result) :-
    atom_codes(A, Cs1),
    atomic_list_concat(As, Rest),
    atom_codes(Rest, Cs2),
    append(Cs1, Cs2, AllCs),
    atom_codes(Result, AllCs).

%% atomic_list_concat(+List, +Sep, -Atom)
%% Concatenate with separator.
atomic_list_concat([], _, '').
atomic_list_concat([A], _, A) :- !.
atomic_list_concat([A|As], Sep, Result) :-
    atom_codes(A, Cs1),
    atom_codes(Sep, SCs),
    atomic_list_concat_rest(As, SCs, Cs2),
    append(Cs1, Cs2, AllCs),
    atom_codes(Result, AllCs).

atomic_list_concat_rest([], _, []).
atomic_list_concat_rest([A|As], Sep, Result) :-
    atom_codes(A, Cs),
    append(Sep, Cs, WithSep),
    atomic_list_concat_rest(As, Sep, Rest),
    append(WithSep, Rest, Result).

%% select(?Elem, +List, -Rest)
%% Select an element from a list, returning the rest.
select(X, [X|Xs], Xs).
select(X, [Y|Ys], [Y|Zs]) :- select(X, Ys, Zs).

