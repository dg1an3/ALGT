%============================================================
% clarion_arrays.pl - Clarion arrays
%
% array(Size, Depth, Tree): a binary tree indexed by the bits of the
% 0-based position, most significant first. Reading and writing cost
% Depth steps, and a write shares the rest of the tree with the old
% array. A new array is one value shared at every level, so its size
% costs nothing until it is written.
%============================================================

:- module(clarion_arrays, [
    new_array/3,         % +Size, +Value, -Array
    array_size/2,        % +Array, -Size
    array_element/3,     % +Array, +Index (1-based), -Value; fails out of range
    set_array_element/4  % +Array, +Index (1-based), +Value, -Array; fails out of range
]).

new_array(Size, Value, array(Size, Depth, Tree)) :-
    Depth is max(0, msb(max(1, 2 * Size - 1))),
    uniform(Depth, Value, Tree).

uniform(0, Value, Value) :- !.
uniform(Depth, Value, n(Half, Half)) :-
    Depth1 is Depth - 1,
    uniform(Depth1, Value, Half).

array_size(array(Size, _, _), Size).

array_element(array(Size, Depth, Tree), Index, Value) :-
    position(Index, Size, Pos),
    element(Depth, Pos, Tree, Value).

element(0, _, Value0, Value) :- !, Value = Value0.
element(Depth, Pos, n(Left, Right), Value) :-
    Depth1 is Depth - 1,
    ( Pos /\ (1 << Depth1) =:= 0 -> element(Depth1, Pos, Left, Value) ; element(Depth1, Pos, Right, Value) ).

set_array_element(array(Size, Depth, Tree0), Index, Value, array(Size, Depth, Tree)) :-
    position(Index, Size, Pos),
    set_element(Depth, Pos, Value, Tree0, Tree).

set_element(0, _, Value, _, Value) :- !.
set_element(Depth, Pos, Value, n(L0, R0), n(L, R)) :-
    Depth1 is Depth - 1,
    ( Pos /\ (1 << Depth1) =:= 0
    -> set_element(Depth1, Pos, Value, L0, L), R = R0
    ;  set_element(Depth1, Pos, Value, R0, R), L = L0
    ).

position(Index, Size, Pos) :-
    Pos is truncate(Index) - 1,
    Pos >= 0, Pos < Size.
