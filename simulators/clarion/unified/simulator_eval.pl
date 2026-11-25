%============================================================
% simulator_eval.pl - Expression Evaluation
%
% Handles evaluation of Clarion expressions and binary operators.
% Note: Function calls and method calls are handled in simulator_core
% to avoid circular dependencies.
%============================================================

:- module(simulator_eval, [
    eval_expr/3,
    eval_binop/4,
    is_truthy/1,
    to_string/2,
    text_slice/4,
    replace_slice/5,
    is_clarion_constant/1
]).

:- use_module(simulator_state).
:- use_module(clarion_types).

:- discontiguous eval_expr/3.

%------------------------------------------------------------
% Expression Evaluation
%------------------------------------------------------------

% Literals
eval_expr(string(S), _, S).
eval_expr(number(N), _, N).
% An argument already evaluated by exec_call (see pre_eval_builtin_args/4)
eval_expr(evaluated(V), _, V).
eval_expr(neg(N), _, Result) :- Result is -N.
eval_expr(true, _, 1).
eval_expr(false, _, 0).

% Handle Clarion constants (EVENT:xxx, BUTTON:xxx, ICON:xxx, PROP:xxx)
% Clarion runtime constants (EVENT:Accepted etc.) — look up as variable first,
% fall back to atom if not defined (legacy behavior)
eval_expr(var(Name), State, Value) :-
    is_clarion_constant(Name), !,
    ( get_var(Name, State, Value) -> true ; Value = Name ).

% Variable lookup
eval_expr(var(Name), State, Value) :-
    get_var(Name, State, Value).

% Binary operations
eval_expr(binop(Op, Left, Right), State, Result) :-
    eval_expr(Left, State, LVal),
    eval_expr(Right, State, RVal),
    eval_binop(Op, LVal, RVal, Result).

% Logical NOT
eval_expr(not(Expr), State, Result) :-
    eval_expr(Expr, State, Val),
    ( is_truthy(Val) -> Result = 0 ; Result = 1 ).

% Control reference (for GUI, returns equate number from state)
eval_expr(control_ref(Name), State, Value) :-
    ( get_var(equate(Name), State, Value) -> true ; Value = 0 ).

% Array element access
eval_expr(array_access(ArrayName, IndexExpr), State, Value) :-
    eval_expr(IndexExpr, State, Index),
    get_var(ArrayName, State, ArrayVal),
    ( ArrayVal = array(Elements)
    -> Idx is truncate(Index) - 1,  % Clarion arrays are 1-based
       get_array_element(Idx, Elements, Value)
    ; is_text(ArrayVal)                % S[i]: one character
    -> text_slice(ArrayVal, Index, Index, Value)
    ;  Value = 0
    ).

% S[a:b]
eval_expr(slice(Name, FromExpr, ToExpr), State, Value) :-
    eval_expr(FromExpr, State, From),
    eval_expr(ToExpr, State, To),
    get_var(Name, State, Text),
    text_slice(Text, From, To, Value).

% Picture expressions (for FORMAT)
eval_expr(picture(Pic), _, picture(Pic)).

%------------------------------------------------------------
% Clarion Constants
%------------------------------------------------------------

is_clarion_constant(Name) :-
    atom(Name),
    atom_string(Name, Str),
    ( sub_string(Str, 0, _, _, "EVENT:")
    ; sub_string(Str, 0, _, _, "BUTTON:")
    ; sub_string(Str, 0, _, _, "ICON:")
    ; sub_string(Str, 0, _, _, "PROP:")
    ).

%------------------------------------------------------------
% Binary Operators
%------------------------------------------------------------

% Arithmetic. Numeric text is converted; + on other text concatenates (legacy).
eval_binop('+', L, R, Result) :-
    ( arithmetic(L, LN), arithmetic(R, RN)
    -> Result is LN + RN
    ;  to_string(L, LS), to_string(R, RS),
       string_concat(LS, RS, Result)
    ).
eval_binop('-', L, R, Result) :- to_number(L, LN), to_number(R, RN), Result is LN - RN.
eval_binop('*', L, R, Result) :- to_number(L, LN), to_number(R, RN), Result is LN * RN.
eval_binop('/', L0, R0, Result) :-
    to_number(L0, L), to_number(R0, R),
    R =\= 0,
    ( (integer(L), integer(R))
    -> Result is L // R    % Clarion integer division for LONG operands
    ;  Result is L / R
    ).
