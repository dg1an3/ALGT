%% llvm_eval.pl -- Value resolution and type operations for LLVM IR simulator
%%
%% Resolves SSA operands to concrete values and implements type conversions.

:- module(llvm_eval, [
    resolve_value/4,
    eval_binary_op/5,
    eval_icmp/4,
    eval_fcmp/4,
    eval_cast/5,
    type_default/2,
    sign_extend/3,
    mask_int/3
]).

:- use_module(llvm_state).

% ============================================================
% Value resolution: operand → concrete value
% ============================================================

%% resolve_value(+Operand, +Type, +State, -Value)
resolve_value(local(Name), _Type, State, Value) :-
    get_register(Name, State, typed_value(_, Value)), !.

resolve_value(global(Name), _Type, State, Addr) :-
    get_global(Name, State, Addr), !.

resolve_value(int(N), _Type, _State, N) :- !.
resolve_value(float(F), _Type, _State, F) :- !.
resolve_value(true, _Type, _State, 1) :- !.
resolve_value(false, _Type, _State, 0) :- !.
resolve_value(null, _Type, _State, 0) :- !.
resolve_value(undef, Type, _State, V) :- !, type_default(Type, V).
resolve_value(zeroinitializer, _Type, _State, 0) :- !.

% ============================================================
% Binary operations
% ============================================================

%% eval_binary_op(+Op, +Type, +V1, +V2, -Result)

% Integer arithmetic
eval_binary_op(add, i(Bits), V1, V2, R) :-
    R0 is V1 + V2, mask_int(Bits, R0, R).
eval_binary_op(sub, i(Bits), V1, V2, R) :-
    R0 is V1 - V2, mask_int(Bits, R0, R).
eval_binary_op(mul, i(Bits), V1, V2, R) :-
    R0 is V1 * V2, mask_int(Bits, R0, R).
eval_binary_op(udiv, _, V1, V2, R) :-
    R is V1 // V2.
eval_binary_op(sdiv, i(Bits), V1, V2, R) :-
    sign_extend(Bits, V1, SV1),
    sign_extend(Bits, V2, SV2),
    R0 is SV1 // SV2,
    mask_int(Bits, R0, R).
eval_binary_op(urem, _, V1, V2, R) :-
    R is V1 mod V2.
eval_binary_op(srem, i(Bits), V1, V2, R) :-
    sign_extend(Bits, V1, SV1),
    sign_extend(Bits, V2, SV2),
    R0 is SV1 rem SV2,
    mask_int(Bits, R0, R).

% Bitwise
eval_binary_op(shl, i(Bits), V1, V2, R) :-
    R0 is V1 << V2, mask_int(Bits, R0, R).
eval_binary_op(lshr, _, V1, V2, R) :-
    R is V1 >> V2.
eval_binary_op(ashr, i(Bits), V1, V2, R) :-
    sign_extend(Bits, V1, SV1),
    R0 is SV1 >> V2,
    mask_int(Bits, R0, R).
eval_binary_op(and, _, V1, V2, R) :-
    R is V1 /\ V2.
eval_binary_op(or, _, V1, V2, R) :-
    R is V1 \/ V2.
eval_binary_op(xor, _, V1, V2, R) :-
    R is V1 xor V2.

% Floating-point arithmetic
eval_binary_op(fadd, _, V1, V2, R) :- R is V1 + V2.
eval_binary_op(fsub, _, V1, V2, R) :- R is V1 - V2.
eval_binary_op(fmul, _, V1, V2, R) :- R is V1 * V2.
eval_binary_op(fdiv, _, V1, V2, R) :- R is V1 / V2.
eval_binary_op(frem, _, V1, V2, R) :-
    Div is truncate(V1 / V2),
    R is V1 - Div * V2.

% ============================================================
% Integer comparison
% ============================================================

%% eval_icmp(+Cond, +V1, +V2, -Result)  Result is 1 or 0
eval_icmp(eq,  V1, V2, R) :- ( V1 =:= V2 -> R = 1 ; R = 0 ).
eval_icmp(ne,  V1, V2, R) :- ( V1 =\= V2 -> R = 1 ; R = 0 ).
eval_icmp(ugt, V1, V2, R) :- ( V1 > V2   -> R = 1 ; R = 0 ).
eval_icmp(uge, V1, V2, R) :- ( V1 >= V2  -> R = 1 ; R = 0 ).
eval_icmp(ult, V1, V2, R) :- ( V1 < V2   -> R = 1 ; R = 0 ).
eval_icmp(ule, V1, V2, R) :- ( V1 =< V2  -> R = 1 ; R = 0 ).

