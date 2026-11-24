%============================================================
% clarion_dates.pl - Clarion standard dates and times
%
% Clarion dates count days since 1800-12-28; valid dates are
% 1801-01-01 (4) to 9999-12-31 (2994626). Times are hundredths
% of a second since midnight, plus 1. In both, 0 means blank.
%
% from_column/4 and to_column/4 convert between database date/time
% columns and Clarion field values. They map only values that convert back
% exactly and fail for the rest, so nothing is silently altered.
%============================================================

:- module(clarion_dates, [
    date_days/2,      % +date(Y,M,D), -Days
    days_date/2,      % +Days, -date(Y,M,D)
    time_centis/2,    % +time(H,M,S), -Time
    centis_time/2,    % +Time, -time(H,M,S)
    from_column/4,    % +ColumnKind, +FieldClass, +DbValue, -Value
    to_column/4       % +ColumnKind, +FieldClass, +Value, -DbValue
]).

:- use_module(library(dcg/basics)).

first_day(4).
last_day(2994626).

date_days(date(Y, M, D), Days) :-
    civil_days(Y, M, D, Days),
    first_day(First), last_day(Last),
    Days >= First, Days =< Last,
    days_civil(Days, Y, M, D).  % rejects dates such as 02-30

days_date(Days, date(Y, M, D)) :-
    integer(Days),
    first_day(First), last_day(Last),
    Days >= First, Days =< Last,
    days_civil(Days, Y, M, D).

% Proleptic Gregorian, counting years from March. 657738 is the day number of
% 1800-12-28 counted from 0000-03-01.
civil_days(Y, M, D, Days) :-
    integer(Y), integer(M), integer(D),
    M >= 1, M =< 12,
    ( M =< 2 -> Y1 is Y - 1, MP is M + 9 ; Y1 = Y, MP is M - 3 ),
    Days is 365*Y1 + Y1//4 - Y1//100 + Y1//400 + (153*MP + 2)//5 + D - 1 - 657738.

days_civil(Days, Y, M, D) :-
    Z is Days + 657738,
    Era is Z // 146097,
    Doe is Z - Era*146097,
    Yoe is (Doe - Doe//1460 + Doe//36524 - Doe//146096) // 365,
    Doy is Doe - (365*Yoe + Yoe//4 - Yoe//100),
    MP is (5*Doy + 2) // 153,
    D is Doy - (153*MP + 2)//5 + 1,
    ( MP < 10 -> M is MP + 3 ; M is MP - 9 ),
    Y0 is Yoe + Era*400,
    ( M =< 2 -> Y is Y0 + 1 ; Y = Y0 ).

time_centis(time(H, M, S), Time) :-
    valid_time(H, M, S),
    Time is (H*3600 + M*60 + S)*100 + 1.

% Whole seconds only: the ODBC time type carries no fraction.
centis_time(Time, time(H, M, S)) :-
    integer(Time), Time >= 1, Time =< 8640000,
    (Time - 1) mod 100 =:= 0,
    Secs is (Time - 1) // 100,
    H is Secs // 3600, M is Secs mod 3600 // 60, S is Secs mod 60.

valid_time(H, M, S) :-
    integer(H), integer(M), integer(S),
    H >= 0, H =< 23, M >= 0, M =< 59, S >= 0, S =< 59.

%------------------------------------------------------------
% Column conversion
%   ColumnKind: date, time, timestamp
%   FieldClass: number, text
%------------------------------------------------------------

from_column(_, number, '$null$', 0) :- !.
from_column(_, text, '$null$', '') :- !.
from_column(date, number, Date, Days) :- date_days(Date, Days).
from_column(time, number, Time, Centis) :- time_centis(Time, Centis).
from_column(timestamp, number, timestamp(Y, M, D, 0, 0, 0, 0), Days) :-
    date_days(date(Y, M, D), Days).
from_column(date, text, Date, Text) :-
    Date = date(Y, M, D), date_days(Date, _),
    format(atom(Text), '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]).
from_column(time, text, time(H, M, S), Text) :-
    valid_time(H, M, S),
    format(atom(Text), '~|~`0t~d~2+:~|~`0t~d~2+:~|~`0t~d~2+', [H, M, S]).
from_column(timestamp, text, timestamp(Y, M, D, H, Mi, S, Nanos), Text) :-
    from_column(date, text, date(Y, M, D), DateText),
    from_column(time, text, time(H, Mi, S), TimeText),
    fraction_text(Nanos, Fraction),
    atomic_list_concat([DateText, ' ', TimeText, Fraction], Text).

to_column(_, number, 0, '$null$') :- !.
to_column(date, number, Days, Date) :- days_date(Days, Date).
to_column(time, number, Centis, Time) :- centis_time(Centis, Time).
to_column(timestamp, number, Days, timestamp(Y, M, D, 0, 0, 0, 0)) :-
    days_date(Days, date(Y, M, D)).
to_column(Kind, text, Text, Value) :-
    text_codes(Text, Codes),
    phrase(column_text(Kind, Value), Codes), !.

text_codes(Text, Codes) :-
    atomic(Text),
    format(atom(Atom), '~w', [Text]),
    normalize_space(codes(Codes), Atom).

column_text(_, '$null$') --> [].
column_text(date, Date) --> iso_date(Date).
column_text(time, Time) --> iso_time(Time).
column_text(timestamp, timestamp(Y, M, D, H, Mi, S, Nanos)) -->
    iso_date(date(Y, M, D)), " ", iso_time(time(H, Mi, S)), iso_fraction(Nanos).
column_text(timestamp, timestamp(Y, M, D, 0, 0, 0, 0)) --> iso_date(date(Y, M, D)).

iso_date(date(Y, M, D)) -->
    fixed(4, Y), "-", fixed(2, M), "-", fixed(2, D),
    { date_days(date(Y, M, D), _) }.
iso_time(time(H, M, S)) -->
    fixed(2, H), ":", fixed(2, M), ":", fixed(2, S),
    { valid_time(H, M, S) }.

iso_fraction(Nanos) -->
    ".", digits(Ds),
    { Ds \== [], length(Ds, N), N =< 9,
      number_codes(V, Ds), Nanos is V * 10**(9 - N) }.
iso_fraction(0) --> [].

fixed(N, Value) -->
    { length(Ds, N) }, all_digits(Ds), { number_codes(Value, Ds) }.

all_digits([]) --> [].
all_digits([D|Ds]) --> [D], { code_type(D, digit), D < 128 }, all_digits(Ds).

fraction_text(0, '') :- !.
fraction_text(Nanos, Text) :-
    format(codes(Codes), '~|~`0t~d~9+', [Nanos]),
    strip_zeros(Codes, Stripped),
    atom_codes(Digits, Stripped),
    atom_concat('.', Digits, Text).

strip_zeros(Codes, Stripped) :-
    ( append(Front, [0'0], Codes) -> strip_zeros(Front, Stripped) ; Stripped = Codes ).