eval_binop('%', L0, R0, Result) :-
    to_number(L0, L), to_number(R0, R),
    R =\= 0, Result is truncate(L) mod truncate(R).

% String concatenation
eval_binop('&', L, R, Result) :-
    to_string(L, LS), to_string(R, RS),
    string_concat(LS, RS, Result).

% Comparison
eval_binop('=', L, R, Result) :- compare_values(O, L, R), ( O == (=) -> Result = 1 ; Result = 0 ).
eval_binop('<>', L, R, Result) :- compare_values(O, L, R), ( O == (=) -> Result = 0 ; Result = 1 ).
eval_binop('<', L, R, Result) :- compare_values(O, L, R), ( O == (<) -> Result = 1 ; Result = 0 ).
eval_binop('>', L, R, Result) :- compare_values(O, L, R), ( O == (>) -> Result = 1 ; Result = 0 ).
eval_binop('<=', L, R, Result) :- compare_values(O, L, R), ( O == (>) -> Result = 0 ; Result = 1 ).
eval_binop('>=', L, R, Result) :- compare_values(O, L, R), ( O == (<) -> Result = 0 ; Result = 1 ).

% Logical (both upper and lower case atoms)
eval_binop('AND', L, R, Result) :-
    ( (is_truthy(L), is_truthy(R)) -> Result = 1 ; Result = 0 ).
eval_binop(and, L, R, Result) :-
    ( (is_truthy(L), is_truthy(R)) -> Result = 1 ; Result = 0 ).
eval_binop('OR', L, R, Result) :-
    ( (is_truthy(L) ; is_truthy(R)) -> Result = 1 ; Result = 0 ).
eval_binop(or, L, R, Result) :-
    ( (is_truthy(L) ; is_truthy(R)) -> Result = 1 ; Result = 0 ).

%------------------------------------------------------------
% Helper Predicates
%------------------------------------------------------------

is_truthy(N) :- number(N), !, N =\= 0.
is_truthy(T) :- is_text(T), clip_text(T, C), C \== "".

arithmetic(V, V) :- number(V), !.
arithmetic(V, N) :- is_text(V), text_number(V, N).

to_string(S, S) :- string(S), !.
to_string(A, S) :- atom(A), !, atom_string(A, S).
to_string(N, S) :- number(N), clarion_types:text_string(N, S).

%------------------------------------------------------------
% String slices (1-based, inclusive; positions past the end give nothing)
%------------------------------------------------------------

text_slice(Text, From0, To0, Slice) :-
    to_string(Text, S),
    string_length(S, Length),
    From is max(1, truncate(From0)),
    To is min(Length, truncate(To0)),
    ( From =< To
    -> Start is From - 1, Count is To - From + 1,
       sub_string(S, Start, Count, _, Slice)
    ;  Slice = ""
    ).

% Positions From..To become New, padded or cut to fit. Text shorter than To
% (a CSTRING) is extended.
replace_slice(Text, From0, To0, New, Result) :-
    to_string(Text, S0),
    From is max(1, truncate(From0)), To is truncate(To0),
    ( From > To
    -> Result = S0
    ;  Width is To - From + 1, Before is From - 1,
       coerce('STRING', size(Width), New, Piece),
       string_length(S0, Length),
       ( Length < Before -> coerce('STRING', size(Before), S0, Head) ; sub_string(S0, 0, Before, _, Head) ),
       ( Length > To -> sub_string(S0, To, _, 0, Tail) ; Tail = "" ),
       atomic_list_concat([Head, Piece, Tail], Joined), atom_string(Joined, Result)
    ).

%------------------------------------------------------------
% Array Access Helper
%------------------------------------------------------------

get_array_element(0, [H|_], H) :- !.
get_array_element(Idx, [_|T], Value) :-
    Idx > 0, !,
    Idx1 is Idx - 1,
    get_array_element(Idx1, T, Value).
get_array_element(_, [], 0).  % Out of bounds returns 0

%------------------------------------------------------------
% Note: call, method_call, member_access, self_access expressions
% are handled by eval_full_expr in simulator_core.pl
%------------------------------------------------------------