% Signed comparisons need sign extension context
eval_icmp(sgt, V1, V2, R) :- ( V1 > V2   -> R = 1 ; R = 0 ).
eval_icmp(sge, V1, V2, R) :- ( V1 >= V2  -> R = 1 ; R = 0 ).
eval_icmp(slt, V1, V2, R) :- ( V1 < V2   -> R = 1 ; R = 0 ).
eval_icmp(sle, V1, V2, R) :- ( V1 =< V2  -> R = 1 ; R = 0 ).

% ============================================================
% Floating-point comparison
% ============================================================

%% eval_fcmp(+Cond, +V1, +V2, -Result)  Result is 1 or 0
%  'o' prefix = ordered (both non-NaN)
%  'u' prefix = unordered (either may be NaN)

eval_fcmp(oeq, V1, V2, R) :- ( V1 =:= V2 -> R = 1 ; R = 0 ).
eval_fcmp(one, V1, V2, R) :- ( V1 =\= V2 -> R = 1 ; R = 0 ).
eval_fcmp(ogt, V1, V2, R) :- ( V1 > V2   -> R = 1 ; R = 0 ).
eval_fcmp(oge, V1, V2, R) :- ( V1 >= V2  -> R = 1 ; R = 0 ).
eval_fcmp(olt, V1, V2, R) :- ( V1 < V2   -> R = 1 ; R = 0 ).
eval_fcmp(ole, V1, V2, R) :- ( V1 =< V2  -> R = 1 ; R = 0 ).
eval_fcmp(ord, V1, V2, R) :-
    ( (float(V1), float(V2)) -> R = 1 ; R = 0 ).
eval_fcmp(uno, V1, V2, R) :-
    ( (float(V1), float(V2)) -> R = 0 ; R = 1 ).
eval_fcmp(ueq, V1, V2, R) :- ( V1 =:= V2 -> R = 1 ; R = 0 ).
eval_fcmp(une, V1, V2, R) :- ( V1 =\= V2 -> R = 1 ; R = 0 ).
eval_fcmp(ugt, V1, V2, R) :- ( V1 > V2   -> R = 1 ; R = 0 ).
eval_fcmp(uge, V1, V2, R) :- ( V1 >= V2  -> R = 1 ; R = 0 ).
eval_fcmp(ult, V1, V2, R) :- ( V1 < V2   -> R = 1 ; R = 0 ).
eval_fcmp(ule, V1, V2, R) :- ( V1 =< V2  -> R = 1 ; R = 0 ).
eval_fcmp(true, _, _, 1).
eval_fcmp(false, _, _, 0).

% ============================================================
% Cast / conversion operations
% ============================================================

%% eval_cast(+CastOp, +FromType, +ToType, +Value, -Result)

eval_cast(sext, i(FromBits), i(ToBits), V, R) :-
    sign_extend(FromBits, V, SV),
    mask_int(ToBits, SV, R).

eval_cast(zext, _, i(ToBits), V, R) :-
    mask_int(ToBits, V, R).

eval_cast(trunc, _, i(ToBits), V, R) :-
    mask_int(ToBits, V, R).

eval_cast(sitofp, i(Bits), _, V, R) :-
    sign_extend(Bits, V, SV),
    R is float(SV).

eval_cast(uitofp, _, _, V, R) :-
    R is float(V).

eval_cast(fptosi, _, i(Bits), V, R) :-
    R0 is truncate(V),
    mask_int(Bits, R0, R).

eval_cast(fptoui, _, _, V, R) :-
    R is truncate(V).

eval_cast(fpext, _, _, V, V).   % Prolog uses double internally
eval_cast(fptrunc, _, _, V, V). % Prolog uses double internally

eval_cast(bitcast, _, _, V, V).
eval_cast(ptrtoint, _, _, V, V).
eval_cast(inttoptr, _, _, V, V).

% ============================================================
% Type defaults (for undef)
% ============================================================

type_default(i(_), 0).
type_default(float, 0.0).
type_default(double, 0.0).
type_default(ptr, 0).
type_default(pointer(_), 0).
type_default(void, void).

% ============================================================
% Integer helpers
% ============================================================

%% mask_int(+Bits, +Value, -Masked)
%  Mask to N bits (unsigned representation)
mask_int(Bits, V, R) :-
    Mask is (1 << Bits) - 1,
    R is V /\ Mask.

%% sign_extend(+Bits, +Value, -SignExtended)
%  Sign-extend an N-bit value to a Prolog integer
sign_extend(Bits, V, SV) :-
    mask_int(Bits, V, Masked),
    SignBit is 1 << (Bits - 1),
    ( Masked /\ SignBit =:= SignBit ->
        SV is Masked - (1 << Bits)
    ;
        SV = Masked
    ).
