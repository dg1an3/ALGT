%% llvm_parser.pl -- DCG parser for LLVM IR text format (.ll files)
%%
%% Parses LLVM IR into:
%%   module(Globals, Declares, Defines)
%%
%% Where:
%%   Defines  = [define(RetType, Name, Params, Blocks), ...]
%%   Declares = [declare(RetType, Name, ParamTypes), ...]
%%   Globals  = [global(Name, Type, Value), ...]
%%   Blocks   = [block(Label, Instructions, Terminator), ...]

:- module(llvm_parser, [
    parse_llvm/2,
    parse_llvm_file/2
]).

%% parse_llvm(+Source, -Module)
%  Parse an LLVM IR source string into a module AST.
parse_llvm(Source, Module) :-
    string_codes(Source, Codes),
    phrase(llvm_module(Module), Codes, []), !.

%% parse_llvm_file(+FilePath, -Module)
%  Parse an LLVM IR file into a module AST.
parse_llvm_file(FilePath, Module) :-
    read_file_to_codes(FilePath, Codes, []),
    phrase(llvm_module(Module), Codes, []), !.

% ============================================================
% Module-level grammar
% ============================================================

llvm_module(module(Globals, Declares, Defines)) -->
    ws,
    module_items(Globals, Declares, Defines).

module_items(Globals, Declares, Defines) -->
    ws,
    ( module_item(Item) ->
        { classify_item(Item, Globals, Declares, Defines,
                        Globals1, Declares1, Defines1) },
        module_items(Globals1, Declares1, Defines1)
    ; \+ [_] ->
        { Globals = [], Declares = [], Defines = [] }
    ).

classify_item(define(R,N,P,B), Gs, Ds, [define(R,N,P,B)|Defs], Gs, Ds, Defs).
classify_item(declare(R,N,PT), Gs, [declare(R,N,PT)|Ds], Defs, Gs, Ds, Defs).
classify_item(global(N,T,V), [global(N,T,V)|Gs], Ds, Defs, Gs, Ds, Defs).

module_item(Item) -->
    ( comment_line -> { fail }
    ; source_filename_line -> { fail }
    ; target_line -> { fail }
    ; attributes_line -> { fail }
    ; metadata_line -> { fail }
    ; define_func(Item)
    ; declare_func(Item)
    ; global_def(Item)
    ).

% Skip lines we don't care about
comment_line --> ws, ";", rest_of_line.
source_filename_line --> ws, "source_filename", rest_of_line.
target_line --> ws, "target", rest_of_line.
attributes_line --> ws, "attributes", rest_of_line.
metadata_line --> ws, "!", rest_of_line.

rest_of_line --> ( "\n" ; "\r\n" ; \+ [_] ), !.
rest_of_line --> [_], rest_of_line.

% ============================================================
% Function definitions
% ============================================================

define_func(define(RetType, Name, Params, Blocks)) -->
    ws, "define", ws1,
    optional_linkage,
    llvm_type(RetType), ws,
    global_name(Name), ws,
    "(", param_list(Params), ")", ws,
    optional_func_attrs,
    "{", ws,
    basic_blocks(Blocks),
    ws, "}", ws.

declare_func(declare(RetType, Name, ParamTypes)) -->
    ws, "declare", ws1,
    optional_linkage,
    llvm_type(RetType), ws,
    global_name(Name), ws,
    "(", param_type_list(ParamTypes), ")", ws,
    optional_func_attrs, ws.

optional_linkage --> linkage_keyword, ws1.
optional_linkage --> [].

linkage_keyword --> "private".
linkage_keyword --> "internal".
linkage_keyword --> "external".
linkage_keyword --> "linkonce".
linkage_keyword --> "weak".
linkage_keyword --> "common".
linkage_keyword --> "dso_local".

optional_func_attrs --> func_attr, ws, optional_func_attrs.
optional_func_attrs --> [].

func_attr --> "#", digits(_).
func_attr --> "nounwind".
func_attr --> "readnone".
func_attr --> "readonly".
func_attr --> "writeonly".
func_attr --> "willreturn".
func_attr --> "mustprogress".
func_attr --> "nosync".
func_attr --> "nofree".
func_attr --> "norecurse".
func_attr --> "uwtable".
func_attr --> "noinline".
func_attr --> "optnone".
func_attr --> "alwaysinline".
func_attr --> "ssp".
func_attr --> "sspstrong".

% ============================================================
% Parameters
% ============================================================

