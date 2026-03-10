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
    is_clarion_constant/1
]).

:- use_module(simulator_state).

:- discontiguous eval_expr/3.

%------------------------------------------------------------
% Expression Evaluation
%------------------------------------------------------------

% Literals
eval_expr(string(S), _, S).
eval_expr(number(N), _, N).
eval_expr(neg(N), _, Result) :- Result is -N.
eval_expr(true, _, 1).
eval_expr(false, _, 0).

% Handle Clarion constants (EVENT:xxx, BUTTON:xxx, ICON:xxx, PROP:xxx)
eval_expr(var(Name), _, Name) :-
    is_clarion_constant(Name), !.

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
    -> Idx is Index - 1,  % Clarion arrays are 1-based
       get_array_element(Idx, Elements, Value)
    ;  Value = 0
    ).

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

% Arithmetic (with string concatenation fallback for +)
eval_binop('+', L, R, Result) :-
    ( (number(L), number(R))
    -> Result is L + R
    ;  % String concatenation
       to_string(L, LS), to_string(R, RS),
       string_concat(LS, RS, Result)
    ).
eval_binop('-', L, R, Result) :- Result is L - R.
eval_binop('*', L, R, Result) :- Result is L * R.
eval_binop('/', L, R, Result) :-
    R \= 0,
    ( (integer(L), integer(R))
    -> Result is L // R    % Clarion integer division for LONG operands
    ;  Result is L / R
    ).
eval_binop('%', L, R, Result) :- R \= 0, Result is L mod R.

% String concatenation
eval_binop('&', L, R, Result) :-
    to_string(L, LS), to_string(R, RS),
    string_concat(LS, RS, Result).

% Comparison
eval_binop('=', L, R, Result) :- ( L = R -> Result = 1 ; Result = 0 ).
eval_binop('<>', L, R, Result) :- ( L \= R -> Result = 1 ; Result = 0 ).
eval_binop('<', L, R, Result) :- ( L < R -> Result = 1 ; Result = 0 ).
eval_binop('>', L, R, Result) :- ( L > R -> Result = 1 ; Result = 0 ).
eval_binop('<=', L, R, Result) :- ( L =< R -> Result = 1 ; Result = 0 ).
eval_binop('>=', L, R, Result) :- ( L >= R -> Result = 1 ; Result = 0 ).

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

is_truthy(1) :- !.
is_truthy(N) :- number(N), N \= 0.
is_truthy(S) :- string(S), S \= "".
is_truthy(A) :- atom(A), A \= ''.

to_string(S, S) :- string(S), !.
to_string(A, S) :- atom(A), !, atom_string(A, S).
to_string(N, S) :- number(N), number_string(N, S).

%------------------------------------------------------------
% Array Access Helper
%------------------------------------------------------------

get_array_element(0, [H|_], H) :- !.
get_array_element(Idx, [_|T], Value) :-
    Idx > 0,
    Idx1 is Idx - 1,
    get_array_element(Idx1, T, Value).
get_array_element(_, [], 0).  % Out of bounds returns 0

%------------------------------------------------------------
% Note: call, method_call, member_access, self_access expressions
% are handled by eval_full_expr in simulator_core.pl
%------------------------------------------------------------
