%% test_llvm.pl -- Test suite for LLVM IR simulator
%%
%% Uses SWI-Prolog plunit framework.
%% Run: swipl -g "run_tests,halt" -t "halt(1)" test_llvm.pl

:- use_module(llvm_parser).
:- use_module(llvm_state).
:- use_module(llvm_eval).
:- use_module(llvm_simulator).
:- use_module(llvm).

% ============================================================
% Parser tests
% ============================================================

:- begin_tests(llvm_parser).

test(parse_simple_function) :-
    Source = "define double @add(double %a, double %b) {\nentry:\n  %r = fadd double %a, %b\n  ret double %r\n}\n",
    parse_llvm(Source, module([], [], Defines)),
    Defines = [define(double, add, [param(double, a), param(double, b)], _Blocks)].

test(parse_declare) :-
    Source = "declare double @sqrt(double)\n",
    parse_llvm(Source, module([], Declares, [])),
    Declares = [declare(double, sqrt, [double])].

test(parse_void_return) :-
    Source = "define void @nop() {\nentry:\n  ret void\n}\n",
    parse_llvm(Source, module([], [], [define(void, nop, [], _)])).

test(parse_integer_ops) :-
    Source = "define i32 @add_i32(i32 %a, i32 %b) {\nentry:\n  %r = add i32 %a, %b\n  ret i32 %r\n}\n",
    parse_llvm(Source, module([], [], [define(i(32), add_i32, _, _)])).

test(parse_conditional_branch) :-
    Source = "define i32 @test(i32 %x) {\nentry:\n  %cmp = icmp slt i32 %x, 0\n  br i1 %cmp, label %neg, label %pos\nneg:\n  %r1 = sub i32 0, %x\n  br label %done\npos:\n  br label %done\ndone:\n  %r = phi i32 [ %r1, %neg ], [ %x, %pos ]\n  ret i32 %r\n}\n",
    parse_llvm(Source, module([], [], [define(i(32), test, _, Blocks)])),
    length(Blocks, 4).

test(parse_select) :-
    Source = "define double @max(double %a, double %b) {\nentry:\n  %cmp = fcmp ogt double %a, %b\n  %r = select i1 %cmp, double %a, double %b\n  ret double %r\n}\n",
    parse_llvm(Source, module(_, _, [define(double, max, _, _)])).

test(parse_call) :-
    Source = "declare double @sqrt(double)\ndefine double @dist(double %x) {\nentry:\n  %x2 = fmul double %x, %x\n  %r = call double @sqrt(double %x2)\n  ret double %r\n}\n",
    parse_llvm(Source, module(_, [declare(double, sqrt, _)], [define(double, dist, _, _)])).

test(parse_comment_skip) :-
    Source = "; This is a comment\ndefine i32 @one() {\nentry:\n  ret i32 1\n}\n",
    parse_llvm(Source, module([], [], [define(i(32), one, [], _)])).

test(parse_file) :-
    parse_llvm_file('samples/add.ll', module(_, Declares, Defines)),
    length(Defines, 7),
    length(Declares, 1).

:- end_tests(llvm_parser).

% ============================================================
% Eval tests
% ============================================================

:- begin_tests(llvm_eval).

test(binary_fadd) :-
    eval_binary_op(fadd, double, 3.0, 4.0, 7.0).

test(binary_fmul) :-
    eval_binary_op(fmul, double, 3.0, 4.0, 12.0).

test(binary_fdiv) :-
    eval_binary_op(fdiv, double, 10.0, 4.0, 2.5).

test(binary_add_i32) :-
    eval_binary_op(add, i(32), 100, 200, 300).

test(binary_sub_i32) :-
    eval_binary_op(sub, i(32), 200, 50, 150).

test(binary_mul_overflow) :-
    % 2^31 * 2 should wrap in i32
    eval_binary_op(mul, i(32), 2147483648, 2, R),
    R =:= 0.

test(icmp_slt_true) :-
    eval_icmp(slt, -1, 0, 1).

test(icmp_slt_false) :-
    eval_icmp(slt, 5, 3, 0).

test(icmp_eq) :-
    eval_icmp(eq, 42, 42, 1).

test(fcmp_ogt_true) :-
    eval_fcmp(ogt, 5.0, 3.0, 1).

test(fcmp_ogt_false) :-
    eval_fcmp(ogt, 3.0, 5.0, 0).

test(cast_sitofp) :-
    eval_cast(sitofp, i(32), double, 42, R),
    R =:= 42.0.