param_list([Param|Rest]) -->
    param(Param),
    ( ws, ",", ws, param_list(Rest)
    ; { Rest = [] }
    ).
param_list([]) --> ws.

param(param(Type, Name)) -->
    llvm_type(Type), ws,
    optional_param_attrs,
    local_name(Name).

param(param(Type)) -->
    llvm_type(Type), ws,
    optional_param_attrs.

optional_param_attrs --> param_attr, ws, optional_param_attrs.
optional_param_attrs --> [].

param_attr --> "noundef".
param_attr --> "signext".
param_attr --> "zeroext".
param_attr --> "inreg".
param_attr --> "byval".
param_attr --> "sret".
param_attr --> "noalias".
param_attr --> "nocapture".
param_attr --> "nonnull".
param_attr --> "align", ws1, digits(_).

param_type_list([Type|Rest]) -->
    llvm_type(Type), ws,
    optional_param_attrs,
    ( ws, ",", ws, param_type_list(Rest)
    ; { Rest = [] }
    ).
param_type_list([]) --> ws.

% ============================================================
% Basic blocks
% ============================================================

basic_blocks([Block|Rest]) -->
    basic_block(Block),
    ( basic_blocks(Rest)
    ; { Rest = [] }
    ).

basic_block(block(Label, Instructions, Terminator)) -->
    block_label(Label), ws,
    instructions(Instructions, Terminator).

block_label(Label) -->
    ws, identifier_str(Label), ":", ws.

instructions([], Terminator) -->
    terminator(Terminator), ws.
instructions([Instr|Rest], Terminator) -->
    instruction(Instr), ws,
    instructions(Rest, Terminator).

% ============================================================
% Terminators
% ============================================================

terminator(ret(Type, Value)) -->
    ws, "ret", ws1,
    llvm_type(Type), ws,
    { Type \= void },
    operand(Value),
    optional_metadata.

terminator(ret(void, void)) -->
    ws, "ret", ws1, "void",
    optional_metadata.

terminator(br(label(Label))) -->
    ws, "br", ws1,
    "label", ws,
    local_name(Label),
    optional_metadata.

terminator(br(Cond, label(TrueLabel), label(FalseLabel))) -->
    ws, "br", ws1,
    "i1", ws, operand(Cond), ",", ws,
    "label", ws, local_name(TrueLabel), ",", ws,
    "label", ws, local_name(FalseLabel),
    optional_metadata.

terminator(switch(Type, Value, Default, Cases)) -->
    ws, "switch", ws1,
    llvm_type(Type), ws, operand(Value), ",", ws,
    "label", ws, local_name(Default), ws,
    "[", ws, switch_cases(Type, Cases), ws, "]",
    optional_metadata.

terminator(unreachable) -->
    ws, "unreachable",
    optional_metadata.

switch_cases(Type, [case(Val, Label)|Rest]) -->
    llvm_type(Type), ws, operand(Val), ",", ws,
    "label", ws, local_name(Label), ws,
    switch_cases(Type, Rest).
switch_cases(_, []) --> [].

% ============================================================
% Instructions
% ============================================================

instruction(Instr) -->
    ws,
    ( named_instruction(Instr)
    ; void_instruction(Instr)
    ),
    optional_metadata.

named_instruction(Instr) -->
    local_name(Result), ws, "=", ws,
    instruction_rhs(Result, Instr).

% Instructions that produce a named result
instruction_rhs(Result, instr(Op, Result, Type, Ops)) -->
    binary_op(Op), ws,
    optional_flags,
    llvm_type(Type), ws,
    operand(Op1), ",", ws, operand(Op2),
    { Ops = [Op1, Op2] }.

instruction_rhs(Result, icmp(Result, Cond, Type, Op1, Op2)) -->
    "icmp", ws1,
    cmp_cond(Cond), ws1,
    llvm_type(Type), ws,
    operand(Op1), ",", ws, operand(Op2).

instruction_rhs(Result, fcmp(Result, Cond, Type, Op1, Op2)) -->
    "fcmp", ws1,
    optional_fast_math_flags,
    cmp_cond(Cond), ws1,
    llvm_type(Type), ws,
    operand(Op1), ",", ws, operand(Op2).

instruction_rhs(Result, alloca(Result, Type)) -->
    "alloca", ws1,
    llvm_type(Type),
    optional_alloca_attrs.

instruction_rhs(Result, alloca(Result, Type, NumElements)) -->
    "alloca", ws1,
    llvm_type(Type), ",", ws,
    llvm_type(_), ws, operand(NumElements),
    optional_alloca_attrs.

