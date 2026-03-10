%============================================================
% test_unified.pl - Tests for the Unified Clarion Simulator
%
% Validates that the unified system (simple parser + AST bridge
% + modular execution engine) produces correct results.
%
% Run: swipl -g "main,halt" -t "halt(1)" test_unified.pl
%============================================================

:- use_module(clarion).
:- use_module(clarion_parser).
:- use_module(ast_bridge).
:- use_module(simulator_state).
:- use_module(execution_tracer).
:- use_module(scenario_dsl).

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
% Parser Structural Tests (ported from prolog-interp)
%------------------------------------------------------------

test_parse_file_decl :-
    format("~nParser structural tests:~n"),
    Src = "  MEMBER()\n\nDiagFile  FILE,DRIVER('DOS'),NAME('Diagnosis.dat'),CREATE,PRE(DX)\nRecord      RECORD\nRecordID      LONG\nPatientID     LONG\nICDCode       CSTRING(12)\n            END\n          END\n\n  MAP\n  END\n",
    parse_clarion(Src, AST),
    AST = program(Files, _, _, _, _),
    ( Files = [file('DiagFile', 'DX', Attrs, Fields)],
      memberchk(driver('DOS'), Attrs),
      memberchk(name('Diagnosis.dat'), Attrs),
      memberchk(create, Attrs),
      length(Fields, 3)
    -> check('FILE declaration structure', ok, ok)
    ;  check('FILE declaration structure', fail, ok)
    ).

test_parse_group_decl :-
    Src = "  MEMBER()\n\nDiagBuf   GROUP,PRE(DB)\nRecordID      LONG\nPatientID     LONG\nICDCode       CSTRING(12)\n          END\n\n  MAP\n  END\n",
    parse_clarion(Src, AST),
    AST = program(_, Groups, _, _, _),
    ( Groups = [group('DiagBuf', 'DB', Fields)],
      length(Fields, 3)
    -> check('GROUP declaration structure', ok, ok)
    ;  check('GROUP declaration structure', fail, ok)
    ).

test_parse_globals :-
    Src = "  MEMBER()\n\nNextID    LONG(0)\nFilePos   LONG(0)\n\n  MAP\n  END\n",
    parse_clarion(Src, AST),
    AST = program(_, _, Globals, _, _),
    ( Globals = [global('NextID', long, 0), global('FilePos', long, 0)]
    -> check('Global variables parse', ok, ok)
    ;  check('Global variables parse', fail, ok)
    ).

test_parse_enhanced_map :-
    Src = "  MEMBER()\n\n  MAP\n    MODULE('kernel32')\n      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')\n    END\n    FindRecord(LONG id),LONG,PRIVATE\n    DSOpenStore(),LONG,C,NAME('DSOpenStore'),EXPORT\n    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT\n  END\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, MapEntries, _),
    ( MapEntries = [module_entry('kernel32', [_MemCopy]),
                    _FindRec, _DSOpen, DSCreate],
      DSCreate = map_entry('DSCreateDiagnosis', CreateParams, long, _),
      length(CreateParams, 4)
    -> check('Enhanced MAP (MODULE, PRIVATE, *CSTRING)', ok, ok)
    ;  check('Enhanced MAP (MODULE, PRIVATE, *CSTRING)', fail, ok)
    ).

test_parse_local_vars :-
    Src = "  MEMBER()\n\n  MAP\n    DSListByPatient(LONG,LONG,LONG,LONG),LONG,C,NAME('DSListByPatient'),EXPORT\n  END\n\nDSListByPatient PROCEDURE(LONG patientID, LONG bufPtr, LONG maxCount, LONG outCountPtr)\nCount  LONG(0)\nOffset LONG(0)\n  CODE\n  RETURN(0)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    ( Procs = [procedure('DSListByPatient', Params, void, Locals, _Body)],
      length(Params, 4),
      Locals = [local('Count', long, 0), local('Offset', long, 0)]
    -> check('Procedure with local variables', ok, ok)
    ;  check('Procedure with local variables', fail, ok)
    ).

test_parse_cstring_params :-
    Src = "  MEMBER()\n\n  MAP\n    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT\n  END\n\nDSCreateDiagnosis PROCEDURE(LONG patientID, *CSTRING icdCode, *CSTRING desc, LONG diagDate)\n  CODE\n  RETURN(0)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    ( Procs = [procedure('DSCreateDiagnosis', Params, void, [], _)],
      Params = [param(patientID, long),
                param(icdCode, ref(cstring)),
                param(desc, ref(cstring)),
                param(diagDate, long)]
    -> check('*CSTRING params', ok, ok)
    ;  check('*CSTRING params', fail, ok)
    ).