test(cast_fptosi) :-
    eval_cast(fptosi, double, i(32), 42.7, R),
    R =:= 42.

test(sign_extend_negative) :-
    % 0xFF in i8 is -1
    llvm_eval:sign_extend(8, 255, -1).

test(sign_extend_positive) :-
    llvm_eval:sign_extend(8, 127, 127).

test(mask_int_i8) :-
    llvm_eval:mask_int(8, 256, 0).

:- end_tests(llvm_eval).

% ============================================================
% State tests
% ============================================================

:- begin_tests(llvm_state).

test(empty_state) :-
    empty_state(S),
    get_error(S, none),
    get_prev_block(S, none),
    get_output(S, []).

test(register_set_get) :-
    empty_state(S0),
    set_register(x, typed_value(i(32), 42), S0, S1),
    get_register(x, S1, typed_value(i(32), 42)).

test(memory_alloc_store_load) :-
    empty_state(S0),
    llvm_state:alloc_memory(Addr, S0, S1),
    llvm_state:store_memory(Addr, typed_value(double, 3.14), S1, S2),
    llvm_state:load_memory(Addr, S2, typed_value(double, 3.14)).

test(clear_registers) :-
    empty_state(S0),
    set_register(x, typed_value(i(32), 1), S0, S1),
    clear_registers(S1, S2),
    \+ get_register(x, S2, _).

:- end_tests(llvm_state).

% ============================================================
% Simulator tests — hand-crafted IR
% ============================================================

:- begin_tests(llvm_simulator).

test(exec_add_double) :-
    Source = "define double @add(double %a, double %b) {\nentry:\n  %r = fadd double %a, %b\n  ret double %r\n}\n",
    exec_function(Source, add, [3.0, 4.0], Result),
    Result =:= 7.0.

test(exec_multiply) :-
    Source = "define double @mul(double %a, double %b) {\nentry:\n  %r = fmul double %a, %b\n  ret double %r\n}\n",
    exec_function(Source, mul, [3.0, 5.0], Result),
    Result =:= 15.0.

test(exec_quadratic) :-
    % f(x) = 3x^2 + 2x + 1, f(2) = 12 + 4 + 1 = 17
    Source = "define double @quad(double %x) {\nentry:\n  %x2 = fmul double %x, %x\n  %t1 = fmul double 3.0, %x2\n  %t2 = fmul double 2.0, %x\n  %s = fadd double %t1, %t2\n  %r = fadd double %s, 1.0\n  ret double %r\n}\n",
    exec_function(Source, quad, [2.0], Result),
    Result =:= 17.0.

test(exec_add_i32) :-
    Source = "define i32 @add(i32 %a, i32 %b) {\nentry:\n  %r = add i32 %a, %b\n  ret i32 %r\n}\n",
    exec_function(Source, add, [100, 200], Result),
    Result =:= 300.

test(exec_select) :-
    Source = "define double @max(double %a, double %b) {\nentry:\n  %cmp = fcmp ogt double %a, %b\n  %r = select i1 %cmp, double %a, double %b\n  ret double %r\n}\n",
    exec_function(Source, max, [3.0, 7.0], R1),
    R1 =:= 7.0,
    exec_function(Source, max, [9.0, 2.0], R2),
    R2 =:= 9.0.

test(exec_conditional_branch) :-
    % abs(x): if x < 0 then -x else x
    Source = "define i32 @abs(i32 %x) {\nentry:\n  %cmp = icmp slt i32 %x, 0\n  br i1 %cmp, label %neg, label %pos\nneg:\n  %r1 = sub i32 0, %x\n  br label %done\npos:\n  br label %done\ndone:\n  %r = phi i32 [ %r1, %neg ], [ %x, %pos ]\n  ret i32 %r\n}\n",
    exec_function(Source, abs, [5], R1),
    R1 =:= 5,
    exec_function(Source, abs, [-3], R2),
    R2 =:= 3.

test(exec_void_return) :-
    Source = "define void @nop() {\nentry:\n  ret void\n}\n",
    exec_function(Source, nop, [], Result),
    Result == void.

:- end_tests(llvm_simulator).

% ============================================================
% Integration tests — using samples/add.ll file
% ============================================================

:- begin_tests(llvm_integration).

test(file_add) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, add, [10.0, 20.0], Result, _),
    Result =:= 30.0.

test(file_multiply) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, multiply, [6.0, 7.0], Result, _),
    Result =:= 42.0.

