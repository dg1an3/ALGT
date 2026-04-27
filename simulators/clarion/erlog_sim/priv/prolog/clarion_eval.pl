%============================================================
% clarion_eval.pl - Expression Evaluation for Erlog Simulator
%
% Evaluates Clarion expressions. Variables can be unbound —
% unification propagates constraints naturally.
%
% Erlog-compatible: no modules, no dicts, ISO-standard.
%============================================================

%------------------------------------------------------------
% Expression Evaluation
%------------------------------------------------------------

% Literals
eval_expr(string(S), _, S).
eval_expr(number(N), _, N).
eval_expr(neg(E), State, Result) :-
    eval_expr(E, State, V),
    Result is -V.
eval_expr(true, _, 1).
eval_expr(false, _, 0).

% Clarion constants (EVENT:xxx, BUTTON:xxx, etc.)
eval_expr(var(Name), _, Name) :-
    is_clarion_constant(Name), !.

% Variable lookup — if unbound in state, Value stays unbound (open variable!)
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

% Control reference (for GUI equates)
eval_expr(control_ref(Name), State, Value) :-
    ( get_var(equate(Name), State, Value) -> true ; Value = 0 ).

% Array element access
eval_expr(array_access(ArrayName, IndexExpr), State, Value) :-
    eval_expr(IndexExpr, State, Index),
    get_var(ArrayName, State, ArrayVal),
    ( ArrayVal = array(Elements) ->
        Idx is Index - 1,
        get_array_element(Idx, Elements, Value)
    ;   Value = 0
    ).

% Picture expressions (for FORMAT)
eval_expr(picture(Pic), _, picture(Pic)).

%------------------------------------------------------------
% Full Expression Evaluation (handles calls and member access)
%------------------------------------------------------------

eval_full_expr(binop(Op, Left, Right), State, Result) :- !,
    eval_full_expr(Left, State, LVal),
    eval_full_expr(Right, State, RVal),
    eval_binop(Op, LVal, RVal, Result).
eval_full_expr(call(Name, Args), StateIn, Result) :- !,
    exec_call(Name, Args, StateIn, _, Result).
eval_full_expr(method_call(ObjName, MethodName, Args), StateIn, Result) :- !,
    exec_method_call(ObjName, MethodName, Args, StateIn, _, Result).
eval_full_expr(self_access(PropName), State, Value) :- !,
    state_self(State, self_context(VarName, _, _)),
    get_var(VarName, State, Instance),
    get_instance_prop(PropName, Instance, Value).
eval_full_expr(member_access(ObjName, PropName), State, Value) :- !,
    get_var(ObjName, State, ObjVal),
    ( ObjVal = instance(_, _) ->
        get_instance_prop(PropName, ObjVal, Value)
    ; ObjVal = group_val(_, Fields, Values) ->
        get_group_field(PropName, Fields, Values, Value)
    ; ObjVal = group_val(Fields, Values) ->
        get_group_field(PropName, Fields, Values, Value)
    ;   Value = 0
    ).
eval_full_expr(not(Expr), State, Result) :- !,
    eval_full_expr(Expr, State, Val),
    ( is_truthy(Val) -> Result = 0 ; Result = 1 ).
eval_full_expr(neg(E), State, Result) :- !,
    eval_full_expr(E, State, V),
    Result is -V.
eval_full_expr(Expr, State, Value) :-
    eval_expr(Expr, State, Value).

%------------------------------------------------------------
% Clarion Constants
%------------------------------------------------------------

is_clarion_constant(Name) :-
    atom(Name),
    atom_codes(Name, Codes),
    ( starts_with_codes(Codes, "EVENT:")
    ; starts_with_codes(Codes, "BUTTON:")
    ; starts_with_codes(Codes, "ICON:")
    ; starts_with_codes(Codes, "PROP:")
    ).

starts_with_codes(Codes, Prefix) :-
    atom_codes(Prefix, PrefixCodes),
    append(PrefixCodes, _, Codes).

%------------------------------------------------------------
% Binary Operators
%------------------------------------------------------------

% Arithmetic (with string concatenation fallback for +)
eval_binop('+', L, R, Result) :-
    ( number(L), number(R) ->
        Result is L + R
    ;   to_string_val(L, LS),
        to_string_val(R, RS),
        atom_codes(LS, LC),
        atom_codes(RS, RC),
        append(LC, RC, Codes),
        atom_codes(Result, Codes)
    ).
eval_binop('-', L, R, Result) :- Result is L - R.
eval_binop('*', L, R, Result) :- Result is L * R.
eval_binop('/', L, R, Result) :-
    R =\= 0,
    ( integer(L), integer(R) ->
        Result is L // R
    ;   Result is L / R
    ).
eval_binop('%', L, R, Result) :- R =\= 0, Result is L mod R.

% String concatenation
eval_binop('&', L, R, Result) :-
    to_string_val(L, LS),
    to_string_val(R, RS),
    atom_codes(LS, LC),
    atom_codes(RS, RC),
    append(LC, RC, Codes),
    atom_codes(Result, Codes).

% Comparison
eval_binop('=', L, R, Result) :- ( L = R -> Result = 1 ; Result = 0 ).
eval_binop('<>', L, R, Result) :- ( L \= R -> Result = 1 ; Result = 0 ).
eval_binop('<', L, R, Result) :- ( L < R -> Result = 1 ; Result = 0 ).
eval_binop('>', L, R, Result) :- ( L > R -> Result = 1 ; Result = 0 ).
eval_binop('<=', L, R, Result) :- ( L =< R -> Result = 1 ; Result = 0 ).
eval_binop('>=', L, R, Result) :- ( L >= R -> Result = 1 ; Result = 0 ).

% Logical
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
is_truthy(N) :- number(N), N =\= 0.
is_truthy(S) :- atom(S), S \= ''.

to_string_val(S, S) :- atom(S), !.
to_string_val(N, S) :- integer(N), !, number_codes(N, Codes), atom_codes(S, Codes).
to_string_val(N, S) :- float(N), !, number_codes(N, Codes), atom_codes(S, Codes).
to_string_val(X, X).

%------------------------------------------------------------
% Array Access Helper
%------------------------------------------------------------

get_array_element(0, [H|_], H) :- !.
get_array_element(Idx, [_|T], Value) :-
    Idx > 0, Idx1 is Idx - 1,
    get_array_element(Idx1, T, Value).
get_array_element(_, [], 0).