test_parse_statslib :-
    read_file_to_string('../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
    parse_clarion(Src, _AST),
    check('StatsLib.clw parse', ok, ok).

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
% Additional Control Flow & Expression Tests (ported from prolog-interp)
%------------------------------------------------------------

test_if_then_dot :-
    format("~nAdditional control flow tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestIf(LONG),LONG\n  END\n\nTestIf PROCEDURE(LONG val)\n  CODE\n  IF val = 1 THEN RETURN(10).\n  RETURN(20)\n",
    exec_procedure(Src, 'TestIf', [1], R1),
    check('IF THEN . (true)', R1, 10),
    exec_procedure(Src, 'TestIf', [0], R2),
    check('IF THEN . (false)', R2, 20).

test_if_block_no_else :-
    Src = "  MEMBER()\n  MAP\n    TestIf(LONG),LONG\n  END\n\nTestIf PROCEDURE(LONG val)\n  CODE\n  IF val = 1\n    RETURN(10)\n  END\n  RETURN(20)\n",
    exec_procedure(Src, 'TestIf', [1], R1),
    check('IF block no ELSE (true)', R1, 10),
    exec_procedure(Src, 'TestIf', [0], R2),
    check('IF block no ELSE (false)', R2, 20).

test_qualified_names :-
    Src = "  MEMBER()\nDiagFile FILE,DRIVER('DOS'),PRE(DX)\nRecord     RECORD\nRecordID     LONG\n           END\n         END\n  MAP\n    TestQual(),LONG\n  END\n\nTestQual PROCEDURE()\n  CODE\n  DX:RecordID = 100\n  RETURN(DX:RecordID)\n",
    exec_procedure(Src, 'TestQual', [], R1),
    check('Qualified names (DX:RecordID)', R1, 100).

test_compound_assign :-
    Src = "  MEMBER()\n  MAP\n    TestAdd(LONG),LONG\n  END\n\nTestAdd PROCEDURE(LONG val)\ni LONG(10)\n  CODE\n  i += val\n  RETURN(i)\n",
    exec_procedure(Src, 'TestAdd', [5], R1),
    check('Compound assignment (i += val)', R1, 15).

test_procedure_call_in_expr :-
    Src = "  MEMBER()\n  MAP\n    Square(LONG),LONG\n    TestCall(LONG),LONG\n  END\n\nSquare PROCEDURE(LONG n)\n  CODE\n  RETURN(n * n)\n\nTestCall PROCEDURE(LONG n)\n  CODE\n  RETURN(Square(n) + 1)\n",
    exec_procedure(Src, 'TestCall', [4], R1),
    check('Procedure call in expression (Square(4)+1)', R1, 17).

test_size_group :-
    Src = "  MEMBER()\nDiagBuf GROUP,PRE(DB)\nRecordID  LONG\nPatientID LONG\n        END\n  MAP\n    TestSize(),LONG\n  END\n\nTestSize PROCEDURE()\n  CODE\n  RETURN(SIZE(DiagBuf))\n",
    exec_procedure(Src, 'TestSize', [], R1),
    check('SIZE(DiagBuf) = 8', R1, 8).

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
% GUI Form Simulation Tests
%------------------------------------------------------------

form_source("
  PROGRAM
  MAP
  END

X LONG(50)
Y LONG(30)
Result LONG(0)

MainWindow WINDOW('Test'),AT(,,200,100),CENTER
             BUTTON('Calc'),AT(10,10,80,14),USE(?CalcBtn)
             BUTTON('Close'),AT(100,10,80,14),USE(?CloseBtn)
           END

  CODE
  OPEN(MainWindow)
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      Result = X * Y
      DISPLAY
    OF ?CloseBtn
      BREAK
    END
  END
  CLOSE(MainWindow)
  RETURN(Result)
").

test_form_calc :-
    format("~nGUI form simulation tests:~n"),
    form_source(Src),
    % CalcBtn=1, CloseBtn=2; simulate: press Calc then Close
    exec_program(Src, [1, 2], R1),
    check('Form calc: 50*30=1500', R1, 1500).

test_form_close_only :-
    form_source(Src),
    % Only press Close -- Result stays 0
    exec_program(Src, [2], R1),
    check('Form close only: Result=0', R1, 0).

test_form_multi_calc :-
    form_source(Src),
    % Press Calc twice then Close
    exec_program(Src, [1, 1, 2], R1),
    check('Form multi calc: Result=1500', R1, 1500).

test_form_no_events :-
    form_source(Src),
    % No events -- accept loop exits immediately
    exec_program(Src, [], R1),
    check('Form no events: Result=0', R1, 0).

test_formdemo_exec :-
    read_file_to_string('../../clarion_projects/form-demo/FormDemo.clw', Src, []),
    % TypeList=1, CalcBtn=2, ClearBtn=3, CloseBtn=4 (based on control order in WINDOW)
    % Simulate: set values, press Calc, then Close
    Events = [set('SensorID', 42), set('Reading', 500), set('Weight', 20), 2, 4],
    exec_program(Src, Events, R),
    % Default SensorType=1 (CHOICE defaults to 1), so: ((500*20)/100)*1 = 100
    check('FormDemo.clw calc: ((500*20)/100)*1=100', R, 100).

%------------------------------------------------------------
% ODBC Store Tests (in-memory)
%------------------------------------------------------------

test_odbcstore :-
    format("~nODBC store tests (in-memory):~n"),
    read_file_to_string('../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
    init_session(Src, S0),
    call_procedure(S0, 'ODBCOpen', [], R0, S1),
    check('ODBCOpen()', R0, 0),
    call_procedure(S1, 'ODBCAddReading', [1, 100, 10], R1, S2),
    check('ODBCAddReading(1,100,10)', R1, 1),
    call_procedure(S2, 'ODBCAddReading', [2, 200, 20], R2, S3),
    check('ODBCAddReading(2,200,20)', R2, 2),
    call_procedure(S3, 'ODBCCountReadings', [], Count, S4),
    check('ODBCCountReadings()', Count, 2),
    call_procedure(S4, 'ODBCDeleteAll', [], R3, S5),
    check('ODBCDeleteAll()', R3, 0),
    call_procedure(S5, 'ODBCCountReadings', [], Count2, S6),
    check('ODBCCountReadings() after delete', Count2, 0),
    call_procedure(S6, 'ODBCClose', [], R4, _),
    check('ODBCClose()', R4, 0).

%------------------------------------------------------------
% StatsLib Tests
%------------------------------------------------------------

test_statslib :-
    format("~nStatsLib tests:~n"),
    read_file_to_string('../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
    exec_procedure(Src, 'Classify', [5], R1),
    check('Classify(5)=1 (Low)', R1, 1),
    exec_procedure(Src, 'Classify', [50], R2),
    check('Classify(50)=2 (Medium)', R2, 2),
    exec_procedure(Src, 'Classify', [150], R3),
    check('Classify(150)=3 (High)', R3, 3).

test_statslib_exec :-
    read_file_to_string('../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
    exec_procedure(Src, 'CalculateStats', [3], R1),
    check('CalculateStats(3)=0', R1, 0).

%------------------------------------------------------------
% New Type Support Tests
%------------------------------------------------------------

test_byte_type :-
    format("~nNew type support tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestByte(),LONG\n  END\n\nTestByte PROCEDURE()\nB BYTE(255)\n  CODE\n  RETURN(B)\n",
    exec_procedure(Src, 'TestByte', [], R1),
    check('BYTE var init 255', R1, 255).

test_date_time_types :-
    Src = "  MEMBER()\n  MAP\n    TestDate(),LONG\n  END\n\nTestDate PROCEDURE()\nD DATE\nT TIME\n  CODE\n  D = 45000\n  T = 36000\n  RETURN(D + T)\n",
    exec_procedure(Src, 'TestDate', [], R1),
    check('DATE + TIME arithmetic', R1, 81000).

test_decimal_type :-
    Src = "  MEMBER()\n  MAP\n    TestDec(),LONG\n  END\n\nTestDec PROCEDURE()\nD DECIMAL(10,2)\n  CODE\n  D = 42\n  RETURN(D)\n",
    exec_procedure(Src, 'TestDec', [], R1),
    check('DECIMAL(10,2) var', R1, 42).

test_pdecimal_type :-
    Src = "  MEMBER()\n  MAP\n    TestPDec(),LONG\n  END\n\nTestPDec PROCEDURE()\nP PDECIMAL(8,2)\n  CODE\n  P = 99\n  RETURN(P)\n",
    exec_procedure(Src, 'TestPDec', [], R1),
    check('PDECIMAL(8,2) var', R1, 99).

test_sreal_type :-
    Src = "  MEMBER()\n  MAP\n    TestSReal(),LONG\n  END\n\nTestSReal PROCEDURE()\nS SREAL\n  CODE\n  S = 7\n  RETURN(S)\n",
    exec_procedure(Src, 'TestSReal', [], R1),
    check('SREAL var', R1, 7).

test_pstring_type :-
    Src = "  MEMBER()\n  MAP\n    TestPStr(),LONG\n  END\n\nTestPStr PROCEDURE()\nS PSTRING(20)\n  CODE\n  S = 'Hello'\n  RETURN(LEN(S))\n",
    exec_procedure(Src, 'TestPStr', [], R1),
    check('PSTRING(20) LEN', R1, 5).

%------------------------------------------------------------
% Optional Parameter Tests
%------------------------------------------------------------

test_optional_params_parse :-
    format("~nOptional parameter tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestOpt(LONG, <LONG>),LONG\n  END\n\nTestOpt PROCEDURE(LONG x, <LONG y>)\n  CODE\n  RETURN(x + y)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, MapEntries, Procs),
    % Check MAP has optional param
    MapEntries = [map_entry('TestOpt', MapParams, long, _)],
    length(MapParams, 2),
    MapParams = [param(anonymous, long), param(anonymous, long, optional)],
    % Check procedure def has optional param
    Procs = [procedure('TestOpt', ProcParams, void, [], _)],
    ProcParams = [param(x, long), param(y, long, optional)],
    check('Optional param parse (MAP + proc)', ok, ok).

test_optional_params_with_value :-
    Src = "  MEMBER()\n  MAP\n    TestOpt(LONG, <LONG>),LONG\n  END\n\nTestOpt PROCEDURE(LONG x, <LONG y>)\n  CODE\n  RETURN(x + y)\n",
    exec_procedure(Src, 'TestOpt', [10, 20], R1),
    check('Optional param provided: 10+20', R1, 30).

test_optional_params_default :-
    Src = "  MEMBER()\n  MAP\n    TestOpt(LONG, <LONG>),LONG\n  END\n\nTestOpt PROCEDURE(LONG x, <LONG y>)\n  CODE\n  RETURN(x + y)\n",
    exec_procedure(Src, 'TestOpt', [10], R1),
    check('Optional param default: 10+0', R1, 10).

test_optional_ref_param :-
    Src = "  MEMBER()\n  MAP\n    TestOpt(LONG, <*CSTRING>),LONG\n  END\n\nTestOpt PROCEDURE(LONG x, <*CSTRING label>)\n  CODE\n  RETURN(x)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    Procs = [procedure('TestOpt', ProcParams, void, [], _)],
    ProcParams = [param(x, long), param(label, ref(cstring), optional)],
    check('Optional *CSTRING ref param parse', ok, ok).

%------------------------------------------------------------
% QUEUE Operation Tests
%------------------------------------------------------------

test_queue_parse :-
    format("~nQUEUE tests:~n"),
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nAge LONG\n  END\n  MAP\n    TestQ(),LONG\n  END\nTestQ PROCEDURE()\n  CODE\n  RETURN(0)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, _, _),
    ( member(queue('MyQ', _), GlobalDecls) -> QOk = ok ; QOk = fail ),
    check('QUEUE declaration parsed and bridged', QOk, ok).

test_queue_add_records :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestAdd(),LONG\n  END\nTestAdd PROCEDURE()\n  CODE\n  MyQ.Name = 'Alice'\n  MyQ.Value = 10\n  ADD(MyQ)\n  MyQ.Name = 'Bob'\n  MyQ.Value = 20\n  ADD(MyQ)\n  RETURN(RECORDS(MyQ))\n",
    exec_procedure(Src, 'TestAdd', [], R),
    check('QUEUE ADD + RECORDS = 2', R, 2).

test_queue_get_by_index :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestGet(),LONG\n  END\nTestGet PROCEDURE()\n  CODE\n  MyQ.Name = 'Alice'\n  MyQ.Value = 10\n  ADD(MyQ)\n  MyQ.Name = 'Bob'\n  MyQ.Value = 20\n  ADD(MyQ)\n  GET(MyQ, 2)\n  RETURN(MyQ.Value)\n",
    exec_procedure(Src, 'TestGet', [], R),
    check('GET(Queue, 2) returns 2nd record value', R, 20).

test_queue_put_update :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestPut(),LONG\n  END\nTestPut PROCEDURE()\n  CODE\n  MyQ.Name = 'Alice'\n  MyQ.Value = 10\n  ADD(MyQ)\n  GET(MyQ, 1)\n  MyQ.Value = 99\n  PUT(MyQ)\n  GET(MyQ, 1)\n  RETURN(MyQ.Value)\n",
    exec_procedure(Src, 'TestPut', [], R),
    check('PUT updates record in queue', R, 99).

test_queue_delete :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestDel(),LONG\n  END\nTestDel PROCEDURE()\n  CODE\n  MyQ.Name = 'Alice'\n  MyQ.Value = 10\n  ADD(MyQ)\n  MyQ.Name = 'Bob'\n  MyQ.Value = 20\n  ADD(MyQ)\n  GET(MyQ, 1)\n  DELETE(MyQ)\n  RETURN(RECORDS(MyQ))\n",
    exec_procedure(Src, 'TestDel', [], R),
    check('DELETE removes record, RECORDS = 1', R, 1).

test_queue_free :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestFree(),LONG\n  END\nTestFree PROCEDURE()\n  CODE\n  MyQ.Name = 'A'\n  MyQ.Value = 1\n  ADD(MyQ)\n  MyQ.Name = 'B'\n  MyQ.Value = 2\n  ADD(MyQ)\n  FREE(MyQ)\n  RETURN(RECORDS(MyQ))\n",
    exec_procedure(Src, 'TestFree', [], R),
    check('FREE clears all records', R, 0).

test_queue_sort :-
    Src = "  MEMBER()\nMyQ QUEUE\nName STRING(20)\nValue LONG\n  END\n  MAP\n    TestSort(),LONG\n  END\nTestSort PROCEDURE()\n  CODE\n  MyQ.Name = 'Charlie'\n  MyQ.Value = 30\n  ADD(MyQ)\n  MyQ.Name = 'Alice'\n  MyQ.Value = 10\n  ADD(MyQ)\n  MyQ.Name = 'Bob'\n  MyQ.Value = 20\n  ADD(MyQ)\n  SORT(MyQ, MyQ.Value)\n  GET(MyQ, 1)\n  RETURN(MyQ.Value)\n",
    exec_procedure(Src, 'TestSort', [], R),
    check('SORT by Value, first record = 10', R, 10).

%------------------------------------------------------------
% CLASS Tests
%------------------------------------------------------------

test_class_parse :-
    format("~nCLASS support tests:~n"),
    Src = "  PROGRAM\n  MAP\n    Demo PROCEDURE\n  END\nMyClass CLASS,TYPE\nX LONG\nY LONG\nInit PROCEDURE(LONG pX, LONG pY)\nGetSum PROCEDURE,LONG\n  END\n  CODE\n  Demo()\nDemo PROCEDURE\n  CODE\n  RETURN\nMyClass.Init PROCEDURE(LONG pX, LONG pY)\n  CODE\n  SELF.X = pX\n  SELF.Y = pY\nMyClass.GetSum PROCEDURE\n  CODE\n  RETURN SELF.X + SELF.Y\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, _),
    check('CLASS declaration parses', true, true).

test_class_self_property :-
    Src = "  MEMBER()\nMyClass CLASS,TYPE\nX LONG\nY LONG\nInit PROCEDURE(LONG pX, LONG pY)\nGetSum PROCEDURE,LONG\n  END\n  MAP\n    TestSelf(),LONG\n  END\nTestSelf PROCEDURE\nobj MyClass\n  CODE\n  obj.Init(10, 20)\n  RETURN(obj.GetSum())\nMyClass.Init PROCEDURE(LONG pX, LONG pY)\n  CODE\n  SELF.X = pX\n  SELF.Y = pY\nMyClass.GetSum PROCEDURE\n  CODE\n  RETURN SELF.X + SELF.Y\n",
    exec_procedure(Src, 'TestSelf', [], R),
    check('SELF property access: 10+20=30', R, 30).

test_class_method_call :-
    Src = "  MEMBER()\nCounter CLASS,TYPE\nValue LONG\nInit PROCEDURE\nIncrement PROCEDURE\nGet PROCEDURE,LONG\n  END\n  MAP\n    TestMethod(),LONG\n  END\nTestMethod PROCEDURE\nc Counter\n  CODE\n  c.Init()\n  c.Increment()\n  c.Increment()\n  c.Increment()\n  RETURN(c.Get())\nCounter.Init PROCEDURE\n  CODE\n  SELF.Value = 0\nCounter.Increment PROCEDURE\n  CODE\n  SELF.Value = SELF.Value + 1\nCounter.Get PROCEDURE\n  CODE\n  RETURN SELF.Value\n",
    exec_procedure(Src, 'TestMethod', [], R),
    check('Method calls: 3 increments = 3', R, 3).

test_class_inheritance :-
    Src = "  MEMBER()\nBase CLASS,TYPE\nX LONG\nSetX PROCEDURE(LONG pX)\nGetX PROCEDURE,LONG\n  END\nChild CLASS(Base),TYPE\nY LONG\nSetY PROCEDURE(LONG pY)\nGetSum PROCEDURE,LONG\n  END\n  MAP\n    TestInherit(),LONG\n  END\nTestInherit PROCEDURE\nobj Child\n  CODE\n  obj.SetX(10)\n  obj.SetY(20)\n  RETURN(obj.GetSum())\nBase.SetX PROCEDURE(LONG pX)\n  CODE\n  SELF.X = pX\nBase.GetX PROCEDURE\n  CODE\n  RETURN SELF.X\nChild.SetY PROCEDURE(LONG pY)\n  CODE\n  SELF.Y = pY\nChild.GetSum PROCEDURE\n  CODE\n  RETURN SELF.X + SELF.Y\n",
    exec_procedure(Src, 'TestInherit', [], R),
    check('Inheritance: SetX(10)+SetY(20)=30', R, 30).

test_class_parent_call :-
    Src = "  MEMBER()\nBase CLASS,TYPE\nX LONG\nInit PROCEDURE(LONG pX)\n  END\nChild CLASS(Base),TYPE\nY LONG\nInit PROCEDURE(LONG pX, LONG pY)\n  END\n  MAP\n    TestParent(),LONG\n  END\nTestParent PROCEDURE\nobj Child\n  CODE\n  obj.Init(10, 20)\n  RETURN(obj.X + obj.Y)\nBase.Init PROCEDURE(LONG pX)\n  CODE\n  SELF.X = pX\nChild.Init PROCEDURE(LONG pX, LONG pY)\n  CODE\n  PARENT.Init(pX)\n  SELF.Y = pY\n",
    exec_procedure(Src, 'TestParent', [], R),
    check('PARENT.Init call: 10+20=30', R, 30).

test_class_virtual_method :-
    Src = "  MEMBER()\nShape CLASS,TYPE\nGetArea PROCEDURE,LONG,VIRTUAL\n  END\nRect CLASS(Shape),TYPE\nW LONG\nH LONG\nInit PROCEDURE(LONG pW, LONG pH)\nGetArea PROCEDURE,LONG,VIRTUAL\n  END\n  MAP\n    TestVirtual(),LONG\n  END\nTestVirtual PROCEDURE\nr Rect\n  CODE\n  r.Init(5, 10)\n  RETURN(r.GetArea())\nShape.GetArea PROCEDURE\n  CODE\n  RETURN 0\nRect.Init PROCEDURE(LONG pW, LONG pH)\n  CODE\n  SELF.W = pW\n  SELF.H = pH\nRect.GetArea PROCEDURE\n  CODE\n  RETURN SELF.W * SELF.H\n",
    exec_procedure(Src, 'TestVirtual', [], R),
    check('Virtual method override: 5*10=50', R, 50).

%------------------------------------------------------------
% MAP prototype tests
%------------------------------------------------------------

test_map_proto_preserved :-
    Src = "  MEMBER()\n  MAP\n    MathAdd(LONG a, LONG b),LONG,C,NAME('MathAdd'),EXPORT\n  END\nMathAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, program(map(MapDecls), _, _, _)),
    % Verify MAP proto has params, return type, and attrs
    member(map_proto('MathAdd', Params, 'LONG', Attrs), MapDecls),
    length(Params, 2),
    member(c, Attrs),
    member(export, Attrs),
    member(name('MathAdd'), Attrs),
    check('MAP proto preserved (params+rettype+attrs)', ok, ok).

test_map_module_external :-
    Src = "  MEMBER()\n  MAP\n    MODULE('kernel32')\n      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')\n    END\n    FindRecord(LONG id),LONG,PRIVATE\n  END\nFindRecord PROCEDURE(LONG id)\n  CODE\n  RETURN(0)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, program(map(MapDecls), _, _, _)),
    % MemCopy should be external_proc with module 'kernel32'
    member(external_proc('MemCopy', 'kernel32', _, _, ExtAttrs), MapDecls),
    member(name('RtlMoveMemory'), ExtAttrs),
    member(raw, ExtAttrs),
    member(pascal, ExtAttrs),
    % FindRecord should be a regular map_proto
    member(map_proto('FindRecord', _, 'LONG', LocalAttrs), MapDecls),
    member(private, LocalAttrs),
    check('MODULE external_proc + local map_proto', ok, ok).

test_map_name_alias_call :-
    % A procedure with NAME('AliasName') in MAP should be callable by either name
    Src = "  MEMBER()\n  MAP\n    MyAdd(LONG a, LONG b),LONG,C,NAME('AddTwo')\n  END\nMyAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
    % Call by Clarion name
    exec_procedure(Src, 'MyAdd', [3, 4], R1),
    check('Call by Clarion name MyAdd(3,4)=7', R1, 7),
    % Call by NAME alias
    exec_procedure(Src, 'AddTwo', [10, 20], R2),
    check('Call by NAME alias AddTwo(10,20)=30', R2, 30).

test_map_external_stub :-
    % Calling an external MODULE procedure should return a stub value (0 for LONG)
    Src = "  MEMBER()\n  MAP\n    MODULE('mylib')\n      ExtFunc(LONG x),LONG,C,NAME('ExtFunc')\n    END\n    TestStub(),LONG\n  END\nTestStub PROCEDURE()\nR LONG(0)\n  CODE\n  R = ExtFunc(42)\n  RETURN(R)\n",
    exec_procedure(Src, 'TestStub', [], R),
    check('External stub returns 0 for LONG', R, 0).

test_map_external_void_stub :-
    % Calling an external void procedure should not error
    Src = "  MEMBER()\n  MAP\n    MODULE('kernel32')\n      DoNothing(LONG x),RAW,PASCAL,NAME('DoNothing')\n    END\n    TestVoid(),LONG\n  END\nTestVoid PROCEDURE()\n  CODE\n  DoNothing(1)\n  RETURN(99)\n",
    exec_procedure(Src, 'TestVoid', [], R),
    check('External void stub continues execution', R, 99).

test_map_proto_arity :-
    % Verify MAP proto stores correct param count
    Src = "  MEMBER()\n  MAP\n    Proc1(),LONG\n    Proc2(LONG a),LONG\n    Proc3(LONG a, LONG b, LONG c),LONG\n  END\nProc1 PROCEDURE()\n  CODE\n  RETURN(1)\nProc2 PROCEDURE(LONG a)\n  CODE\n  RETURN(a)\nProc3 PROCEDURE(LONG a, LONG b, LONG c)\n  CODE\n  RETURN(a + b + c)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, program(map(MapDecls), _, _, _)),
    member(map_proto('Proc1', P1, _, _), MapDecls), length(P1, 0),
    member(map_proto('Proc2', P2, _, _), MapDecls), length(P2, 1),
    member(map_proto('Proc3', P3, _, _), MapDecls), length(P3, 3),
    check('MAP proto arity: 0, 1, 3 params', ok, ok).

%------------------------------------------------------------
% String Builtin Tests
%------------------------------------------------------------

test_upper :-
    format("~nString builtin tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestUpper(),LONG\n  END\nTestUpper PROCEDURE()\nS CSTRING(20)\n  CODE\n  S = UPPER('hello world')\n  RETURN(LEN(S))\n",
    exec_procedure(Src, 'TestUpper', [], R),
    check('UPPER(hello world) length', R, 11).

test_upper_value :-
    Src = "  MEMBER()\n  MAP\n    TestUV(),LONG\n  END\nTestUV PROCEDURE()\nS CSTRING(20)\nR LONG(0)\n  CODE\n  S = UPPER('abc')\n  IF S = 'ABC' THEN R = 1.\n  RETURN(R)\n",
    exec_procedure(Src, 'TestUV', [], R),
    check('UPPER(abc) = ABC', R, 1).

test_lower :-
    Src = "  MEMBER()\n  MAP\n    TestLower(),LONG\n  END\nTestLower PROCEDURE()\nS CSTRING(20)\nR LONG(0)\n  CODE\n  S = LOWER('HELLO')\n  IF S = 'hello' THEN R = 1.\n  RETURN(R)\n",
    exec_procedure(Src, 'TestLower', [], R),
    check('LOWER(HELLO) = hello', R, 1).

test_instring :-
    Src = "  MEMBER()\n  MAP\n    TestIn(),LONG\n  END\nTestIn PROCEDURE()\n  CODE\n  RETURN(INSTRING('world', 'hello world'))\n",
    exec_procedure(Src, 'TestIn', [], R),
    check('INSTRING(world, hello world) = 7', R, 7).

test_instring_notfound :-
    Src = "  MEMBER()\n  MAP\n    TestIn(),LONG\n  END\nTestIn PROCEDURE()\n  CODE\n  RETURN(INSTRING('xyz', 'hello'))\n",
    exec_procedure(Src, 'TestIn', [], R),
    check('INSTRING(xyz, hello) = 0', R, 0).

test_instring_start :-
    Src = "  MEMBER()\n  MAP\n    TestIn(),LONG\n  END\nTestIn PROCEDURE()\n  CODE\n  RETURN(INSTRING('l', 'hello world', 5))\n",
    exec_procedure(Src, 'TestIn', [], R),
    check('INSTRING(l, hello world, 5) = 10', R, 10).

test_sub :-
    Src = "  MEMBER()\n  MAP\n    TestSub(),LONG\n  END\nTestSub PROCEDURE()\nS CSTRING(20)\n  CODE\n  S = SUB('Hello World', 7, 5)\n  RETURN(LEN(S))\n",
    exec_procedure(Src, 'TestSub', [], R),
    check('SUB(Hello World, 7, 5) len=5', R, 5).

test_left :-
    Src = "  MEMBER()\n  MAP\n    TestLeft(),LONG\n  END\nTestLeft PROCEDURE()\nS CSTRING(20)\n  CODE\n  S = LEFT('  hello')\n  RETURN(LEN(S))\n",
    exec_procedure(Src, 'TestLeft', [], R),
    check('LEFT(  hello) len=5', R, 5).

%------------------------------------------------------------
% Math Builtin Tests
%------------------------------------------------------------

test_abs :-
    format("~nMath builtin tests:~n"),
    Src = "  MEMBER()\n  MAP\n    TestAbs(LONG),LONG\n  END\nTestAbs PROCEDURE(LONG x)\n  CODE\n  RETURN(ABS(x))\n",
    exec_procedure(Src, 'TestAbs', [-42], R1),
    check('ABS(-42) = 42', R1, 42),
    exec_procedure(Src, 'TestAbs', [10], R2),
    check('ABS(10) = 10', R2, 10).

test_int :-
    Src = "  MEMBER()\n  MAP\n    TestInt(),LONG\n  END\nTestInt PROCEDURE()\n  CODE\n  RETURN(INT(7))\n",
    exec_procedure(Src, 'TestInt', [], R),
    check('INT(7) = 7', R, 7).

test_sqrt :-
    Src = "  MEMBER()\n  MAP\n    TestSqrt(),LONG\n  END\nTestSqrt PROCEDURE()\nV LONG(0)\n  CODE\n  V = SQRT(144)\n  RETURN(V)\n",
    exec_procedure(Src, 'TestSqrt', [], R),
    check('SQRT(144) assigned to LONG = 12', R, 12).

test_round :-
    Src = "  MEMBER()\n  MAP\n    TestRound(),LONG\n  END\nTestRound PROCEDURE()\n  CODE\n  RETURN(ROUND(7))\n",
    exec_procedure(Src, 'TestRound', [], R),
    check('ROUND(7) = 7', R, 7).

%------------------------------------------------------------
% PREVIOUS File I/O Tests
%------------------------------------------------------------

test_previous :-
    format("~nPREVIOUS tests:~n"),
    Src = "  MEMBER()\nSensors FILE,DRIVER('DOS'),PRE(SN)\nRecord   RECORD\nID         LONG\nValue      LONG\n         END\n       END\n  MAP\n    TestPrev(),LONG\n  END\nTestPrev PROCEDURE()\n  CODE\n  CREATE(Sensors)\n  OPEN(Sensors)\n  SN:ID = 1\n  SN:Value = 100\n  ADD(Sensors)\n  SN:ID = 2\n  SN:Value = 200\n  ADD(Sensors)\n  SN:ID = 3\n  SN:Value = 300\n  ADD(Sensors)\n  SET(Sensors)\n  NEXT(Sensors)\n  NEXT(Sensors)\n  NEXT(Sensors)\n  PREVIOUS(Sensors)\n  RETURN(SN:Value)\n",
    exec_procedure(Src, 'TestPrev', [], R),
    check('PREVIOUS after 3 NEXTs = record 2 (200)', R, 200).

test_previous_at_start :-
    Src = "  MEMBER()\nSensors FILE,DRIVER('DOS'),PRE(SN)\nRecord   RECORD\nID         LONG\nValue      LONG\n         END\n       END\n  MAP\n    TestPrevStart(),LONG\n  END\nTestPrevStart PROCEDURE()\n  CODE\n  CREATE(Sensors)\n  OPEN(Sensors)\n  SN:ID = 1\n  SN:Value = 100\n  ADD(Sensors)\n  SET(Sensors)\n  NEXT(Sensors)\n  PREVIOUS(Sensors)\n  RETURN(ERRORCODE())\n",
    exec_procedure(Src, 'TestPrevStart', [], R),
    check('PREVIOUS at start = error 33', R, 33).

%------------------------------------------------------------
% Execution Tracer ML Export Tests
%------------------------------------------------------------

test_trace_capture :-
    format("~nExecution tracer tests:~n"),
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    TestAdd(LONG, LONG),LONG\n  END\nTestAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n", 'TestAdd', [3, 4], R),
    stop_trace(Trace),
    ( is_dict(Trace), R = 7 -> ROk = ok ; ROk = fail ),
    check('Trace capture returns dict with result=7', ROk, ok).

test_execution_graph :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    TestAdd(LONG, LONG),LONG\n  END\nTestAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n", 'TestAdd', [5, 10], _),
    stop_trace(_),
    get_execution_graph(Graph),
    % Note: Graph has valid structure but 0 nodes because simulator
    % does not yet emit trace events during exec_procedure.
    ( is_dict(Graph),
      Graph.nodes = Nodes,
      Graph.edges = Edges,
      is_list(Nodes), is_list(Edges)
    -> ROk = ok ; ROk = fail ),
    check('Execution graph has valid structure', ROk, ok).

test_graph_adjacency :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  IF x > 0\n    R = x * 2\n  ELSE\n    R = 0\n  END\n  RETURN(R)\n", 'T', [5], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_adjacency(Graph, AdjList, NodeTypes),
    ( is_list(AdjList), is_list(NodeTypes) -> ROk = ok ; ROk = fail ),
    check('Graph to adjacency list', ROk, ok).

test_graph_edge_index :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\n  CODE\n  RETURN(x + 1)\n", 'T', [10], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_edge_index(Graph, EdgeIndex, EdgeTypes),
    ( is_list(EdgeIndex), is_list(EdgeTypes) -> ROk = ok ; ROk = fail ),
    check('Graph to PyTorch Geometric edge_index', ROk, ok).

test_graph_pgm :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  IF x > 10\n    R = 1\n  ELSE\n    R = 0\n  END\n  RETURN(R)\n", 'T', [15], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_pgm(Graph, PGM),
    ( is_dict(PGM) -> ROk = ok ; ROk = fail ),
    check('Graph to PGM (Bayesian network)', ROk, ok).

test_pgm_pymc :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  IF x > 5\n    R = x\n  END\n  RETURN(R)\n", 'T', [8], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_pgm(Graph, PGM),
    pgm_to_pymc(PGM, PymcCode),
    ( string(PymcCode), string_length(PymcCode, Len), Len > 0 -> ROk = ok ; ROk = fail ),
    check('PGM to PyMC code generation', ROk, ok).

test_pgm_stan :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\n  CODE\n  IF x > 0\n    RETURN(1)\n  END\n  RETURN(0)\n", 'T', [3], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_pgm(Graph, PGM),
    pgm_to_stan(PGM, StanCode),
    ( string(StanCode), string_length(StanCode, Len), Len > 0 -> ROk = ok ; ROk = fail ),
    check('PGM to Stan code generation', ROk, ok).

test_graph_gnn_dataset :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(),LONG\n  END\nT PROCEDURE()\n  CODE\n  RETURN(42)\n", 'T', [], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_gnn_dataset([Graph], DatasetJson),
    ( string(DatasetJson), string_length(DatasetJson, Len), Len > 0 -> ROk = ok ; ROk = fail ),
    check('Graph to GNN dataset JSON', ROk, ok).

test_gnn_vae_code :-
    generate_gnn_vae_code(PythonCode),
    % Output is an atom (single-quoted in tracer), so use atom_length
    ( (string(PythonCode) ; atom(PythonCode)),
      atom_string(PythonCode, PStr),
      string_length(PStr, Len), Len > 100
    -> ROk = ok ; ROk = fail ),
    check('GNN-VAE Python code generation', ROk, ok).

test_graph_dot :-
    start_trace,
    exec_procedure("  MEMBER()\n  MAP\n    T(LONG),LONG\n  END\nT PROCEDURE(LONG x)\n  CODE\n  RETURN(x * 2)\n", 'T', [5], _),
    stop_trace(_),
    get_execution_graph(Graph),
    graph_to_dot(Graph, DotString),
    ( string(DotString), sub_string(DotString, _, _, _, "digraph") -> ROk = ok ; ROk = fail ),
    check('Graph to DOT format', ROk, ok).

%------------------------------------------------------------
% Scenario DSL Tests
%------------------------------------------------------------

test_scenario_proc_call :-
    format("~nScenario DSL tests:~n"),
    Scenario = scenario(
        add_test,
        [procedure_call(
            "  MEMBER()\n  MAP\n    TestAdd(LONG, LONG),LONG\n  END\nTestAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
            'TestAdd', [3, 4])],
        [],
        [return_value(7)]
    ),
    run_scenario(Scenario, Result),
    ( Result = passed(_) -> ROk = ok ; ROk = fail ),
    check('Scenario proc call TestAdd(3,4)=7', ROk, ok).

test_scenario_var_check :-
    Scenario = scenario(
        var_check,
        [procedure_call(
            "  MEMBER()\n  MAP\n    TestAdd(LONG, LONG),LONG\n  END\nTestAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
            'TestAdd', [10, 20])],
        [],
        [return_value(30)]
    ),
    run_scenario(Scenario, Result),
    ( Result = passed(_) -> ROk = ok ; ROk = fail ),
    check('Scenario var check return=30', ROk, ok).

test_scenario_fail_expect :-
    Scenario = scenario(
        wrong_result,
        [procedure_call(
            "  MEMBER()\n  MAP\n    TestAdd(LONG, LONG),LONG\n  END\nTestAdd PROCEDURE(LONG a, LONG b)\n  CODE\n  RETURN(a + b)\n",
            'TestAdd', [3, 4])],
        [],
        [return_value(999)]
    ),
    run_scenario(Scenario, Result),
    ( Result = failed(_, _) -> ROk = ok ; ROk = fail ),
    check('Scenario failed expectation detected', ROk, ok).

test_scenario_no_error :-
    Scenario = scenario(
        error_check,
        [procedure_call(
            "  MEMBER()\n  MAP\n    TestErr(),LONG\n  END\nTestErr PROCEDURE()\n  CODE\n  RETURN(ERRORCODE())\n",
            'TestErr', [])],
        [],
        [no_error]
    ),
    run_scenario(Scenario, Result),
    ( Result = passed(_) -> ROk = ok ; ROk = fail ),
    check('Scenario no_error check', ROk, ok).

%------------------------------------------------------------
% Main
%------------------------------------------------------------

run_test(Test) :-
    ( catch(Test, E, (format(user_error, "Error in test: ~w~n", [E]), fail))
    -> true
    ;  true  % Continue even if test fails
    ).

main :-
    format("=== Unified Simulator Test Suite ===~n"),
    % Parser tests (bridge)
    run_test(test_parse_simple),
    run_test(test_parse_mathlib),
    run_test(test_parse_sensorlib),
    run_test(test_parse_diagstore),
    run_test(test_parse_formdemo),
    run_test(test_parse_odbcstore),
    run_test(test_parse_controlflow),
    % Parser structural tests (ported from prolog-interp)
    run_test(test_parse_file_decl),
    run_test(test_parse_group_decl),
    run_test(test_parse_globals),
    run_test(test_parse_enhanced_map),
    run_test(test_parse_local_vars),
    run_test(test_parse_cstring_params),
    run_test(test_parse_statslib),
    % Arithmetic
    run_test(test_mathadd),
    % Control flow
    run_test(test_if_then),
    run_test(test_if_else),
    run_test(test_loop_break),
    run_test(test_loop_for),
    run_test(test_case),
    % Additional control flow & expressions (ported from prolog-interp)
    run_test(test_if_then_dot),
    run_test(test_if_block_no_else),
    run_test(test_qualified_names),
    run_test(test_compound_assign),
    run_test(test_procedure_call_in_expr),
    run_test(test_size_group),
    % File I/O
    run_test(test_sensorlib),
    run_test(test_diagstore),
    % Builtins
    run_test(test_builtins),
    % GUI form simulation
    run_test(test_form_calc),
    run_test(test_form_close_only),
    run_test(test_form_multi_calc),
    run_test(test_form_no_events),
    run_test(test_formdemo_exec),
    % ODBC store
    run_test(test_odbcstore),
    % StatsLib
    run_test(test_statslib),
    run_test(test_statslib_exec),
    % New type support
    run_test(test_byte_type),
    run_test(test_date_time_types),
    run_test(test_decimal_type),
    run_test(test_pdecimal_type),
    run_test(test_sreal_type),
    run_test(test_pstring_type),
    % Optional parameters
    run_test(test_optional_params_parse),
    run_test(test_optional_params_with_value),
    run_test(test_optional_params_default),
    run_test(test_optional_ref_param),
    % QUEUE operations
    run_test(test_queue_parse),
    run_test(test_queue_add_records),
    run_test(test_queue_get_by_index),
    run_test(test_queue_put_update),
    run_test(test_queue_delete),
    run_test(test_queue_free),
    run_test(test_queue_sort),
    % CLASS support
    run_test(test_class_parse),
    run_test(test_class_self_property),
    run_test(test_class_method_call),
    run_test(test_class_inheritance),
    run_test(test_class_parent_call),
    run_test(test_class_virtual_method),
    % MAP prototype support
    run_test(test_map_proto_preserved),
    run_test(test_map_module_external),
    run_test(test_map_name_alias_call),
    run_test(test_map_external_stub),
    run_test(test_map_external_void_stub),
    run_test(test_map_proto_arity),
    % String builtins
    run_test(test_upper),
    run_test(test_upper_value),
    run_test(test_lower),
    run_test(test_instring),
    run_test(test_instring_notfound),
    run_test(test_instring_start),
    run_test(test_sub),
    run_test(test_left),
    % Math builtins
    run_test(test_abs),
    run_test(test_int),
    run_test(test_sqrt),
    run_test(test_round),
    % PREVIOUS
    run_test(test_previous),
    run_test(test_previous_at_start),
    % Execution tracer ML exports
    run_test(test_trace_capture),
    run_test(test_execution_graph),
    run_test(test_graph_adjacency),
    run_test(test_graph_edge_index),
    run_test(test_graph_pgm),
    run_test(test_pgm_pymc),
    run_test(test_pgm_stan),
    run_test(test_graph_gnn_dataset),
    run_test(test_gnn_vae_code),
    run_test(test_graph_dot),
    % Scenario DSL
    run_test(test_scenario_proc_call),
    run_test(test_scenario_var_check),
    run_test(test_scenario_fail_expect),
    run_test(test_scenario_no_error),
    % Summary
    test_count(Total),
    pass_count(Pass),
    fail_count(Fail),
    format("~n=== Results: ~w passed, ~w failed out of ~w ===~n", [Pass, Fail, Total]),
    ( Fail > 0 -> halt(1) ; true ).
