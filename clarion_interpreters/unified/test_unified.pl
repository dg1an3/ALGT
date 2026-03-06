%============================================================
% test_unified.pl - Tests for the Unified Clarion Interpreter
%
% Validates that the unified system (simple parser + AST bridge
% + modular execution engine) produces correct results.
%
% Run: swipl -g "main,halt" -t "halt(1)" test_unified.pl
%============================================================

:- use_module(clarion).
:- use_module(clarion_parser).
:- use_module(ast_bridge).
:- use_module(interpreter_state).

:- dynamic test_count/1, pass_count/1, fail_count/1.
test_count(0). pass_count(0). fail_count(0).

check(Label, Got, Expected) :-
    retract(test_count(N)), N1 is N + 1, assert(test_count(N1)),
    ( Got = Expected ->
        retract(pass_count(P)), P1 is P + 1, assert(pass_count(P1)),
        format("  ~w [PASS]~n", [Label])
    ;   retract(fail_count(F)), F1 is F + 1, assert(fail_count(F1)),
        format("  ~w [FAIL] got ~w, expected ~w~n", [Label, Got, Expected])
    ).

%------------------------------------------------------------
% Parser Tests (via bridge)
%------------------------------------------------------------

test_parse_simple :-
    format("~nParser + Bridge tests:~n"),
    Src = "  MEMBER()\n  MAP\n    MathAdd(LONG a, LONG b),LONG,C,NAME('MathAdd'),EXPORT\n  END\nMathAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(map(MapDecls), _, code(_), Procs),
    length(MapDecls, NMap),
    length(Procs, NProc),
    check('MEMBER parse + bridge', ok, ok),
    check('Map entries count', NMap, 1),
    check('Procedure count', NProc, 1).