instruction_rhs(Result, load(Result, Type, PtrType, Ptr)) -->
    "load", ws1,
    llvm_type(Type), ",", ws,
    llvm_type(PtrType), ws, operand(Ptr),
    optional_load_attrs.

instruction_rhs(Result, store_result(Result, ValType, Val, PtrType, Ptr)) -->
    % store doesn't normally have a result, but handle weird cases
    "store", ws1,
    llvm_type(ValType), ws, operand(Val), ",", ws,
    llvm_type(PtrType), ws, operand(Ptr),
    optional_store_attrs.

instruction_rhs(Result, getelementptr(Result, InBounds, BaseType, PtrType, Ptr, Indices)) -->
    "getelementptr", ws1,
    gep_inbounds(InBounds),
    llvm_type(BaseType), ",", ws,
    llvm_type(PtrType), ws, operand(Ptr),
    gep_indices(Indices).

instruction_rhs(Result, call(Result, RetType, Callee, Args)) -->
    optional_tail,
    "call", ws1,
    optional_fast_math_flags,
    llvm_type(RetType), ws,
    call_target(Callee), ws,
    "(", call_arg_list(Args), ")",
    optional_call_attrs.

instruction_rhs(Result, phi(Result, Type, Entries)) -->
    "phi", ws1,
    llvm_type(Type), ws,
    phi_entries(Entries).

instruction_rhs(Result, select(Result, CondType, Cond, Type, TrueVal, FalseVal)) -->
    "select", ws1,
    llvm_type(CondType), ws, operand(Cond), ",", ws,
    llvm_type(Type), ws, operand(TrueVal), ",", ws,
    llvm_type(Type), ws, operand(FalseVal).

instruction_rhs(Result, cast(CastOp, Result, FromType, Val, ToType)) -->
    cast_op(CastOp), ws1,
    llvm_type(FromType), ws, operand(Val), ws,
    "to", ws1,
    llvm_type(ToType).

% Void instructions (no result register)
void_instruction(store(ValType, Val, PtrType, Ptr)) -->
    "store", ws1,
    llvm_type(ValType), ws, operand(Val), ",", ws,
    llvm_type(PtrType), ws, operand(Ptr),
    optional_store_attrs.

void_instruction(call_void(Callee, Args)) -->
    optional_tail,
    "call", ws1, "void", ws,
    call_target(Callee), ws,
    "(", call_arg_list(Args), ")",
    optional_call_attrs.

% ============================================================
% Operators
% ============================================================

binary_op(add) --> "add".
binary_op(sub) --> "sub".
binary_op(mul) --> "mul".
binary_op(udiv) --> "udiv".
binary_op(sdiv) --> "sdiv".
binary_op(urem) --> "urem".
binary_op(srem) --> "srem".
binary_op(shl) --> "shl".
binary_op(lshr) --> "lshr".
binary_op(ashr) --> "ashr".
binary_op(and) --> "and".
binary_op(or) --> "or".
binary_op(xor) --> "xor".
binary_op(fadd) --> "fadd".
binary_op(fsub) --> "fsub".
binary_op(fmul) --> "fmul".
binary_op(fdiv) --> "fdiv".
binary_op(frem) --> "frem".

cast_op(sext) --> "sext".
cast_op(zext) --> "zext".
cast_op(trunc) --> "trunc".
cast_op(sitofp) --> "sitofp".
cast_op(fptosi) --> "fptosi".
cast_op(uitofp) --> "uitofp".
cast_op(fptoui) --> "fptoui".
cast_op(fpext) --> "fpext".
cast_op(fptrunc) --> "fptrunc".
cast_op(bitcast) --> "bitcast".
cast_op(ptrtoint) --> "ptrtoint".
cast_op(inttoptr) --> "inttoptr".

cmp_cond(eq) --> "eq".
cmp_cond(ne) --> "ne".
cmp_cond(slt) --> "slt".
cmp_cond(sgt) --> "sgt".
cmp_cond(sle) --> "sle".
cmp_cond(sge) --> "sge".
cmp_cond(ult) --> "ult".
cmp_cond(ugt) --> "ugt".
cmp_cond(ule) --> "ule".
cmp_cond(uge) --> "uge".
cmp_cond(oeq) --> "oeq".
cmp_cond(one) --> "one".
cmp_cond(ogt) --> "ogt".
cmp_cond(olt) --> "olt".
cmp_cond(oge) --> "oge".
cmp_cond(ole) --> "ole".
cmp_cond(ord) --> "ord".
cmp_cond(uno) --> "uno".
cmp_cond(ueq) --> "ueq".
cmp_cond(une) --> "une".
% For true/false constants in fcmp
cmp_cond(true) --> "true".
cmp_cond(false) --> "false".

