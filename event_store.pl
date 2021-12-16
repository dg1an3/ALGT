
do_add(X,Y,[added(X,Y,Result)|_]) :-
    number(X),
    number(Y),
    Result is X + Y.