test_parse_mathlib :-
    read_file_to_string('../../clarion_projects/python-dll/MathLib.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    check('MathLib.clw parse + bridge', N, 2).

test_parse_sensorlib :-
    read_file_to_string('../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, _, Procs),
    length(Procs, NP),
    include([X]>>(X = file(_, _, _)), GlobalDecls, Files),
    length(Files, NF),
    check('SensorLib.clw parse + bridge procs', NP, 6),
    check('SensorLib.clw file declarations', NF, 1).

test_parse_diagstore :-
    read_file_to_string('../../clarion_projects/diagnosis-store/DiagnosisStore.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    ( N > 0 -> R = true ; R = false ),
    check('DiagnosisStore.clw parse + bridge', R, true).

test_parse_formdemo :-
    read_file_to_string('../../clarion_projects/form-demo/FormDemo.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, code(Main), _),
    length(Main, NM),
    include([X]>>(X = window(_, _, _, _)), GlobalDecls, Wins),
    length(Wins, NW),
    ( NM > 0 -> RM = true ; RM = false ),
    check('FormDemo.clw parse + bridge main stmts', RM, true),
    check('FormDemo.clw window declarations', NW, 1).

test_parse_odbcstore :-
    read_file_to_string('../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    ( N > 0 -> RN = true ; RN = false ),
    check('OdbcStore.clw parse + bridge', RN, true).

test_parse_controlflow :-
    read_file_to_string('../../clarion_projects/clarion_examples/control_flow.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, ModProcs),
    length(ModProcs, N),
    check('control_flow.clw PROGRAM parse + bridge', N, 4).

%------------------------------------------------------------
% Arithmetic Tests
%------------------------------------------------------------

test_mathadd :-
    format("~nArithmetic tests:~n"),
    read_file_to_string('../../clarion_projects/python-dll/MathLib.clw', Src, []),
    exec_procedure(Src, 'MathAdd', [3, 4], R1),
    check('MathAdd(3, 4)', R1, 7),
    exec_procedure(Src, 'MathAdd', [-10, 10], R2),
    check('MathAdd(-10, 10)', R2, 0),
    exec_procedure(Src, 'Multiply', [5, 6], R3),
    check('Multiply(5, 6)', R3, 30),
    exec_procedure(Src, 'Multiply', [0, 999], R4),
    check('Multiply(0, 999)', R4, 0).

%------------------------------------------------------------
% Control Flow Tests
%------------------------------------------------------------

test_if_then :-
    format("~nControl flow tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestIf(LONG x),LONG\n  END\nTestIf PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  IF x > 10 THEN R = 1.\n  RETURN(R)\n",
    exec_procedure(Src, 'TestIf', [15], R1),
    check('IF x>10 THEN (true)', R1, 1),
    exec_procedure(Src, 'TestIf', [5], R2),
    check('IF x>10 THEN (false)', R2, 0).

test_if_else :-
    Src = "  MEMBER()\n  MAP\n    TestIf(LONG x),LONG\n  END\nTestIf PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  IF x > 10\n    R = 1\n  ELSE\n    R = 2\n  END\n  RETURN(R)\n",
    exec_procedure(Src, 'TestIf', [15], R1),
    check('IF/ELSE (true branch)', R1, 1),
    exec_procedure(Src, 'TestIf', [5], R2),
    check('IF/ELSE (false branch)', R2, 2).

test_loop_break :-
    Src = "  MEMBER()\n  MAP\n    TestLoop(),LONG\n  END\nTestLoop PROCEDURE()\nI LONG(0)\n  CODE\n  LOOP\n    I = I + 1\n    IF I = 5 THEN BREAK.\n  END\n  RETURN(I)\n",
    exec_procedure(Src, 'TestLoop', [], R),
    check('LOOP with BREAK at 5', R, 5).

test_loop_for :-
    Src = "  MEMBER()\n  MAP\n    TestFor(),LONG\n  END\nTestFor PROCEDURE()\nSum LONG(0)\nI LONG(0)\n  CODE\n  LOOP I = 1 TO 10\n    Sum = Sum + I\n  END\n  RETURN(Sum)\n",
    exec_procedure(Src, 'TestFor', [], R),
    check('LOOP I=1 TO 10 sum', R, 55).

test_case :-
    Src = "  MEMBER()\n  MAP\n    TestCase(LONG x),LONG\n  END\nTestCase PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  CASE x\n  OF 1\n    R = 10\n  OF 2\n    R = 20\n  ELSE\n    R = 99\n  END\n  RETURN(R)\n",
    exec_procedure(Src, 'TestCase', [1], R1),
    check('CASE x=1', R1, 10),
    exec_procedure(Src, 'TestCase', [2], R2),
    check('CASE x=2', R2, 20),
    exec_procedure(Src, 'TestCase', [3], R3),
    check('CASE ELSE', R3, 99).

%------------------------------------------------------------
% File I/O Tests (SensorLib)
%------------------------------------------------------------

test_sensorlib :-
    format("~nFile I/O tests (SensorLib):~n"),
    read_file_to_string('../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
    init_session(Src, S0),
    call_procedure(S0, 'SSOpen', [], R0, S1),
    check('SSOpen()', R0, 0),
    call_procedure(S1, 'SSAddReading', [1, 100, 50], R1, S2),
    check('SSAddReading(1,100,50)', R1, 0),
    call_procedure(S2, 'SSAddReading', [2, 200, 25], R2, S3),
    check('SSAddReading(2,200,25)', R2, 0),
    call_procedure(S3, 'SSAddReading', [3, 300, 10], R3, S4),
    check('SSAddReading(3,300,10)', R3, 0),
    call_procedure(S4, 'SSCalculateWeightedAverage', [], Avg, S5),
    check('SSCalculateWeightedAverage()', Avg, 152),
    call_procedure(S5, 'SSCleanupLowReadings', [150], Rem, S6),
    check('SSCleanupLowReadings(150)', Rem, 1),
    call_procedure(S6, 'SSCalculateWeightedAverage', [], Avg2, S7),
    check('SSCalculateWeightedAverage() after cleanup', Avg2, 228),
    call_procedure(S7, 'SSClose', [], R8, _),
    check('SSClose()', R8, 0).

%------------------------------------------------------------
% DiagnosisStore Tests
%------------------------------------------------------------

test_diagstore :-
    format("~nFile I/O tests (DiagnosisStore):~n"),
    read_file_to_string('../../clarion_projects/diagnosis-store/DiagnosisStore.clw', Src, []),
    init_session(Src, S0),
    % Open store first
    call_procedure(S0, 'DSOpenStore', [], R0, S1),
    check('DSOpenStore()', R0, 0),
    % Create a diagnosis (patientID, icdCode, desc, tstage, nstage, mstage, ostage, diagDate)
    call_procedure(S1, 'DSCreateDiagnosis', [101, 'C50.9', 'Breast cancer', 'T2', 'N0', 'M0', 'IIA', 0], R1, S2),
    ( R1 >= 0 -> RCreate = ok ; RCreate = fail ),
    check('DSCreateDiagnosis(101,...)', RCreate, ok),
    % Close
    call_procedure(S2, 'DSCloseStore', [], R2, _S3),
    check('DSCloseStore()', R2, 0).

%------------------------------------------------------------
% Builtin Function Tests
%------------------------------------------------------------

test_builtins :-
    format("~nBuiltin function tests:~n"),
    % SIZE: GROUP with 3 LONG fields = 12 bytes
    Src1 = "  MEMBER()\nGB GROUP,PRE(GB)\nA LONG\nB LONG\nC LONG\n  END\n  MAP\n    GetSize(),LONG\n  END\nGetSize PROCEDURE()\n  CODE\n  RETURN(SIZE(GB))\n",
    exec_procedure(Src1, 'GetSize', [], SZ),
    check('SIZE(group) = 3*4', SZ, 12),
    % LOOP WHILE
    Src2 = "  MEMBER()\n  MAP\n    TestWhile(),LONG\n  END\nTestWhile PROCEDURE()\nI LONG(0)\n  CODE\n  LOOP WHILE I < 5\n    I = I + 1\n  END\n  RETURN(I)\n",
    exec_procedure(Src2, 'TestWhile', [], RW),
    check('LOOP WHILE I<5', RW, 5),
    % LOOP UNTIL
    Src3 = "  MEMBER()\n  MAP\n    TestUntil(),LONG\n  END\nTestUntil PROCEDURE()\nI LONG(0)\n  CODE\n  LOOP UNTIL I = 3\n    I = I + 1\n  END\n  RETURN(I)\n",
    exec_procedure(Src3, 'TestUntil', [], RU),
    check('LOOP UNTIL I=3', RU, 3),
    % Modulo
    Src4 = "  MEMBER()\n  MAP\n    TestMod(LONG x),LONG\n  END\nTestMod PROCEDURE(LONG x)\n  CODE\n  RETURN(x % 3)\n",
    exec_procedure(Src4, 'TestMod', [10], RM),
    check('10 % 3 = 1', RM, 1),
    % String concatenation
    Src5 = "  MEMBER()\n  MAP\n    TestConcat(),LONG\n  END\nTestConcat PROCEDURE()\nS CSTRING(20)\n  CODE\n  S = 'Hello' & ' World'\n  RETURN(LEN(S))\n",
    exec_procedure(Src5, 'TestConcat', [], RL),
    check('LEN(Hello & World)', RL, 11).

%------------------------------------------------------------
% Main
%------------------------------------------------------------

run_test(Test) :-
    ( catch(Test, E, (format(user_error, "Error in test: ~w~n", [E]), fail))
    -> true
    ;  true  % Continue even if test fails
    ).

main :-
    format("=== Unified Interpreter Test Suite ===~n"),
    % Parser tests
    run_test(test_parse_simple),
    run_test(test_parse_mathlib),
    run_test(test_parse_sensorlib),
    run_test(test_parse_diagstore),
    run_test(test_parse_formdemo),
    run_test(test_parse_odbcstore),
    run_test(test_parse_controlflow),
    % Arithmetic
    run_test(test_mathadd),
    % Control flow
    run_test(test_if_then),
    run_test(test_if_else),
    run_test(test_loop_break),
    run_test(test_loop_for),
    run_test(test_case),
    % File I/O
    run_test(test_sensorlib),
    run_test(test_diagstore),
    % Builtins
    run_test(test_builtins),
    % Summary
    test_count(Total),
    pass_count(Pass),
    fail_count(Fail),
    format("~n=== Results: ~w passed, ~w failed out of ~w ===~n", [Pass, Fail, Total]),
    ( Fail > 0 -> halt(1) ; true ).