% ============================================================
% Operands and values
% ============================================================

operand(local(Name)) --> local_name(Name).
operand(global(Name)) --> global_name(Name).
operand(int(Value)) --> integer_literal(Value).
operand(float(Value)) --> float_literal(Value).
operand(true) --> "true".
operand(false) --> "false".
operand(null) --> "null".
operand(undef) --> "undef".
operand(zeroinitializer) --> "zeroinitializer".

% ============================================================
% Names and identifiers
% ============================================================

local_name(Name) -->
    "%", identifier_or_number(Name).

global_name(Name) -->
    "@", identifier_or_number(Name).

identifier_or_number(Name) -->
    identifier_str(Name).
identifier_or_number(Name) -->
    digits(Codes),
    { atom_codes(Name, Codes) }.

identifier_str(Name) -->
    [C], { id_start(C) },
    id_rest(Rest),
    { atom_codes(Name, [C|Rest]) }.

identifier_str(Name) -->
    "\"", quoted_str_codes(Codes), "\"",
    { atom_codes(Name, Codes) }.

id_start(C) :- code_type(C, alpha) ; C =:= 0'_ ; C =:= 0'..
id_rest([C|Rest]) --> [C], { id_cont(C) }, id_rest(Rest).
id_rest([]) --> [].
id_cont(C) :- code_type(C, alnum) ; C =:= 0'_ ; C =:= 0'. ; C =:= 0'$.