test(file_quadratic) :-
    % f(x) = 3x^2 + 2x + 1, f(3) = 27 + 6 + 1 = 34
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, quadratic, [3.0], Result, _),
    Result =:= 34.0.

test(file_abs_positive) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, abs_i32, [42], Result, _),
    Result =:= 42.

test(file_abs_negative) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, abs_i32, [-7], Result, _),
    Result =:= 7.

test(file_max_double) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, max_double, [3.14, 2.71], Result, _),
    Result =:= 3.14.

test(file_distance) :-
    % sqrt(3^2 + 4^2) = 5.0
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, distance, [3.0, 4.0], Result, _),
    abs(Result - 5.0) < 1e-10.

test(file_factorial) :-
    init_session_from_file('samples/add.ll', Session),
    call_function(Session, factorial, [5], Result, _),
    Result =:= 120.

test(session_multiple_calls) :-
    init_session_from_file('samples/add.ll', Session0),
    call_function(Session0, add, [1.0, 2.0], R1, Session1),
    R1 =:= 3.0,
    call_function(Session1, multiply, [R1, 10.0], R2, _),
    R2 =:= 30.0.

:- end_tests(llvm_integration).

% ============================================================
% Phase 2: VecMat MathUtil tests — real clang-generated LLVM IR
% ============================================================

:- begin_tests(llvm_vecmat).

test(parse_mathutil_ll) :-
    parse_llvm_file('samples/mathutil.ll', module(Globals, Declares, Defines)),
    length(Globals, 1),
    length(Declares, 5),
    length(Defines, 6).

test(is_approx_equal_true) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'IsApproxEqual_double', [1.0, 1.000001, 1e-5], R, _),
    R =:= 1.

test(is_approx_equal_false) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'IsApproxEqual_double', [1.0, 2.0, 1e-5], R, _),
    R =:= 0.

test(gauss_at_zero) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'Gauss_double', [0.0, 1.0], R, _),
    % Gauss(0, 1) = 1 / sqrt(2*PI) ≈ 0.3989
    abs(R - 0.3989422804014327) < 1e-10.

test(gauss_symmetry) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'Gauss_double', [1.0, 1.0], R1, _),
    call_function(S, 'Gauss_double', [-1.0, 1.0], R2, _),
    abs(R1 - R2) < 1e-10.

test(gauss2d_at_origin) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'Gauss2D_double', [0.0, 0.0, 1.0, 1.0], R, _),
    % Gauss2D at origin with sx=sy=1
    abs(R - 0.3989422804014327) < 1e-10.

test(gauss2d_isotropic) :-
    % Gauss2D(x,0,s,s) should equal Gauss(x,s) * normalizing factor
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'Gauss2D_double', [1.0, 0.0, 2.0, 2.0], R, _),
    R > 0.0.

test(dgauss2d_dx_at_origin) :-
    % Derivative at x=0 should be 0 (peak of gaussian)
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'dGauss2D_dx_double', [0.0, 0.0, 1.0, 1.0], R, _),
    abs(R) < 1e-10.

test(dgauss2d_dy_at_origin) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'dGauss2D_dy_double', [0.0, 0.0, 1.0, 1.0], R, _),
    abs(R) < 1e-10.

test(dgauss2d_dx_negative_slope) :-
    % Derivative at x>0 should be negative (gaussian decreasing)
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'dGauss2D_dx_double', [1.0, 0.0, 1.0, 1.0], R, _),
    R < 0.0.

test(angle_from_sincos_zero) :-
    init_session_from_file('samples/mathutil.ll', S),
    call_function(S, 'AngleFromSinCos_double', [0.0, 1.0], R, _),
    abs(R) < 1e-10.

test(angle_from_sincos_pi_half) :-
    init_session_from_file('samples/mathutil.ll', S),
    Pi_2 is pi / 2,
    call_function(S, 'AngleFromSinCos_double', [1.0, 0.0], R, _),
    abs(R - Pi_2) < 1e-10.

test(angle_from_sincos_pi) :-
    init_session_from_file('samples/mathutil.ll', S),
    Pi is pi,
    call_function(S, 'AngleFromSinCos_double', [0.0, -1.0], R, _),
    abs(R - Pi) < 1e-10.

test(angle_from_sincos_three_pi_half) :-
    init_session_from_file('samples/mathutil.ll', S),
    ThreePi2 is 3 * pi / 2,
    call_function(S, 'AngleFromSinCos_double', [-1.0, 0.0], R, _),
    abs(R - ThreePi2) < 1e-10.

:- end_tests(llvm_vecmat).


:- run_tests.
