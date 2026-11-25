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
:- use_module(clarion_preproc).
:- use_module(ast_bridge).
:- use_module(simulator_state).
:- use_module(execution_tracer).
:- use_module(scenario_dsl).
:- use_module(storage_backend).
:- use_module(ui_backend).
:- use_module(ast_mermaid).

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
    read_file_to_string('../../../clarion_projects/python-dll/MathLib.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    check('MathLib.clw parse + bridge', N, 2).

test_parse_sensorlib :-
    read_file_to_string('../../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, _, Procs),
    length(Procs, NP),
    include([X]>>(X = file(_, _, _)), GlobalDecls, Files),
    length(Files, NF),
    check('SensorLib.clw parse + bridge procs', NP, 6),
    check('SensorLib.clw file declarations', NF, 1).

test_parse_diagstore :-
    read_file_to_string('../../../clarion_projects/diagnosis-store/DiagnosisStore.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    ( N > 0 -> R = true ; R = false ),
    check('DiagnosisStore.clw parse + bridge', R, true).

test_parse_formdemo :-
    read_file_to_string('../../../clarion_projects/form-demo/FormDemo.clw', Src, []),
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
    read_file_to_string('../../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, _, _, Procs),
    length(Procs, N),
    ( N > 0 -> RN = true ; RN = false ),
    check('OdbcStore.clw parse + bridge', RN, true).

test_parse_controlflow :-
    read_file_to_string('../../../clarion_projects/clarion_examples/control_flow.clw', Src, []),
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
    read_file_to_string('../../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
    parse_clarion(Src, _AST),
    check('StatsLib.clw parse', ok, ok).

%------------------------------------------------------------
% Arithmetic Tests
%------------------------------------------------------------

test_mathadd :-
    format("~nArithmetic tests:~n"),
    read_file_to_string('../../../clarion_projects/python-dll/MathLib.clw', Src, []),
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
    read_file_to_string('../../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
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
    read_file_to_string('../../../clarion_projects/diagnosis-store/DiagnosisStore.clw', Src, []),
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
    read_file_to_string('../../../clarion_projects/form-demo/FormDemo.clw', Src, []),
    % With implicit equates for USE(Var) controls:
    % SensorID=1, Reading=2, Weight=3, TypeList=4, CalcBtn=5, ClearBtn=6, CloseBtn=7, Result=8
    % Simulate: set values, press Calc, then Close
    Events = [set('SensorID', 42), set('Reading', 500), set('Weight', 20), 5, 7],
    exec_program(Src, Events, R),
    % Default SensorType=1 (CHOICE defaults to 1), so: ((500*20)/100)*1 = 100
    check('FormDemo.clw calc: ((500*20)/100)*1=100', R, 100).

%------------------------------------------------------------
% ODBC Store Tests (in-memory)
%------------------------------------------------------------

% ODBCDeleteAll would wipe a real table, so run this with no DSN configured.
test_odbcstore :-
    with_env('CLARION_ODBC_DSN', unset, test_odbcstore_in_memory).

test_odbcstore_in_memory :-
    format("~nODBC store tests (in-memory):~n"),
    read_file_to_string('../../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
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
% ODBC Store Tests (SQLite round trip)
%
% Runs OdbcStore.clw against a throwaway SQLite database through
% the real ODBC backend. Skipped when library(odbc), a driver
% manager or the SQLite driver is missing. The probe and the row
% checks use library(odbc) directly, never storage_odbc, so a
% broken backend (which falls back to memory) fails, not skips.
%------------------------------------------------------------

:- if(exists_source(library(odbc))).
:- use_module(library(odbc), []).
:- endif.

test_odbcstore_sqlite :-
    format("~nODBC store tests (SQLite round trip):~n"),
    with_sqlite(odbcstore_sqlite_round_trip).

%% with_sqlite(:Goal): run Goal against a fresh SQLite database, or skip.
with_sqlite(Goal) :-
    sqlite_fixture(Ini, Db),
    ( exists_file(Db) -> delete_file(Db) ; true ),
    with_env('ODBCINI', Ini,
        with_env('CLARION_ODBC_DSN', 'ClarionSqliteTest',
            sqlite_or_skip(Goal))).

% One fixture per process: unixODBC caches the DSN, so its path cannot change.
:- dynamic sqlite_fixture_files/2.
sqlite_fixture(Ini, Db) :- sqlite_fixture_files(Ini, Db), !.
sqlite_fixture(Ini, Db) :-
    tmp_file(clarion_odbc, Dir),
    make_directory(Dir),
    at_halt(delete_directory_and_contents(Dir)),
    directory_file_path(Dir, 'odbc.ini', Ini),
    directory_file_path(Dir, 'test.db', Db),
    setup_call_cleanup(
        open(Ini, write, Out),
        format(Out, "[ClarionSqliteTest]~nDriver=SQLite3~nDatabase=~w~n", [Db]),
        close(Out)),
    assertz(sqlite_fixture_files(Ini, Db)).

% Skip only when ODBC is not installed; any other error is a test failure.
sqlite_or_skip(Goal) :-
    catch(raw_odbc('SELECT 1', _), Error, true),
    ( var(Error)
    -> call(Goal)
    ; odbc_not_installed(Error)
    -> format("  [SKIP] SQLite ODBC unavailable: ~p~n", [Error])
    ;  throw(Error)
    ).

odbc_not_installed(error(existence_error(procedure, odbc:_), _)).
odbc_not_installed(error(odbc('IM002', _, _), _)).  % no such DSN or driver
odbc_not_installed(error(odbc('IM003', _, _), _)).  % driver could not be loaded
odbc_not_installed(error(odbc('01000', _, _), _)).  % unixODBC: can't open driver lib

odbcstore_sqlite_round_trip :-
    raw_odbc('CREATE TABLE SensorReadings (ReadingID INTEGER PRIMARY KEY, SensorID INTEGER, Value INTEGER, Weight INTEGER, Timestamp INTEGER)', _),
    raw_odbc('INSERT INTO SensorReadings VALUES (7, 1, 100, 10, 5)', _),
    read_file_to_string('../../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
    % Session 1: sees the existing row, adds two more
    init_session(Src, S0),
    call_procedure(S0, 'ODBCOpen', [], R0, S1),
    check('SQLite: ODBCOpen()', R0, 0),
    call_procedure(S1, 'ODBCCountReadings', [], C1, S2),
    check('SQLite: existing row loaded', C1, 1),
    call_procedure(S2, 'ODBCAddReading', [2, 200, 20], R2, S3),
    check('SQLite: NextID continues from table', R2, 8),
    call_procedure(S3, 'ODBCAddReading', [3, 300, 30], R3, S4),
    check('SQLite: second add', R3, 9),
    call_procedure(S4, 'ODBCClose', [], R4, _),
    check('SQLite: ODBCClose()', R4, 0),
    raw_odbc('SELECT ReadingID, SensorID, Value, Weight FROM SensorReadings ORDER BY ReadingID', Rows1),
    check('SQLite: rows persisted', Rows1,
          [row(7,1,100,10), row(8,2,200,20), row(9,3,300,30)]),
    % Session 2: fresh state reads them back, then deletes them
    init_session(Src, T0),
    call_procedure(T0, 'ODBCOpen', [], Q0, T1),
    check('SQLite: reopen', Q0, 0),
    call_procedure(T1, 'ODBCCountReadings', [], C2, T2),
    check('SQLite: count after reopen', C2, 3),
    call_procedure(T2, 'ODBCDeleteAll', [], Q2, T3),
    check('SQLite: ODBCDeleteAll()', Q2, 0),
    call_procedure(T3, 'ODBCClose', [], _, _),
    raw_odbc('SELECT ReadingID FROM SensorReadings', Rows2),
    check('SQLite: deletes persisted', Rows2, []).

% --- Failures must be reported and must never cost existing rows ---

test_odbc_safety :-
    format("~nODBC data safety tests (SQLite):~n"),
    with_sqlite(odbc_load_failure),
    with_sqlite(odbc_connect_failure),
    with_sqlite(odbc_insert_failure),
    with_sqlite(odbc_write_through),
    with_sqlite(odbc_put_preserves),
    with_sqlite(odbc_put_conflict),
    with_sqlite(odbc_delete_ambiguous),
    with_sqlite(odbc_empty_table).

odbcstore_session(S0) :-
    read_file_to_string('../../../clarion_projects/odbc-store/OdbcStore.clw', Src, []),
    init_session(Src, S0).

sensor_table(Extra) :-
    format(atom(SQL), 'CREATE TABLE SensorReadings (ReadingID INTEGER PRIMARY KEY, SensorID INTEGER, Value INTEGER, Weight INTEGER~w)', [Extra]),
    raw_odbc(SQL, _).

% Table lacks a declared column, so the rows cannot be loaded.
odbc_load_failure :-
    sensor_table(''),
    raw_odbc('INSERT INTO SensorReadings VALUES (1,1,100,10),(2,2,200,20)', _),
    odbcstore_session(S0),
    call_procedure(S0, 'ODBCOpen', [], R0, S1),
    check('load failure: ODBCOpen reports it', R0, -3),
    call_procedure(S1, 'ODBCAddReading', [3, 300, 30], R1, S2),
    check('load failure: add after failed open refused', R1, -2),
    call_procedure(S2, 'ODBCDeleteAll', [], _, S3),
    call_procedure(S3, 'ODBCClose', [], _, _),
    raw_odbc('SELECT ReadingID FROM SensorReadings ORDER BY ReadingID', Rows),
    check('load failure: existing rows intact', Rows, [row(1), row(2)]).

odbc_connect_failure :-
    odbcstore_session(S0),
    with_env('CLARION_ODBC_DSN', 'ClarionNoSuchDsn',
        ( call_procedure(S0, 'ODBCOpen', [], R0, S1),
          call_procedure(S1, 'ODBCAddReading', [3, 300, 30], R1, _) )),
    check('connect failure: ODBCOpen reports it', R0, -3),
    check('connect failure: add refused', R1, -2).

odbc_insert_failure :-
    sensor_table(', Timestamp INTEGER, CHECK (Value < 1000)'),
    raw_odbc('INSERT INTO SensorReadings VALUES (1,1,100,10,5)', _),
    odbcstore_session(S0),
    call_procedure(S0, 'ODBCOpen', [], _, S1),
    call_procedure(S1, 'ODBCAddReading', [2, 5000, 20], R1, S2),
    check('insert failure: reported by the ADD', R1, -2),
    call_procedure(S2, 'ODBCCountReadings', [], C, S3),
    check('insert failure: not counted', C, 1),
    call_procedure(S3, 'ODBCAddReading', [2, 200, 20], _, S4),
    call_procedure(S4, 'ODBCClose', [], _, _),
    raw_odbc('SELECT Value FROM SensorReadings ORDER BY Value', Rows),
    check('insert failure: other rows intact', Rows, [row(100), row(200)]).

odbc_write_through :-
    sensor_table(', Timestamp INTEGER, Note TEXT'),
    raw_odbc('INSERT INTO SensorReadings VALUES (1,1,100,10,5,''keep'')', _),
    odbcstore_session(S0),
    call_procedure(S0, 'ODBCOpen', [], _, S1),
    raw_odbc('INSERT INTO SensorReadings VALUES (50,9,900,90,5,''other'')', _),
    call_procedure(S1, 'ODBCAddReading', [2, 3000000000, 20], _, S2),
    raw_odbc('SELECT CAST(Value AS TEXT), typeof(Value) FROM SensorReadings WHERE ReadingID = 2', Big),
    check('write-through: row stored before CLOSE, value exact', Big, [row('3000000000', integer)]),
    call_procedure(S2, 'ODBCClose', [], _, _),
    raw_odbc('SELECT ReadingID, Note FROM SensorReadings WHERE Note IS NOT NULL ORDER BY ReadingID', Notes),
    check('write-through: undeclared column and other writer''s row kept', Notes,
          [row(1,keep), row(50,other)]).

person_session(S0) :-
    raw_odbc('CREATE TABLE People (ID INTEGER, Name TEXT, Score REAL, Note TEXT)', _),
    raw_odbc('INSERT INTO People VALUES (1,''Ann'',0.1,''keep'')', _),
    Src = "  MEMBER()\nPeople FILE,DRIVER('ODBC'),PRE(PP)\nRecord RECORD\nID LONG\nName STRING(20)\nScore REAL\n  END\n  END\n  MAP\n    POpen(),LONG\n    PRename(),LONG\n    PDelete(),LONG\n    PEmpty(),LONG\n    PClose(),LONG\n  END\nPOpen PROCEDURE()\n  CODE\n  OPEN(People)\n  RETURN(ERRORCODE())\nPRename PROCEDURE()\n  CODE\n  SET(People)\n  NEXT(People)\n  PP:Name = 'O''Brien'\n  PUT(People)\n  RETURN(ERRORCODE())\nPDelete PROCEDURE()\n  CODE\n  SET(People)\n  NEXT(People)\n  DELETE(People)\n  RETURN(ERRORCODE())\nPEmpty PROCEDURE()\n  CODE\n  EMPTY(People)\n  RETURN(ERRORCODE())\nPClose PROCEDURE()\n  CODE\n  CLOSE(People)\n  RETURN(ERRORCODE())\n",
    init_session(Src, S0).

odbc_put_preserves :-
    person_session(S0),
    call_procedure(S0, 'POpen', [], R0, S1),
    check('PUT: OPEN', R0, 0),
    call_procedure(S1, 'POpen', [], R1, S2),
    check('PUT: second OPEN is error 52', R1, 52),
    call_procedure(S2, 'PRename', [], R2, S3),
    check('PUT: succeeds', R2, 0),
    call_procedure(S3, 'PRename', [], R3, S4),
    check('PUT: again on the updated row', R3, 0),
    call_procedure(S4, 'PClose', [], R4, _),
    check('PUT: CLOSE', R4, 0),
    raw_odbc('SELECT ID, Name, Score, Note FROM People', Rows),
    check('PUT: quote stored, undeclared column kept', Rows,
          [row(1,'O\'Brien',0.1,keep)]).

odbc_put_conflict :-
    person_session(S0),
    call_procedure(S0, 'POpen', [], _, S1),
    raw_odbc('UPDATE People SET Name = ''Changed''', _),
    call_procedure(S1, 'PRename', [], R, S2),
    check('conflict: PUT is error 89', R, 89),
    call_procedure(S2, 'PDelete', [], RD, S3),
    check('conflict: DELETE is error 89', RD, 89),
    call_procedure(S3, 'PClose', [], _, _),
    raw_odbc('SELECT Name FROM People', Rows),
    check('conflict: other writer''s change kept', Rows, [row('Changed')]).

% Two rows identical in every declared column: cannot tell which to delete.
odbc_delete_ambiguous :-
    person_session(S0),
    raw_odbc('INSERT INTO People VALUES (1,''Ann'',0.1,''twin'')', _),
    call_procedure(S0, 'POpen', [], _, S1),
    call_procedure(S1, 'PDelete', [], R, S2),
    check('ambiguous: DELETE refused', R, 89),
    call_procedure(S2, 'PClose', [], _, _),
    raw_odbc('SELECT Note FROM People ORDER BY Note', Rows),
    check('ambiguous: both rows kept', Rows, [row(keep), row(twin)]).

odbc_empty_table :-
    person_session(S0),
    call_procedure(S0, 'PEmpty', [], R0, S1),
    check('EMPTY: refused before OPEN', R0, 37),
    call_procedure(S1, 'POpen', [], _, S2),
    call_procedure(S2, 'PEmpty', [], R1, S3),
    check('EMPTY: succeeds when open', R1, 0),
    call_procedure(S3, 'PClose', [], _, _),
    raw_odbc('SELECT ID FROM People', Rows),
    check('EMPTY: table emptied', Rows, []).

% --- Date and time columns ---

test_clarion_dates :-
    format("~nClarion date conversion tests:~n"),
    % Endpoints documented for Clarion standard dates
    check('1801-01-01 is day 4', D1, 4, clarion_dates:date_days(date(1801,1,1), D1)),
    check('9999-12-31 is day 2994626', D2, 2994626, clarion_dates:date_days(date(9999,12,31), D2)),
    check('day 4 back', B1, date(1801,1,1), clarion_dates:days_date(4, B1)),
    check('day 2994626 back', B2, date(9999,12,31), clarion_dates:days_date(2994626, B2)),
    check('1 day across non-leap 1900-02-28', N1, 1,
          ( clarion_dates:date_days(date(1900,2,28), X1), clarion_dates:date_days(date(1900,3,1), X2), N1 is X2-X1 )),
    check('2 days across leap 2000-02-28', N2, 2,
          ( clarion_dates:date_days(date(2000,2,28), X3), clarion_dates:date_days(date(2000,3,1), X4), N2 is X4-X3 )),
    % One full 400-year Gregorian cycle (146097 days)
    ( forall(between(4, 146100, Day),
             ( clarion_dates:days_date(Day, Date), clarion_dates:date_days(Date, Day) ))
    -> All = ok ; All = mismatch ),
    check('every day of a 400-year cycle round-trips', All, ok),
    ( clarion_dates:days_date(3, _) -> Low = accepted ; Low = refused ),
    check('day 3 refused', Low, refused),
    ( clarion_dates:days_date(2994627, _) -> High = accepted ; High = refused ),
    check('day 2994627 refused', High, refused),
    ( clarion_dates:date_days(date(2023,2,29), _) -> Bad = accepted ; Bad = refused ),
    check('2023-02-29 refused', Bad, refused),
    check('midnight is time 1', T1, 1, clarion_dates:time_centis(time(0,0,0), T1)),
    check('23:59:59 time', T2, 8639901, clarion_dates:time_centis(time(23,59,59), T2)).

check(Label, Got, Expected, Goal) :-
    ( call(Goal) -> true ; Got = goal_failed ),
    check(Label, Got, Expected).

test_odbc_dates :-
    format("~nODBC date/time column tests (SQLite):~n"),
    with_sqlite(odbc_dates_read),
    with_sqlite(odbc_dates_write),
    with_sqlite(odbc_dates_nulls),
    with_sqlite(odbc_dates_text),
    with_sqlite(odbc_dates_refused),
    with_sqlite(odbc_dates_inexact),
    with_sqlite(odbc_dates_similar_table).

% Visits(ID LONG, Day LONG, At TIME, Seen LONG); columns INTEGER, DATE, TIME, DATETIME
visits_session(S0) :-
    raw_odbc('CREATE TABLE Visits (ID INTEGER, Day DATE, At TIME, Seen DATETIME)', _),
    visits_source("LONG", "TIME", "LONG", Src),
    init_session(Src, S0).

visits_source(DayType, AtType, SeenType, Src) :-
    format(string(Src), "  MEMBER()\nVisits FILE,DRIVER('ODBC'),PRE(VV)\nRecord RECORD\nID LONG\nDay ~w\nAt ~w\nSeen ~w\n  END\n  END\n  MAP\n    VOpen(),LONG\n    VFirst(),LONG\n    VDay(),LONG\n    VAt(),LONG\n    VSeen(),LONG\n    VAdd(LONG id, LONG dy, LONG tm, LONG sn),LONG\n    VMove(LONG dy),LONG\n    VDelete(),LONG\n    VAddText(),LONG\n    VAddBadText(),LONG\n    VClose(),LONG\n  END\nVOpen PROCEDURE()\n  CODE\n  OPEN(Visits)\n  RETURN(ERRORCODE())\nVFirst PROCEDURE()\n  CODE\n  SET(Visits)\n  NEXT(Visits)\n  RETURN(ERRORCODE())\nVDay PROCEDURE()\n  CODE\n  RETURN(VV:Day)\nVAt PROCEDURE()\n  CODE\n  RETURN(VV:At)\nVSeen PROCEDURE()\n  CODE\n  RETURN(VV:Seen)\nVAdd PROCEDURE(LONG id, LONG dy, LONG tm, LONG sn)\n  CODE\n  VV:ID = id\n  VV:Day = dy\n  VV:At = tm\n  VV:Seen = sn\n  ADD(Visits)\n  RETURN(ERRORCODE())\nVMove PROCEDURE(LONG dy)\n  CODE\n  VV:Day = dy\n  PUT(Visits)\n  RETURN(ERRORCODE())\nVDelete PROCEDURE()\n  CODE\n  DELETE(Visits)\n  RETURN(ERRORCODE())\nVAddText PROCEDURE()\n  CODE\n  VV:ID = 2\n  VV:Day = '2024-02-29'\n  VV:At = '23:59:58'\n  VV:Seen = '2024-02-29 01:02:03.5'\n  ADD(Visits)\n  RETURN(ERRORCODE())\nVAddBadText PROCEDURE()\n  CODE\n  VV:ID = 3\n  VV:Day = '2023-02-29'\n  ADD(Visits)\n  RETURN(ERRORCODE())\nVClose PROCEDURE()\n  CODE\n  CLOSE(Visits)\n  RETURN(ERRORCODE())\n",
           [DayType, AtType, SeenType]).

odbc_dates_read :-
    visits_session(S0),
    raw_odbc('INSERT INTO Visits VALUES (1,''2024-01-02'',''01:02:03'',''2024-01-02 00:00:00.000'')', _),
    call_procedure(S0, 'VOpen', [], R0, S1), check('dates read: OPEN', R0, 0),
    call_procedure(S1, 'VFirst', [], R1, S2), check('dates read: NEXT', R1, 0),
    % 2024-01-02 is 81454 days after 1800-12-28
    call_procedure(S2, 'VDay', [], D, S3), check('dates read: DATE column', D, 81454),
    call_procedure(S3, 'VAt', [], T, S4), check('dates read: TIME column', T, 372301),
    call_procedure(S4, 'VSeen', [], N, _), check('dates read: midnight DATETIME column', N, 81454).

odbc_dates_write :-
    visits_session(S0),
    call_procedure(S0, 'VOpen', [], _, S1),
    call_procedure(S1, 'VAdd', [1, 81454, 372301, 81454], R1, S2),
    check('dates write: ADD', R1, 0),
    raw_odbc('SELECT CAST(Day AS TEXT), CAST(At AS TEXT), CAST(Seen AS TEXT) FROM Visits', Rows),
    check('dates write: stored', Rows, [row('2024-01-02','01:02:03','2024-01-02 00:00:00.000')]),
    call_procedure(S2, 'VFirst', [], _, S3),
    call_procedure(S3, 'VMove', [81455], R2, S4),
    check('dates write: PUT', R2, 0),
    raw_odbc('SELECT CAST(Day AS TEXT) FROM Visits', Rows2),
    check('dates write: PUT stored', Rows2, [row('2024-01-03')]),
    call_procedure(S4, 'VFirst', [], _, S5),
    call_procedure(S5, 'VDelete', [], R3, _),
    check('dates write: DELETE', R3, 0),
    raw_odbc('SELECT ID FROM Visits', Rows3),
    check('dates write: DELETE stored', Rows3, []).

odbc_dates_nulls :-
    visits_session(S0),
    raw_odbc('INSERT INTO Visits VALUES (1,NULL,NULL,NULL)', _),
    call_procedure(S0, 'VOpen', [], _, S1),
    call_procedure(S1, 'VFirst', [], _, S2),
    call_procedure(S2, 'VDay', [], D, S3), check('dates null: reads as 0', D, 0),
    call_procedure(S3, 'VMove', [81454], R, S4), check('dates null: PUT over NULL', R, 0),
    call_procedure(S4, 'VAdd', [2, 0, 0, 0], R2, _), check('dates null: ADD of 0', R2, 0),
    raw_odbc('SELECT ID, Day IS NULL, At IS NULL FROM Visits ORDER BY ID', Rows),
    check('dates null: 0 stored as NULL', Rows, [row(1,0,1), row(2,1,1)]).

odbc_dates_text :-
    raw_odbc('CREATE TABLE Visits (ID INTEGER, Day DATE, At TIME, Seen DATETIME)', _),
    raw_odbc('INSERT INTO Visits VALUES (1,''2024-01-02'',''01:02:03'',''2024-01-02 04:05:06.250'')', _),
    visits_source("STRING(30)", "STRING(30)", "STRING(30)", Src),
    init_session(Src, S0),
    call_procedure(S0, 'VOpen', [], R0, S1), check('dates text: OPEN', R0, 0),
    call_procedure(S1, 'VFirst', [], _, S2),
    call_procedure(S2, 'VDay', [], D, S3), check('dates text: DATE', D, '2024-01-02'),
    call_procedure(S3, 'VSeen', [], N, S4), check('dates text: DATETIME', N, '2024-01-02 04:05:06.25'),
    call_procedure(S4, 'VDelete', [], R1, S5), check('dates text: DELETE matches', R1, 0),
    call_procedure(S5, 'VAddText', [], R2, S6), check('dates text: ADD', R2, 0),
    call_procedure(S6, 'VAddBadText', [], R3, _), check('dates text: 2023-02-29 refused', R3, 90),
    raw_odbc('SELECT CAST(Day AS TEXT), CAST(At AS TEXT), CAST(Seen AS TEXT) FROM Visits', Rows),
    check('dates text: stored', Rows, [row('2024-02-29','23:59:58','2024-02-29 01:02:03.500')]).

odbc_dates_refused :-
    visits_session(S0),
    call_procedure(S0, 'VOpen', [], _, S1),
    call_procedure(S1, 'VAdd', [1, 3, 0, 0], R1, S2), check('dates refused: day 3', R1, 90),
    call_procedure(S2, 'VAdd', [1, 2994627, 0, 0], R2, S3), check('dates refused: day 2994627', R2, 90),
    call_procedure(S3, 'VAdd', [1, 81454, 8640001, 0], R3, S4), check('dates refused: time past midnight', R3, 90),
    call_procedure(S4, 'VAdd', [1, 81454, 150, 0], R4, _), check('dates refused: part-second time', R4, 90),
    raw_odbc('SELECT ID FROM Visits', Rows), check('dates refused: nothing stored', Rows, []).

% A LONG cannot hold the time of day, so reading it would lose data.
odbc_dates_inexact :-
    visits_session(S0),
    raw_odbc('INSERT INTO Visits VALUES (1,''2024-01-02'',''01:02:03'',''2024-01-02 04:05:06.000'')', _),
    call_procedure(S0, 'VOpen', [], R, _),
    check('dates inexact: OPEN refused', R, 90).

% SQLColumns treats _ as a wildcard: VisitXs must not supply the types for Visit_s.
odbc_dates_similar_table :-
    raw_odbc('CREATE TABLE VisitXs (ID INTEGER, Day INTEGER)', _),
    raw_odbc('CREATE TABLE Visit_s (ID INTEGER, Day DATE)', _),
    raw_odbc('INSERT INTO Visit_s VALUES (1,''2024-01-02'')', _),
    Src = "  MEMBER()\nVisit_s FILE,DRIVER('ODBC'),PRE(VV)\nRecord RECORD\nID LONG\nDAY LONG\n  END\n  END\n  MAP\n    VDay(),LONG\n  END\nVDay PROCEDURE()\n  CODE\n  OPEN(Visit_s)\n  SET(Visit_s)\n  NEXT(Visit_s)\n  RETURN(VV:DAY)\n",
    exec_procedure(Src, 'VDay', [], D),
    check('dates similar table: own types, any case', D, 81454).

%% raw_odbc(+SQL, -Rows): query on a private connection, bypassing storage_odbc.
raw_odbc(SQL, Rows) :-
    setup_call_cleanup(
        odbc:odbc_connect('ClarionSqliteTest', C, [open(multiple)]),
        findall(Row, odbc:odbc_query(C, SQL, Row), Rows),
        odbc:odbc_disconnect(C)).

%% with_env(+Var, +Value, :Goal): run Goal with Var set (or `unset`), then restore.
with_env(Var, Value, Goal) :-
    ( getenv(Var, Old) -> true ; Old = unset ),
    setup_call_cleanup(put_env(Var, Value), Goal, put_env(Var, Old)).

put_env(Var, unset) :- !, unsetenv(Var).
put_env(Var, Value) :- setenv(Var, Value).

%------------------------------------------------------------
% StatsLib Tests
%------------------------------------------------------------

test_statslib :-
    format("~nStatsLib tests:~n"),
    read_file_to_string('../../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
    exec_procedure(Src, 'Classify', [5], R1),
    check('Classify(5)=1 (Low)', R1, 1),
    exec_procedure(Src, 'Classify', [50], R2),
    check('Classify(50)=2 (Medium)', R2, 2),
    exec_procedure(Src, 'Classify', [150], R3),
    check('Classify(150)=3 (High)', R3, 3).

test_statslib_exec :-
    read_file_to_string('../../../clarion_projects/stats-calc/StatsLib.clw', Src, []),
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
% Storage Backend Tests
%------------------------------------------------------------

test_storage_backend_selection :-
    format("~nStorage backend selection tests:~n"),
    get_backend('TOPSPEED', B1), check('TOPSPEED -> memory', B1, memory),
    get_backend('DOS', B2), check('DOS -> memory', B2, memory),
    get_backend('ASCII', B3), check('ASCII -> csv', B3, csv),
    get_backend('BASIC', B4), check('BASIC -> csv', B4, csv),
    get_backend('ODBC', B5), check('ODBC -> odbc', B5, odbc),
    get_backend('ADO', B6), check('ADO -> odbc', B6, odbc).

test_storage_memory_lifecycle :-
    format("~nStorage memory lifecycle tests:~n"),
    Fields = [field('ID', 'LONG', 4), field('Value', 'LONG', 4)],
    Keys = [key('IDKey', ['ID'])],
    FS0 = file_state(sensors, 'S', Keys, Fields, [], [0, 0], -1, false),
    % Open
    storage_memory::open(FS0, FS1),
    FS1 = file_state(_, _, _, _, _, _, _, IsOpen1),
    check('mem_open sets open', IsOpen1, true),
    % Clear buffer and set values for add
    storage_memory::clear(FS1, FS2),
    FS2 = file_state(N2, Pre2, K2, F2, R2, _, P2, O2),
    FSWithData = file_state(N2, Pre2, K2, F2, R2, [1, 100], P2, O2),
    % Add a record
    storage_memory::add(FSWithData, FS3),
    storage_memory::records(FS3, Count1),
    check('mem_add 1 record', Count1, 1),
    % Add a second record
    FS3 = file_state(N3, Pre3, K3, F3, R3, _, _, O3),
    FSWithData2 = file_state(N3, Pre3, K3, F3, R3, [2, 200], -1, O3),
    storage_memory::add(FSWithData2, FS4),
    storage_memory::records(FS4, Count2),
    check('mem_add 2 records', Count2, 2),
    % SET resets position
    storage_memory::set(FS4, FS5),
    FS5 = file_state(_, _, _, _, _, _, Pos5, _),
    check('mem_set resets pos', Pos5, -1),
    % NEXT advances
    storage_memory::next(FS5, FS6),
    FS6 = file_state(_, _, _, _, _, Buf6, Pos6, _),
    check('mem_next pos 0', Pos6, 0),
    check('mem_next buf', Buf6, [1, 100]),
    % GET by key
    storage_memory::get(key_search('IDKey', ['ID'], [2]), FS4, FS7),
    FS7 = file_state(_, _, _, _, _, Buf7, Pos7, _),
    check('mem_get finds key=2', Buf7, [2, 200]),
    check('mem_get pos=1', Pos7, 1),
    % PUT updates record at position
    FS4 = file_state(N4, Pre4, K4, F4, R4, _, _, O4),
    FSForPut = file_state(N4, Pre4, K4, F4, R4, [2, 999], 1, O4),
    storage_memory::put(FSForPut, FS8),
    storage_memory::get(key_search('IDKey', ['ID'], [2]), FS8, FS9),
    FS9 = file_state(_, _, _, _, _, Buf9, _, _),
    check('mem_put updated', Buf9, [2, 999]),
    % DELETE
    storage_memory::delete(FS9, FS10),
    storage_memory::records(FS10, Count3),
    check('mem_delete removes 1', Count3, 1),
    % EMPTY clears all
    storage_memory::empty(FS10, FS11),
    storage_memory::records(FS11, Count4),
    check('mem_empty clears all', Count4, 0),
    % Close
    storage_memory::close(FS11, FS12),
    FS12 = file_state(_, _, _, _, _, _, _, IsOpen12),
    check('mem_close sets closed', IsOpen12, false).

test_storage_dispatch :-
    format("~nStorage dispatch tests:~n"),
    Fields = [field('X', 'LONG', 4)],
    Keys = [key('XKey', ['X'])],
    FS0 = file_state(test, 'T', Keys, Fields, [], [0], -1, false),
    % Dispatch through storage_backend with memory driver
    storage_open('TOPSPEED', test, FS0, FS1),
    FS1 = file_state(_, _, _, _, _, _, _, O1),
    check('storage_open dispatch', O1, true),
    FS1 = file_state(N1, Pre1, K1, F1, R1, _, P1, O1b),
    FSAdd = file_state(N1, Pre1, K1, F1, R1, [42], P1, O1b),
    storage_add('TOPSPEED', FSAdd, FS2),
    storage_records('TOPSPEED', FS2, C1),
    check('storage_add dispatch', C1, 1),
    storage_close('TOPSPEED', FS2, FS3),
    FS3 = file_state(_, _, _, _, _, _, _, O3),
    check('storage_close dispatch', O3, false).

%------------------------------------------------------------
% UI Backend Tests
%------------------------------------------------------------

test_ui_init_shutdown :-
    format("~nUI backend tests:~n"),
    empty_state(S0),
    % Init
    ui_init(simulation, S0, S1),
    ui_get_backend(S1, B1),
    check('ui_init backend', B1, simulation),
    % Shutdown
    ui_shutdown(S1, S2),
    ui_get_backend(S2, B2),
    check('ui_shutdown preserves backend', B2, simulation).

test_ui_window_ops :-
    format("~nUI window operation tests:~n"),
    empty_state(S0),
    ui_init(simulation, S0, S1),
    % Open window with controls
    Controls = [
        control(entry, '@n3', [use(control_ref(sensorID))]),
        control(entry, '@n6', [use(control_ref(reading))]),
        control(button, '&Calculate', [use(control_ref(calcBtn))])
    ],
    WindowDef = window('TestWindow', 'Test Form', Controls),
    ui_open_window(WindowDef, S1, S2, R1),
    check('ui_open_window ok', R1, ok),
    % Get control value (default empty)
    ui_get_control_value(sensorID, S2, Val1, R2),
    check('ui_get_control default', Val1, ''),
    check('ui_get_control ok', R2, ok),
    % Set control value
    ui_set_control_value(sensorID, 42, S2, S3, R3),
    check('ui_set_control ok', R3, ok),
    ui_get_control_value(sensorID, S3, Val2, _),
    check('ui_get_control after set', Val2, 42),
    % Select (focus)
    ui_select(reading, S3, S4, R4),
    check('ui_select ok', R4, ok),
    % Set control property
    ui_set_control_prop(sensorID, color, red, S4, S5, R5),
    check('ui_set_control_prop ok', R5, ok),
    % Display (no-op)
    ui_display(S5, S6, R6),
    check('ui_display ok', R6, ok),
    % Close window
    ui_close_window(S6, _, R7),
    check('ui_close_window ok', R7, ok).

test_ui_event_queue :-
    format("~nUI event queue tests:~n"),
    empty_state(S0),
    ui_init(simulation, S0, S1),
    % Initially no events
    ui_has_events(S1, HasE1),
    check('no events initially', HasE1, false),
    % Push events
    ui_push_event(set('SensorID', 5), S1, S2, _),
    ui_push_event(1, S2, S3, _),
    ui_has_events(S3, HasE2),
    check('has events after push', HasE2, true),
    % Poll events (FIFO)
    ui_poll_event(S3, S4, Evt1),
    check('poll first event', Evt1, set('SensorID', 5)),
    ui_poll_event(S4, S5, Evt2),
    check('poll second event', Evt2, 1),
    % Queue empty now
    ui_poll_event(S5, _, Evt3),
    check('poll empty returns none', Evt3, none),
    ui_has_events(S5, HasE3),
    check('no events after drain', HasE3, false).

test_ui_mode_control :-
    format("~nUI mode control tests:~n"),
    empty_state(S0),
    ui_init(simulation, S0, S1),
    % Default mode
    ui_get_mode(S1, Mode1),
    check('default mode sync', Mode1, sync),
    % Set async
    ui_set_mode(async, S1, S2, R1),
    check('set_mode async ok', R1, ok),
    ui_get_mode(S2, Mode2),
    check('mode now async', Mode2, async),
    % Invalid mode
    ui_set_mode(invalid, S2, _, R2),
    check('invalid mode error', R2, error(invalid_mode)).

test_ui_current_event :-
    format("~nUI current event tests:~n"),
    empty_state(S0),
    ui_init(simulation, S0, S1),
    % Default current event
    ui_get_current_event(S1, CE1),
    check('default current event', CE1, none),
    % Set current event
    ui_set_current_event(42, S1, S2, R1),
    check('set current event ok', R1, ok),
    ui_get_current_event(S2, CE2),
    check('current event is 42', CE2, 42).

test_ui_close_no_window :-
    format("~nUI close no window test:~n"),
    empty_state(S0),
    ui_init(simulation, S0, S1),
    ui_close_window(S1, _, R1),
    check('close no window error', R1, error(no_window)).

%------------------------------------------------------------
% Qualified Names / Nested Groups
%------------------------------------------------------------

test_parse_qualnames :-
    read_file_to_string('../../../clarion_projects/qualified-names/QualNames.clw', Src, []),
    ( parse_clarion(Src, _AST) ->
        check('Parse QualNames.clw', ok, ok)
    ;   check('Parse QualNames.clw', failed, ok)
    ).

test_nested_group_in_file :-
    % FILE with nested GROUP,PRE(SB) inside RECORD
    Src = "  MEMBER()\nDF FILE,DRIVER('DOS'),PRE(DF)\nRec  RECORD\nX      LONG\nSub    GROUP,PRE(SB)\nY        LONG\nZ        LONG\n       END\n     END\n   END\n  MAP\n    TestNG(),LONG\n  END\nTestNG PROCEDURE()\n  CODE\n  SB:Y = 10\n  SB:Z = 20\n  RETURN(SB:Y + SB:Z)\n",
    exec_procedure(Src, 'TestNG', [], R),
    check('Nested GROUP in FILE (SB:Y + SB:Z)', R, 30).

test_nested_group_in_group :-
    % Top-level GROUP with nested GROUP inside
    Src = "  MEMBER()\nOuter GROUP,PRE(OT)\nInner   GROUP,PRE(IN)\nVal       LONG\n        END\nFlag    LONG\n      END\n  MAP\n    TestGG(),LONG\n  END\nTestGG PROCEDURE()\n  CODE\n  IN:Val = 77\n  OT:Flag = 33\n  RETURN(IN:Val + OT:Flag)\n",
    exec_procedure(Src, 'TestGG', [], R),
    check('Nested GROUP in GROUP (IN:Val + OT:Flag)', R, 110).

test_qualnames_full :-
    % Full QualNames project: FILE with nested GROUP + top-level nested GROUP
    read_file_to_string('../../../clarion_projects/qualified-names/QualNames.clw', Src, []),
    init_session(Src, S0),
    call_procedure(S0, 'InitDose', [], R0, S1),
    check('QN InitDose()', R0, 0),
    call_procedure(S1, 'SetDisplay', [42, 3], R1, S2),
    check('QN SetDisplay(42,3)', R1, 0),
    call_procedure(S2, 'GetDisplaySize', [], R2, S3),
    check('QN GetDisplaySize()', R2, 42),
    call_procedure(S3, 'GetDisplayScale', [], R3, S4),
    check('QN GetDisplayScale()', R3, 3),
    call_procedure(S4, 'CalcTotal', [], R4, S5),
    check('QN CalcTotal() = 42*3', R4, 126),
    call_procedure(S5, 'SetPlan', [5, 200], R5, S6),
    check('QN SetPlan(5,200)', R5, 0),
    call_procedure(S6, 'GetBeamCount', [], R6, S7),
    check('QN GetBeamCount()', R6, 5),
    call_procedure(S7, 'GetEnergy', [], R7, S8),
    check('QN GetEnergy()', R7, 200),
    call_procedure(S8, 'CalcDoseProduct', [], R8, _),
    check('QN CalcDoseProduct() = 5*200+0', R8, 1000).

test_double_colon_parse :-
    % Identifiers with :: (scope resolution) should parse correctly
    Src = "  MEMBER()\nSAV GROUP,PRE(SAV)\nITM   GROUP,PRE(ITM)\nRecord  LONG\n      END\n    END\n  MAP\n    TestDC(),LONG\n  END\nTestDC PROCEDURE()\n  CODE\n  ITM:Record = 42\n  RETURN(ITM:Record)\n",
    exec_procedure(Src, 'TestDC', [], R),
    check('Double-colon style nested group', R, 42).

%------------------------------------------------------------
% Phase 1: EQUATE, float literals, ADDRESS
%------------------------------------------------------------

test_equate_parse :-
    format("~nEQUATE + Float tests:~n"),
    Src = "  MEMBER()\nMAX_SIZE EQUATE(640)\nMIN_VAL EQUATE(0)\n  MAP\n    GetMax(),LONG,C,NAME('GetMax'),EXPORT\n  END\nGetMax PROCEDURE()\n  CODE\n  RETURN(MAX_SIZE)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, ModAST),
    ModAST = program(_, GlobalDecls, _, _),
    % EQUATE should appear as a var with init value
    member(var('MAX_SIZE', 'LONG', init(640)), GlobalDecls),
    check('EQUATE parsed as global var', ok, ok).

test_equate_exec :-
    Src = "  MEMBER()\nMAX_SIZE EQUATE(640)\nMIN_VAL EQUATE(0)\n  MAP\n    GetMax(),LONG,C,NAME('GetMax'),EXPORT\n    GetMin(),LONG,C,NAME('GetMin'),EXPORT\n  END\nGetMax PROCEDURE()\n  CODE\n  RETURN(MAX_SIZE)\nGetMin PROCEDURE()\n  CODE\n  RETURN(MIN_VAL)\n",
    init_session(Src, S0),
    call_procedure(S0, 'GetMax', [], R1, S1),
    check('EQUATE GetMax()=640', R1, 640),
    call_procedure(S1, 'GetMin', [], R2, _),
    check('EQUATE GetMin()=0', R2, 0).

test_float_literal_parse :-
    Src = "  MEMBER()\nSCALE REAL(10000.0)\n  MAP\n    GetScale(),REAL,C,NAME('GetScale'),EXPORT\n  END\nGetScale PROCEDURE()\n  CODE\n  RETURN(SCALE)\n",
    parse_clarion(Src, SimpleAST),
    bridge_ast(SimpleAST, _ModAST),
    check('Float literal 10000.0 parsed', ok, ok).

test_float_literal_exec :-
    Src = "  MEMBER()\n  MAP\n    CalcHalf(LONG x),REAL,C,NAME('CalcHalf'),EXPORT\n  END\nCalcHalf PROCEDURE(LONG x)\nresult REAL(0.0)\n  CODE\n  result = x * 0.5\n  RETURN(result)\n",
    exec_procedure(Src, 'CalcHalf', [100], R),
    check('Float 100*0.5=50.0', R, 50.0).

test_address_unique :-
    format("~nADDRESS tests:~n"),
    Src = "  MEMBER()\nA LONG(0)\nB LONG(0)\n  MAP\n    GetAddrA(),LONG,C,NAME('GetAddrA'),EXPORT\n    GetAddrB(),LONG,C,NAME('GetAddrB'),EXPORT\n  END\nGetAddrA PROCEDURE()\n  CODE\n  RETURN(ADDRESS(A))\nGetAddrB PROCEDURE()\n  CODE\n  RETURN(ADDRESS(B))\n",
    init_session(Src, S0),
    call_procedure(S0, 'GetAddrA', [], AddrA, S1),
    call_procedure(S1, 'GetAddrB', [], AddrB, _),
    ( AddrA > 0 -> APos = yes ; APos = no ),
    check('ADDRESS(A) > 0', APos, yes),
    ( AddrB > 0 -> BPos = yes ; BPos = no ),
    check('ADDRESS(B) > 0', BPos, yes),
    ( AddrA \= AddrB -> Diff = yes ; Diff = no ),
    check('ADDRESS(A) \\= ADDRESS(B)', Diff, yes).

test_memcopy_noop :-
    % MemCopy should not crash — it's a no-op in the simulator
    Src = "  MEMBER()\nBuf GROUP,PRE(BF)\nX LONG\nY LONG\n  END\n  MAP\n    MODULE('kernel32')\n      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')\n    END\n    TestMC(),LONG,C,NAME('TestMC'),EXPORT\n  END\nTestMC PROCEDURE()\n  CODE\n  BF:X = 42\n  BF:Y = 99\n  RETURN(BF:X + BF:Y)\n",
    exec_procedure(Src, 'TestMC', [], R),
    check('MemCopy module parsed + exec', R, 141).


%------------------------------------------------------------
% Parse gaps (COMPILE/OMIT, LIKE, string EQUATE,
% STRING('x'), omitted first arg, OROF, A[i].Field)
%------------------------------------------------------------

compile_src("  MEMBER()\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nF PROCEDURE()\nX LONG(1)\n  CODE\n  COMPILE('__ENDCOV__', HasCov = 1)\n  X = 99\n__ENDCOV__\n  OMIT('**OFF**', HasCov = 0)\n  X = X + 1000\n  !**OFF**\n  COMPILE('***')\n  X = X + 10\n  ! ***\n  RETURN(X)\n").

test_compile_omit :-
    format("~nCOMPILE/OMIT tests:~n"),
    compile_src(Src),
    exec_procedure(Src, 'F', [], R0),
    check('COMPILE false / OMIT true / COMPILE no-expr (defines [])', R0, 11),
    parse_clarion(Src, AST1, [defines(['HasCov'=1])]),
    bridge_ast(AST1, Mod1),
    Mod1 = program(_, _, _, [procedure('F', _, _, code(Body1))]),
    ( Body1 = [assign('X', number(99)), assign('X', binop('+', var('X'), number(1000))),
               assign('X', binop('+', var('X'), number(10))), return(_)]
    -> B1 = ok ; B1 = Body1 ),
    check('COMPILE true / OMIT false with defines([HasCov=1])', B1, ok),
    string_codes(Src, Codes), clarion_preproc:preprocess_codes(Codes, [], Out),
    include(==(0'\n), Codes, N1), include(==(0'\n), Out, N2),
    length(N1, L1), length(N2, L2),
    check('preprocessor preserves line count', L2, L1).

test_like_decl :-
    format("~nLIKE tests:~n"),
    Src = "  MEMBER()\nRec GROUP,PRE(REC)\nId LONG\n  END\nCopy:Record LIKE(Rec),PRE(CPY)\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nF PROCEDURE()\nA LONG\nB LIKE(A)\nR LIKE(REC:Id),PRE(RR)\n  CODE\n  B = 5\n  RETURN(B + 1)\n",
    parse_clarion(Src, program(_, _, Globals, _, [procedure('F', _, _, Locals, _)])),
    ( member(global('Copy:Record', like('Rec', [pre('CPY')]), 0), Globals) -> G = ok ; G = Globals ),
    check('global LIKE(Rec),PRE(CPY) parsed', G, ok),
    ( Locals = [local('A', long, 0), like('B', 'A', []), like('R', 'REC:Id', [pre('RR')])] -> L = ok ; L = Locals ),
    check('local LIKE / LIKE,PRE parsed', L, ok),
    exec_procedure(Src, 'F', [], R),
    check('LIKE local exec B=5 -> 6', R, 6),
    QSrc = "  MEMBER()\nQ QUEUE\nId LIKE(X:Id)\nName STRING('abc')\n  END\n",
    parse_clarion(QSrc, program(_, _, QG, _, _)),
    ( QG = [queue('Q', [field('Id', like('X:Id', [])), field('Name', string(3))])] -> QOk = ok ; QOk = QG ),
    check('LIKE and STRING(init) fields in QUEUE', QOk, ok).

test_string_equate :-
    format("~nEQUATE string / :: tests:~n"),
    Src = "  MEMBER('X.clw')\nNT::THIS_MODULE   Equate('Some_Db.clw(APP.app)')\nA::B EQUATE(7)\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nF PROCEDURE()\n  CODE\n  RETURN(A::B)\n",
    parse_clarion(Src, program(_, _, Globals, _, _)),
    ( Globals = [equate('NT::THIS_MODULE', 'Some_Db.clw(APP.app)'), equate('A::B', 7)] -> G = ok ; G = Globals ),
    check('EQUATE(string) and :: names parsed', G, ok),
    exec_procedure(Src, 'F', [], R),
    check('A::B EQUATE(7) exec', R, 7).

test_string_init :-
    format("~nSTRING('init') tests:~n"),
    Src = "  MEMBER()\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nF PROCEDURE()\nS STRING('abcd')\n  CODE\n  RETURN(LEN(S))\n",
    parse_clarion(Src, program(_, _, _, _, [procedure('F', _, _, Locals, _)])),
    check('STRING(init) local parsed', Locals, [local('S', string(4), abcd)]),
    exec_procedure(Src, 'F', [], R),
    check('LEN(STRING(abcd)) = 4', R, 4).

test_omitted_first_arg :-
    format("~nOmitted argument tests:~n"),
    Src = "  MEMBER()\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nG PROCEDURE(<LONG a>, LONG b)\n  CODE\n  RETURN(a + b)\nF PROCEDURE()\n  CODE\n  RETURN(G(, 5) + G(1, 2))\n",
    parse_clarion(Src, program(_, _, _, _, Procs)),
    ( member(procedure('F', _, _, _, [return(add(call('G', [omitted, lit(5)]), _))]), Procs) -> P = ok ; P = Procs ),
    check('f(, a) parsed with omitted', P, ok),
    exec_procedure(Src, 'F', [], R),
    check('G(, 5) + G(1, 2) = 8', R, 8).

test_orof :-
    format("~nOROF tests:~n"),
    Src = "  MEMBER()\n  MAP\n    C(LONG x),LONG,C,NAME('C'),EXPORT\n  END\nC PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  case x\n  of 1\n  orof 2\n    R = 10\n  of 3\n    R = 30\n  else\n    R = -1\n  .\n  RETURN(R)\n",
    parse_clarion(Src, program(_, _, _, _, [procedure('C', _, _, _, [case(_, Ofs, _)|_])])),
    ( Ofs = [of(any([single(lit(1)), single(lit(2))]), _), of(single(lit(3)), _)] -> P = ok ; P = Ofs ),
    check('OF 1 OROF 2 parsed as any/1', P, ok),
    init_session(Src, S0),
    call_procedure(S0, 'C', [1], R1, _), check('OROF: C(1) = 10', R1, 10),
    call_procedure(S0, 'C', [2], R2, _), check('OROF: C(2) = 10', R2, 10),
    call_procedure(S0, 'C', [3], R3, _), check('OROF: C(3) = 30', R3, 30),
    call_procedure(S0, 'C', [4], R4, _), check('OROF: C(4) = -1', R4, -1).

test_array_field :-
    format("~nArray element field tests:~n"),
    Src = "  MEMBER()\nF PROCEDURE()\nI LONG(1)\nX LONG\n  CODE\n  if ITM:Fx[I].WaveIdx > X\n    X = ITM:Fx[I].WaveIdx\n  .\n  ITM:Fx[I].WaveIdx = 3\n",
    parse_clarion(Src, program(_, _, _, _, [procedure('F', _, _, _, Body)])),
    ( Body = [if(gt(array_field('ITM:Fx', var('I'), 'WaveIdx'), var('X')),
                 [assign('X', array_field('ITM:Fx', var('I'), 'WaveIdx'))], []),
              assign(array_field('ITM:Fx', var('I'), 'WaveIdx'), lit(3))] -> P = ok ; P = Body ),
    check('A[i].Field read and assign parsed', P, ok),
    bridge_ast(program([], [], [], [], [procedure('F', [], void, [], Body)]),
               program(_, _, _, [procedure('F', _, _, code(BB))])),
    ( BB = [if(binop('>', array_field_access('ITM:Fx', var('I'), 'WaveIdx'), var('X')), _, [], []),
            array_field_assign('ITM:Fx', var('I'), 'WaveIdx', number(3))] -> B = ok ; B = BB ),
    check('A[i].Field bridged', B, ok).


test_local_queue_group :-
    format("~nLocal QUEUE/GROUP tests:~n"),
    Src = "  MEMBER()\n  MAP\n    F(),LONG,C,NAME('F'),EXPORT\n  END\nF PROCEDURE()\nMsgQ QUEUE\nText STRING(200)\n  .\nCur GROUP,PRE(CUR)\nId LONG\nName STRING(20)\n  .\nT LONG\n  CODE\n  CUR:Id = 41\n  MsgQ.Text = 'hello'\n  ADD(MsgQ)\n  T = CUR:Id + RECORDS(MsgQ)\n  RETURN(T)\n",
    parse_clarion(Src, AST),
    bridge_ast(AST, program(_, _, _, [procedure('F', _, Locals, _)])),
    ( Locals = [local_decl(queue('MsgQ', _)), local_decl(group('Cur', 'CUR', _)), local_var('T', 'LONG', _)]
    -> L = ok ; L = Locals ),
    check('local QUEUE/GROUP bridged as local_decl', L, ok),
    exec_procedure(Src, 'F', [], R),
    check('local GROUP field + local QUEUE ADD/RECORDS = 42', R, 42).

test_not_call :-
    format("~nNOT with calls tests:~n"),
    Src = "  MEMBER()\n  MAP\n    F(LONG x),LONG,C,NAME('F'),EXPORT\n  END\nIsBig PROCEDURE(LONG v)\n  CODE\n  RETURN(v > 10)\nF PROCEDURE(LONG x)\nR LONG(0)\n  CODE\n  if ~IsBig(x)\n    R = 1\n  .\n  if NOT IsBig(x) and ~(x = 3)\n    R = R + 10\n  .\n  RETURN(R)\n",
    parse_clarion(Src, AST),
    bridge_ast(AST, program(_, _, _, Procs)),
    ( member(procedure('F', _, _, code([if(not(call('IsBig', [var(x)])), _, _, _)|_])), Procs)
    -> B = ok ; B = Procs ),
    check('~call bridged recursively', B, ok),
    init_session(Src, S0),
    call_procedure(S0, 'F', [5], R1, _), check('~IsBig(5) and NOT IsBig(5) and ~(5=3) -> 11', R1, 11),
    call_procedure(S0, 'F', [3], R2, _), check('x=3 -> 1', R2, 1),
    call_procedure(S0, 'F', [50], R3, _), check('~IsBig(50) false -> 0', R3, 0).

test_implicit_long :-
    format("~nImplicit # variable tests:~n"),
    % DoUpdate:Item save/restore pattern: SAV:ITM:EDIT_DATE# holds the field
    % while it is overwritten, then restores it.  The ITM prefix matches a
    % real GROUP, so ITM:Tmp# must stay a plain variable, not a group field.
    Src = "  MEMBER()\nItemRec GROUP,PRE(ITM)\nEDIT_DATE LONG\nOther LONG\n  END\n  MAP\n    Upd(LONG m),LONG,C,NAME('Upd'),EXPORT\n    Trunc(),LONG,C,NAME('Trunc'),EXPORT\n    Unset(),LONG,C,NAME('Unset'),EXPORT\n  END\nUpd PROCEDURE(LONG m)\n  CODE\n  ITM:EDIT_DATE = 77000\n  if m\n    SAV:ITM:EDIT_DATE# = ITM:EDIT_DATE\n    ITM:EDIT_DATE = 0\n  .\n  ITM:Other = ITM:EDIT_DATE\n  if m\n    ITM:EDIT_DATE = SAV:ITM:EDIT_DATE#\n  .\n  ITM:Tmp# = 5\n  RETURN(ITM:EDIT_DATE + ITM:Other + ITM:Tmp#)\nTrunc PROCEDURE\n  CODE\n  t# = 79 / 10\n  t# = t# + 2.9\n  RETURN(t#)\nUnset PROCEDURE\n  CODE\n  RETURN(never_set# + 1)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs0),
    ( member(procedure('Upd', _, _, _, Body), Procs0),
      sub_term(assign('SAV:ITM:EDIT_DATE#', _), Body)
    -> P = ok ; P = missing ),
    check('SAV:ITM:EDIT_DATE# parsed as one name', P, ok),
    init_session(Src, S0),
    call_procedure(S0, 'Upd', [1], R1, _),
    check('save/restore via implicit #: 77000 + 0 + 5', R1, 77005),
    call_procedure(S0, 'Upd', [0], R2, _),
    check('no save: 77000 + 77000 + 5', R2, 154005),
    call_procedure(S0, 'Trunc', [], R3, _),
    check('implicit # truncates reals: 7 + 2.9 -> 9', R3, 9),
    call_procedure(S0, 'Unset', [], R4, _),
    check('unassigned implicit # reads 0', R4, 1).

test_ref_assign :-
    format("~nReference assignment (&=) tests:~n"),
    Src = "  MEMBER()\nSomeClass CLASS,TYPE\nV LONG\n  END\n  MAP\n    R(LONG x),LONG,C,NAME('R'),EXPORT\n  END\nR PROCEDURE(LONG x)\nobjA     &SomeClass\nCopy     &LONG\nNothing  &SomeClass\n  CODE\n  Copy &= x\n  Nothing &= NULL\n  if Nothing &= NULL\n    Copy += 100\n  .\n  if objA &= NULL\n    Copy += 1000\n  .\n  objA &= NEW(SomeClass)\n  if objA &= NULL\n    Copy += 5000\n  .\n  RETURN(Copy + 1)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    member(procedure('R', _, _, Locals, Body), Procs),
    ( Locals = [ref_var(objA, 'SomeClass'), ref_var('Copy', 'LONG'), ref_var('Nothing', 'SomeClass')]
    -> L = ok ; L = Locals ),
    check('&Type locals parsed as ref_var', L, ok),
    ( Body = [ref_assign('Copy', var(x)), ref_assign('Nothing', null)|_] -> B = ok ; B = Body ),
    check('Copy &= x / Nothing &= NULL parsed', B, ok),
    init_session(Src, S0),
    call_procedure(S0, 'R', [41], R1, _),
    check('&= copy + NULL tests (41 + 100 + 1000 + 1)', R1, 1142),
    % NEW(Class) and a call on the right-hand side bridge distinctly
    parse_clarion("  MEMBER()\n  MAP\n  END\nP PROCEDURE\nobjLog &LogClass\n  CODE\n  objLog &= new(LogClass)\n  ActiveReg &= Registry:Find()\n  FREF:Image &= Image\n", AST2),
    bridge_ast(AST2, program(_, _, _, [procedure('P', _, _, code(BBody))|_])),
    ( BBody = [ref_assign(objLog, new('LogClass')),
               ref_assign('ActiveReg', expr(call(_, []))),
               ref_assign('FREF:Image', name('Image'))]
    -> NB = ok ; NB = BBody ),
    check('&= NEW / call / name bridged', NB, ok).

test_keyword_table_names :-
    format("~nKeyword table-name argument tests:~n"),
    Src = "  MEMBER()\n  MAP\n  END\nP PROCEDURE\n  CODE\n  add(Prompt)\n  PUT(Prompt)\n  delete(Prompt)\n  add(Queue)\n  if ~Lookup(Queue,Que:By_Que_Id,QUE:Record)\n    x = 1\n  .\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, [procedure('P', _, _, _, Body)]),
    ( Body = [call(add, [var('Prompt')]), call('PUT', [var('Prompt')]),
              call('DELETE', [var('Prompt')]), call(add, [var('Queue')]),
              if(not(call('Lookup', [var('Queue')|_])), _, _)]
    -> B = ok ; B = Body ),
    check('Prompt/Queue accepted as whole arguments', B, ok),
    % ...but a keyword is still a keyword elsewhere
    ( parse_clarion("  MEMBER()\n  MAP\n  END\nP PROCEDURE\n  CODE\n  x = Queue + 1\n", _) -> K = parsed ; K = rejected ),
    check('keyword inside an expression still rejected', K, rejected).

test_file_ref_param :-
    format("~nFILE reference parameter (*FILE) tests:~n"),
    % A dispatcher of the form: case address(P:File) / of address(F) / call F's handler
    Src = "  MEMBER()\nItem FILE,DRIVER('DOS'),PRE(ITM)\nRecord RECORD\nITM_ID LONG\n  END\n  END\nPart FILE,DRIVER('DOS'),PRE(PRT)\nRecord RECORD\nFLD_ID LONG\n  END\n  END\n  MAP\n    Run(LONG which),LONG,C,NAME('Run'),EXPORT\n  END\nDoAdd PROCEDURE(*file P:File, <long O:OptionsMask>)\nFREF:Image &file\n  CODE\n  FREF:Image &= Item\n  case address(P:File)\n  of address(Item)\n    return(DoAdd:Item(O:OptionsMask))\n  of address(Part)\n    return(DoAdd:Part(O:OptionsMask))\n  .\n  return(-1)\nDoAdd:Item PROCEDURE(<long O:OptionsMask>)\n  CODE\n  return(11 + O:OptionsMask)\nDoAdd:Part PROCEDURE(<long O:OptionsMask>)\n  CODE\n  return(22 + O:OptionsMask)\nPassOn PROCEDURE(*file F)\n  CODE\n  return(DoAdd(F, 100))\nAddVia PROCEDURE(*file F)\n  CODE\n  add(F)\nRun PROCEDURE(LONG which)\n  CODE\n  open(Item)\n  open(Part)\n  case which\n  of 1\n    return(DoAdd(Item))\n  of 2\n    return(DoAdd(Part, 5))\n  of 3\n    return(PassOn(Part))\n  of 4\n    ITM:ITM_ID = 7\n    AddVia(Item)\n    AddVia(Item)\n    return(records(Item))\n  .\n  return(0)\n",
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    ( member(procedure('DoAdd', [param('P:File', ref(file)), _], _, _, _), Procs) -> P = ok ; P = missing ),
    check('*file P:File parsed as ref(file)', P, ok),
    init_session(Src, S0),
    call_procedure(S0, 'Run', [1], R1, _), check('DoAdd(Item) dispatches to DoAdd:Item', R1, 11),
    call_procedure(S0, 'Run', [2], R2, _), check('DoAdd(Part, 5) dispatches to DoAdd:Part', R2, 27),
    call_procedure(S0, 'Run', [3], R3, _), check('*file passed on through a second *file param', R3, 122),
    call_procedure(S0, 'Run', [4], R4, _), check('ADD(F) through *file param adds to Item', R4, 2).

test_expr_call_state :-
    format("~nProcedure calls inside expressions keep their effects:~n"),
    Src = "  MEMBER()\nItem FILE,DRIVER('DOS'),PRE(ITM)\nRecord RECORD\nITM_ID LONG\n  END\n  END\nCounter LONG(0)\n  MAP\n    Run(LONG which),LONG,C,NAME('Run'),EXPORT\n  END\nAddItem PROCEDURE(LONG id)\n  CODE\n  ITM:ITM_ID = id\n  add(Item)\n  return(errorcode())\nBump PROCEDURE(LONG n)\n  CODE\n  Counter += n\n  return(Counter)\nDoAdd PROCEDURE(*file P:File, <long O:OptionsMask>)\n  CODE\n  case address(P:File)\n  of address(Item)\n    return(DoAdd:Item(O:OptionsMask))\n  .\n  return(-1)\nDoAdd:Item PROCEDURE(<long O:OptionsMask>)\n  CODE\n  add(Item)\n  return(errorcode())\nRun PROCEDURE(LONG which)\n  CODE\n  open(Item)\n  case which\n  of 1\n    x# = AddItem(1)\n    return(records(Item))\n  of 2\n    if AddItem(1) = 0 and AddItem(2) = 0\n      x# = 1\n    .\n    return(records(Item))\n  of 3\n    return(Bump(1) * 100 + Bump(Bump(10)))\n  of 4\n    loop while Bump(1) < 5\n    .\n    return(Counter)\n  of 5\n    ITM:ITM_ID = 9\n    if DoAdd(Item)\n      return(-1)\n    .\n    x# = DoAdd(Item, 0)\n    return(records(Item))\n  .\n  return(0)\n",
    init_session(Src, S0),
    call_procedure(S0, 'Run', [1], R1, _),
    check('x# = AddItem(1) keeps the ADD', R1, 1),
    call_procedure(S0, 'Run', [2], R2, _),
    check('both calls in an IF condition keep their ADDs', R2, 2),
    call_procedure(S0, 'Run', [3], R3, _),
    check('globals thread left to right, incl. nested args: 1*100 + 22', R3, 122),
    call_procedure(S0, 'Run', [4], R4, _),
    check('LOOP WHILE condition call updates the global each pass', R4, 5),
    call_procedure(S0, 'Run', [5], R5, _),
    check('if DoAdd(Item) / x# = DoAdd(Item, 0) both add a record', R5, 2),
    % A method that calls a procedure keeps its SELF context afterwards
    MSrc = "  MEMBER()\nAcc CLASS,TYPE\nTotal LONG\nAddTwice PROCEDURE(LONG n)\nGet PROCEDURE,LONG\n  END\n  MAP\n    TestM(),LONG\n  END\nDouble PROCEDURE(LONG v)\n  CODE\n  return(v * 2)\nTestM PROCEDURE\na Acc\n  CODE\n  a.AddTwice(5)\n  RETURN(a.Get())\nAcc.AddTwice PROCEDURE(LONG n)\n  CODE\n  SELF.Total = Double(n)\n  Double(1)\n  SELF.Total = SELF.Total + Double(n)\nAcc.Get PROCEDURE\n  CODE\n  RETURN SELF.Total\n",
    exec_procedure(MSrc, 'TestM', [], RM),
    check('SELF survives procedure calls inside a method: 10 + 10', RM, 20).

% Clarion names are case-insensitive; keys from a FILE declaration are kept
test_case_insensitive_names :-
    format("~nCase-insensitive names, FILE keys and new builtins:~n"),
    Src = "  MEMBER()\nT FILE,DRIVER('DOS'),PRE(TT),THREAD\nBy_ID KEY(TT:ID),NAME('PK'),PRIMARY\nBy_Code KEY(TT:Code),DUP,NOCASE\nRecord RECORD,PRE()\nID LONG,NAME('ID |NULLABLE')\nCode LONG\nDt GROUP,PRE()\nD DATE\n  END\n  END\n  END\n  MAP\n    Run(LONG which),LONG,C,NAME('Run'),EXPORT\n  END\nRun PROCEDURE(LONG which)\nMyVar LONG(7)\n  CODE\n  open(t)\n  case which\n  of 1\n    return(myvar + MYVAR)\n  of 2\n    MyVAR = 3\n    return(MyVar)\n  of 3\n    tt:id = 5\n    return(TT:ID)\n  of 4\n    TT:ID = 1\n    TT:Code = 9\n    add(T)\n    TT:ID = 2\n    add(T)\n    a# = errorcode()\n    TT:ID = 1\n    add(T)\n    return(a# * 100 + errorcode())\n  of 5\n    return(band(6, 3) * 100 + bor(4, 1) * 10 + TRUE)\n  of 6\n    return(date(1, 1, 1801) * 100000 + date(3, 1, 2000))\n  of 7\n    TT:ID = 1\n    add(T)\n    TT:ID = 2\n    add(T)\n    TT:ID = 1\n    get(T, TT:By_ID)\n    TT:ID = 2\n    put(T)\n    return(errorcode())\n  .\n  return(0)\n",
    init_session(Src, S0),
    call_procedure(S0, 'Run', [1], R1, _), check('myvar / MYVAR read MyVar', R1, 14),
    call_procedure(S0, 'Run', [2], R2, _), check('MyVAR = 3 updates MyVar', R2, 3),
    call_procedure(S0, 'Run', [3], R3, _), check('tt:id writes TT:ID', R3, 5),
    call_procedure(S0, 'Run', [4], R4, _), check('DUP key allows repeats; PRIMARY key gives ERRORCODE 40', R4, 40),
    call_procedure(S0, 'Run', [5], R5, _), check('BAND(6,3)=2, BOR(4,1)=5, TRUE=1', R5, 251),
    call_procedure(S0, 'Run', [6], R6, _), check('DATE(1,1,1801)=4, DATE(3,1,2000)=72747 (days since 28 Dec 1800)', R6, 472747),
    call_procedure(S0, 'Run', [7], R7, _), check('PUT onto another record''s unique key gives 40', R7, 40),
    % ADDRESS was a sum of character codes, so anagram names collided
    ASrc = "  MEMBER()
  MAP
    A(),LONG
  END
A PROCEDURE
Listen LONG
Silent LONG
  CODE
  if address(Listen) = address(Silent) then return(0).
  if address(listen) <> address(Listen) then return(1).
  return(2)
",
    exec_procedure(ASrc, 'A', [], RA),
    check('ADDRESS: anagrams differ, case does not matter', RA, 2),
    % procedure and key names in any case; PRE:Group.Field on a record
    KSrc = "  MEMBER()
T FILE,DRIVER('DOS'),PRE(TT)
By_Item_ID KEY(TT:ID),PRIMARY
Record RECORD
ID LONG
Stamp GROUP
D DATE
  END
  END
  END
  MAP
    Run(),LONG
  END
Helper PROCEDURE(LONG n)
  CODE
  return(n * 2)
Run PROCEDURE
  CODE
  open(T)
  TT:ID = 4
  TT:Stamp.D = 77
  add(T)
  clear(TT:Record)
  tt:id = 4
  get(t, Tt:by_item_id)
  if errorcode() then return(-1).
  return(helper(TT:Stamp.D) + HELPER(1))
",
    exec_procedure(KSrc, 'Run', [], KR),
    check('procedure/key names in any case, PRE:Group.Field: 77*2 + 2', KR, 156).

% Picture tokens, local storage attributes, LIKE(Pre:Group.Field)
test_pictures_local_attrs :-
    format("~nPicture tokens, ,AUTO locals, dotted LIKE:~n"),
    Src = "  MEMBER()\nRec FILE,DRIVER('DOS'),PRE(REC)\nRecord RECORD\nStamp GROUP\nD DATE\n  END\n  END\n  END\n  MAP\n    Run(),LONG\n  END\nRun PROCEDURE\nTxt cstring(64),auto\nN long,auto\nLastD like(REC:Stamp.D)\nArr long,dim(3),auto\n  CODE\n  N = 7\n  Txt = format(N, @n02) & format(N % 5, @P.###P) & format(N, @d01)\n  if N = 7 and len(clip(Txt)) > 0\n    LastD = 12\n  .\n  return(N + LastD)\n",
    ( catch(parse_clarion(Src, AST), _, fail) -> P = ok ; P = failed ),
    check('parses @n02 / @P.###P / @d01, ,auto, like(PRE:G.F)', P, ok),
    ( P == ok, AST = program(_, _, _, _, [procedure('Run', _, _, Locals, _)]),
      memberchk(like('LastD', 'REC:Stamp.D', _), Locals) -> L = ok ; L = missing ),
    check('LIKE keeps the dotted reference', L, ok),
    exec_procedure(Src, 'Run', [], R),
    check('runs: N + LastD', R, 19),
    BSrc = "  MEMBER()
Counter LONG(0)
  MAP
    Run(),LONG
  END
Bump PROCEDURE(LONG n)
  CODE
  Counter += n
  return(Counter)
Run PROCEDURE
  CODE
  x# = abs(Bump(5)) + len(clip(Bump(1)))
  return(Counter * 100 + x#)
",
    exec_procedure(BSrc, 'Run', [], BR),
    check('calls inside builtin args run and keep effects: 6*100 + 5 + 1', BR, 606).

% *T parameters are aliases; *KEY/*GROUP/*?/? params; OMITTED; DISPOSE;
% a parameter or local shadows a global of the same name
test_byref_params :-
    format("~nBy-reference parameters, OMITTED, DISPOSE, shadowing:~n"),
    Src = "  MEMBER()\nRec FILE,DRIVER('DOS'),PRE(REC)\nBy_ID KEY(REC:ID),PRIMARY\nRecord RECORD\nID LONG\nVal LONG\n  END\n  END\nG LONG(5)\nCls CLASS,TYPE\nInit PROCEDURE(LONG n)\n  END\n  MAP\n    Run(LONG which),LONG\n  END\nInc PROCEDURE(*LONG X)\n  CODE\n  X += 1\nFind PROCEDURE(*FILE F, *KEY K, *GROUP R, *? Fld, ? Target, <*? Fld2>, <? Target2>)\n  CODE\n  clear(F)\n  Fld = Target\n  if ~omitted(FLD2)\n    fld2 = Target2\n  .\n  get(F, K)\n  if errorcode()\n    clear(R)\n    return(FALSE)\n  .\n  return(TRUE)\nShadow PROCEDURE(LONG G)\nN LONG\n  CODE\n  G = 99\n  return(G)\nOmit PROCEDURE(<LONG a>, <LONG b>)\n  CODE\n  return(omitted(a) * 10 + omitted(b))\nCls.Init PROCEDURE(LONG n)\n  CODE\nRun PROCEDURE(LONG which)\nL LONG(1)\no &Cls\n  CODE\n  open(Rec)\n  REC:ID = 1\n  REC:Val = 10\n  add(Rec)\n  REC:ID = 2\n  REC:Val = 20\n  add(Rec)\n  case which\n  of 1\n    Inc(L)\n    Inc(L)\n    Inc(REC:Val)\n    return(L * 100 + REC:Val)\n  of 2\n    clear(REC:Record)\n    x# = Find(Rec, REC:By_ID, REC:Record, REC:ID, 2)\n    return(x# * 100 + REC:Val)\n  of 3\n    x# = Find(Rec, REC:By_ID, REC:Record, REC:ID, 7)\n    return(x# * 100 + REC:Val)\n  of 4\n    y# = Shadow(1)\n    return(y# * 100 + G)\n  of 5\n    return(Omit(1) * 100 + Omit(, 2))\n  of 6\n    o &= new(Cls)\n    dispose(o)\n    if o &= NULL then return(1).\n    return(0)\n  of 7\n    Inc(5)\n    return(G)\n  .\n  return(0)\n",
    init_session(Src, S0),
    call_procedure(S0, 'Run', [1], R1, _), check('*LONG param writes the caller variable and a record field', R1, 321),
    call_procedure(S0, 'Run', [2], R2, _), check('*FILE/*KEY/*GROUP/*? lookup finds record 2 (Fld = Target via alias)', R2, 120),
    call_procedure(S0, 'Run', [3], R3, _), check('lookup miss returns FALSE and clears the record via *GROUP', R3, 0),
    call_procedure(S0, 'Run', [4], R4, _), check('a parameter named like a global shadows it', R4, 9905),
    call_procedure(S0, 'Run', [5], R5, _), check('OMITTED: (1) -> 01, (,2) -> 10', R5, 110),
    call_procedure(S0, 'Run', [6], R6, _), check('DISPOSE makes the reference NULL', R6, 1),
    call_procedure(S0, 'Run', [7], R7, _), check('*LONG given a literal is passed by value', R7, 5),
    GSrc = "  MEMBER()
CounterClass CLASS,TYPE
N LONG
Bump PROCEDURE,LONG
  END
Tally CounterClass
  MAP
    Run(),LONG
  END
CounterClass.Bump PROCEDURE
  CODE
  SELF.N += 1
  return(SELF.N)
Run PROCEDURE
  CODE
  Tally.Bump()
  return(Tally.Bump())
",
    exec_procedure(GSrc, 'Run', [], GR),
    check('global object (Name ClassName) keeps its state across calls', GR, 2).

%------------------------------------------------------------
% Main
%------------------------------------------------------------

% A test that throws or fails outright is counted as a failure (previously
% it was skipped silently, which hid the checks after the failing goal).
run_test(Test) :-
    ( catch(Test, E, (format(user_error, "Error in test ~w: ~w~n", [Test, E]), fail))
    -> true
    ;  check(Test, aborted, completed)  % records a FAIL and continues
    ).

%------------------------------------------------------------
% Mermaid Sequence Diagram Tests
%------------------------------------------------------------

test_mermaid_simple_call :-
    format("~nMermaid sequence diagram tests:~n"),
    Src = "  MEMBER()\n  MAP\n    Greet(LONG x),LONG,C,NAME('Greet'),EXPORT\n    Helper(LONG y),LONG,C,NAME('Helper'),EXPORT\n  END\nGreet PROCEDURE(LONG x)\n  CODE\n  RETURN(Helper(x))\nHelper PROCEDURE(LONG y)\n  CODE\n  RETURN(y + 1)\n",
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % Check header present
    ( sub_atom(Mermaid, _, _, _, 'sequenceDiagram') -> HasHeader = true ; HasHeader = false ),
    check('Mermaid has sequenceDiagram header', HasHeader, true),
    % Check participants
    ( sub_atom(Mermaid, _, _, _, 'participant Greet') -> HasGreet = true ; HasGreet = false ),
    check('Mermaid has Greet participant', HasGreet, true),
    ( sub_atom(Mermaid, _, _, _, 'participant Helper') -> HasHelper = true ; HasHelper = false ),
    check('Mermaid has Helper participant', HasHelper, true).

test_mermaid_call_arrow :-
    Src = "  MEMBER()\n  MAP\n    A(LONG x),LONG,C,NAME('A'),EXPORT\n    B(LONG y),LONG,C,NAME('B'),EXPORT\n  END\nA PROCEDURE(LONG x)\nR LONG\n  CODE\n  R = B(x)\n  RETURN(R)\nB PROCEDURE(LONG y)\n  CODE\n  RETURN(y * 2)\n",
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % Check call arrow from A to B
    ( sub_atom(Mermaid, _, _, _, 'A->>B') -> HasCall = true ; HasCall = false ),
    check('Mermaid has A->>B call arrow', HasCall, true),
    % Check return arrow from B to A
    ( sub_atom(Mermaid, _, _, _, 'B-->>A') -> HasRet = true ; HasRet = false ),
    check('Mermaid has B-->>A return arrow', HasRet, true).

test_mermaid_if_alt :-
    Src = "  MEMBER()\n  MAP\n    Check(LONG x),LONG,C,NAME('Check'),EXPORT\n  END\nCheck PROCEDURE(LONG x)\nR LONG\n  CODE\n  IF x > 0\n    R = 1\n  ELSE\n    R = 0\n  END\n  RETURN(R)\n",
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % Check alt fragment
    ( sub_atom(Mermaid, _, _, _, 'alt x > 0') -> HasAlt = true ; HasAlt = false ),
    check('Mermaid has alt fragment for IF', HasAlt, true),
    ( sub_atom(Mermaid, _, _, _, 'else') -> HasElse = true ; HasElse = false ),
    check('Mermaid has else for ELSE branch', HasElse, true).

test_mermaid_loop :-
    Src = "  MEMBER()\n  MAP\n    Count(LONG n),LONG,C,NAME('Count'),EXPORT\n  END\nCount PROCEDURE(LONG n)\nI LONG\nS LONG\n  CODE\n  S = 0\n  LOOP I = 1 TO n\n    S = S + I\n  END\n  RETURN(S)\n",
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % Check loop fragment
    ( sub_atom(Mermaid, _, _, _, 'loop I = 1 TO n') -> HasLoop = true ; HasLoop = false ),
    check('Mermaid has loop fragment for LOOP FOR', HasLoop, true).

test_mermaid_case :-
    Src = "  MEMBER()\n  MAP\n    Grade(LONG s),LONG,C,NAME('Grade'),EXPORT\n  END\nGrade PROCEDURE(LONG s)\nR LONG\n  CODE\n  CASE s\n  OF 1\n    R = 10\n  OF 2\n    R = 20\n  ELSE\n    R = 0\n  END\n  RETURN(R)\n",
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % Check alt for CASE
    ( sub_atom(Mermaid, _, _, _, 'alt s = 1') -> HasCase1 = true ; HasCase1 = false ),
    check('Mermaid has alt for CASE OF 1', HasCase1, true),
    ( sub_atom(Mermaid, _, _, _, 'else s = 2') -> HasCase2 = true ; HasCase2 = false ),
    check('Mermaid has else for CASE OF 2', HasCase2, true).

test_mermaid_real_project :-
    read_file_to_string('../../../clarion_projects/python-dll/MathLib.clw', Src, []),
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    atom_length(Mermaid, Len),
    ( Len > 50 -> HasContent = true ; HasContent = false ),
    check('MathLib Mermaid diagram has content', HasContent, true),
    ( sub_atom(Mermaid, _, _, _, 'sequenceDiagram') -> Ok = true ; Ok = false ),
    check('MathLib Mermaid is valid diagram', Ok, true).

test_mermaid_sensorlib :-
    read_file_to_string('../../../clarion_projects/sensor-data/SensorLib.clw', Src, []),
    parse_clarion(Src, AST),
    ast_to_mermaid(AST, Mermaid),
    % SensorLib has inter-procedure calls (e.g. SSCalculateWeightedAverage uses file ops)
    ( sub_atom(Mermaid, _, _, _, 'participant') -> HasParts = true ; HasParts = false ),
    check('SensorLib Mermaid has participants', HasParts, true),
    ( sub_atom(Mermaid, _, _, _, 'loop') -> HasLoop = true ; HasLoop = false ),
    check('SensorLib Mermaid has loop fragments', HasLoop, true).

test_mermaid_file_output :-
    Src = "  MEMBER()\n  MAP\n    Foo(),LONG,C,NAME('Foo'),EXPORT\n  END\nFoo PROCEDURE()\n  CODE\n  RETURN(42)\n",
    parse_clarion(Src, AST),
    TmpFile = '/tmp/test_mermaid_output.md',
    ast_to_mermaid_file(AST, TmpFile),
    ( exists_file(TmpFile) -> FileOk = true ; FileOk = false ),
    check('Mermaid file output created', FileOk, true),
    ( FileOk = true -> delete_file(TmpFile) ; true ).

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
    run_test(test_odbcstore_sqlite),
    run_test(test_odbc_safety),
    run_test(test_clarion_dates),
    run_test(test_odbc_dates),
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
    % Storage backends
    run_test(test_storage_backend_selection),
    run_test(test_storage_memory_lifecycle),
    run_test(test_storage_dispatch),
    % UI backends
    run_test(test_ui_init_shutdown),
    run_test(test_ui_window_ops),
    run_test(test_ui_event_queue),
    run_test(test_ui_mode_control),
    run_test(test_ui_current_event),
    run_test(test_ui_close_no_window),
    % Qualified names / nested groups
    run_test(test_parse_qualnames),
    run_test(test_nested_group_in_file),
    run_test(test_nested_group_in_group),
    run_test(test_qualnames_full),
    run_test(test_double_colon_parse),
    % Phase 1: EQUATE, float literals, ADDRESS, MemCopy
    run_test(test_equate_parse),
    run_test(test_equate_exec),
    run_test(test_float_literal_parse),
    run_test(test_float_literal_exec),
    run_test(test_address_unique),
    run_test(test_memcopy_noop),
    % Mermaid sequence diagrams
    run_test(test_mermaid_simple_call),
    run_test(test_mermaid_call_arrow),
    run_test(test_mermaid_if_alt),
    run_test(test_mermaid_loop),
    run_test(test_mermaid_case),
    run_test(test_mermaid_real_project),
    run_test(test_mermaid_sensorlib),
    run_test(test_mermaid_file_output),
    % Parse gaps
    run_test(test_compile_omit),
    run_test(test_like_decl),
    run_test(test_string_equate),
    run_test(test_string_init),
    run_test(test_omitted_first_arg),
    run_test(test_orof),
    run_test(test_array_field),
    run_test(test_local_queue_group),
    run_test(test_not_call),
    run_test(test_implicit_long),
    run_test(test_ref_assign),
    run_test(test_keyword_table_names),
    run_test(test_file_ref_param),
    run_test(test_expr_call_state),
    run_test(test_case_insensitive_names),
    run_test(test_pictures_local_attrs),
    run_test(test_byref_params),
    % Summary
    test_count(Total),
    pass_count(Pass),
    fail_count(Fail),
    format("~n=== Results: ~w passed, ~w failed out of ~w ===~n", [Pass, Fail, Total]),
    ( Fail > 0 -> halt(1) ; true ).