quoted_str_codes([]) --> [].
quoted_str_codes([0'\\, C|Rest]) --> "\\", [C], quoted_str_codes(Rest).
quoted_str_codes([C|Rest]) --> [C], { C \= 0'" }, quoted_str_codes(Rest).

% ============================================================
% Types
% ============================================================

llvm_type(Type) --> base_type(T), type_suffix(T, Type).

base_type(void) --> "void".
base_type(i(1)) --> "i1".
base_type(i(8)) --> "i8".
base_type(i(16)) --> "i16".
base_type(i(32)) --> "i32".
base_type(i(64)) --> "i64".
base_type(float) --> "float".
base_type(double) --> "double".
base_type(ptr) --> "ptr".
base_type(array(N, T)) --> "[", ws, integer_literal(N), ws, "x", ws, llvm_type(T), ws, "]".
base_type(struct(Fields)) --> "{", ws, type_list(Fields), ws, "}".
base_type(opaque_struct(Name)) --> "%", identifier_str(Name).

type_suffix(T, pointer(T)) --> ws, "*".
type_suffix(T, T) --> [].

type_list([T|Rest]) -->
    llvm_type(T),
    ( ws, ",", ws, type_list(Rest)
    ; { Rest = [] }
    ).
type_list([]) --> [].

% ============================================================
% Phi entries
% ============================================================

phi_entries([phi_entry(Value, Label)|Rest]) -->
    "[", ws,
    operand(Value), ",", ws,
    local_name(Label), ws,
    "]",
    ( ws, ",", ws, phi_entries(Rest)
    ; { Rest = [] }
    ).

% ============================================================
% Call-related
% ============================================================

call_target(Name) --> global_name(Name).
call_target(Name) --> local_name(Name).

call_arg_list([Arg|Rest]) -->
    call_arg(Arg),
    ( ws, ",", ws, call_arg_list(Rest)
    ; { Rest = [] }
    ).
call_arg_list([]) --> ws.

call_arg(arg(Type, Value)) -->
    llvm_type(Type), ws,
    optional_param_attrs,
    operand(Value).

optional_tail --> "tail", ws1.
optional_tail --> "musttail", ws1.
optional_tail --> "notail", ws1.
optional_tail --> [].

optional_call_attrs --> [].

% ============================================================
% GEP (getelementptr) indices
% ============================================================

gep_inbounds(inbounds) --> "inbounds", ws1.
gep_inbounds(false) --> [].

gep_indices([index(Type, Value)|Rest]) -->
    ",", ws,
    llvm_type(Type), ws, operand(Value),
    gep_indices(Rest).
gep_indices([]) --> [].

% ============================================================
% Optional attributes and flags (skip)
% ============================================================

optional_flags --> flag_keyword, ws, optional_flags.
optional_flags --> [].

flag_keyword --> "nsw".
flag_keyword --> "nuw".
flag_keyword --> "exact".

optional_fast_math_flags --> fast_math_flag, ws1, optional_fast_math_flags.
optional_fast_math_flags --> [].

fast_math_flag --> "fast".
fast_math_flag --> "nnan".
fast_math_flag --> "ninf".
fast_math_flag --> "nsz".
fast_math_flag --> "arcp".
fast_math_flag --> "contract".
fast_math_flag --> "afn".
fast_math_flag --> "reassoc".

optional_alloca_attrs --> ",", ws, "align", ws1, integer_literal(_).
optional_alloca_attrs --> [].

optional_load_attrs --> ",", ws, "align", ws1, integer_literal(_).
optional_load_attrs --> [].

optional_store_attrs --> ",", ws, "align", ws1, integer_literal(_).
optional_store_attrs --> [].

optional_metadata --> ",", ws, "!dbg", ws, "!", integer_literal(_), optional_metadata.
optional_metadata --> ",", ws, "!tbaa", ws, "!", integer_literal(_), optional_metadata.
optional_metadata --> [].

% ============================================================
% Global definitions
% ============================================================

global_def(global(Name, Type, Value)) -->
    global_name(Name), ws, "=", ws,
    optional_linkage,
    optional_global_attrs,
    global_kind, ws1,
    llvm_type(Type), ws,
    global_init(Value),
    optional_global_suffix.

global_kind --> "global".
global_kind --> "constant".

optional_global_attrs --> "unnamed_addr", ws1, optional_global_attrs.
optional_global_attrs --> "local_unnamed_addr", ws1, optional_global_attrs.
optional_global_attrs --> [].

global_init(Value) --> operand(Value).
global_init(undef) --> "undef".

optional_global_suffix --> ",", ws, "align", ws1, integer_literal(_).
optional_global_suffix --> [].

% ============================================================
% Literals
% ============================================================

integer_literal(N) -->
    optional_sign(Sign),
    digits(Codes),
    { Codes \= [],
      number_codes(Abs, Codes),
      N is Sign * Abs }.

float_literal(F) -->
    optional_sign(Sign),
    digits(IntPart),
    ".",
    digits(FracPart),
    optional_exponent(Exp),
    { IntPart \= [],
      append(IntPart, [0'.|FracPart], NumCodes1),
      append(NumCodes1, Exp, NumCodes),
      number_codes(Abs, NumCodes),
      F is Sign * Abs }.

float_literal(F) -->
    "0x", hex_digits(HexCodes),
    { hex_to_float(HexCodes, F) }.

optional_sign(-1) --> "-".
optional_sign(1) --> "+".
optional_sign(1) --> [].

optional_exponent(Codes) -->
    [E], { E =:= 0'e ; E =:= 0'E },
    optional_sign_codes(SignCodes),
    digits(DigitCodes),
    { append([E|SignCodes], DigitCodes, Codes) }.
optional_exponent([]) --> [].

optional_sign_codes([0'+]) --> "+".
optional_sign_codes([0'-]) --> "-".
optional_sign_codes([]) --> [].

digits([D|Rest]) --> [D], { code_type(D, digit) }, digits(Rest).
digits([]) --> [].

hex_digits([D|Rest]) --> [D], { is_hex_digit(D) }, hex_digits(Rest).
hex_digits([]) --> [].

is_hex_digit(D) :-
    ( code_type(D, digit)
    ; D >= 0'a, D =< 0'f
    ; D >= 0'A, D =< 0'F
    ).

%% hex_to_float(+HexCodes, -Float)
%  Convert LLVM hex float representation (IEEE 754 double) to Prolog float.
hex_to_float(HexCodes, Float) :-
    atom_codes(HexAtom, HexCodes),
    atom_string(HexAtom, HexStr),
    atom_to_term(HexStr, HexInt, _),
    % For now, handle common cases
    ( HexInt =:= 0 -> Float = 0.0
    ; % General IEEE 754 conversion would go here
      Float = 0.0  % placeholder
    ).

% ============================================================
% Whitespace handling
% ============================================================

ws --> [C], { ws_char(C) }, ws.
ws --> ";", rest_of_line, ws.
ws --> [].

ws1 --> [C], { ws_char(C) }, ws.

ws_char(0' ).
ws_char(0'\t).
ws_char(0'\n).
ws_char(0'\r).
