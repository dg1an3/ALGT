% test_interpreter.pl — Tests for clarion_interpreter.pl (AST execution)

:- use_module(clarion_parser).
:- use_module(clarion_interpreter).
:- set_prolog_flag(double_quotes, codes).

%% ==========================================================================
%% MathLib execution tests
%% ==========================================================================

mathlib_source("
  MEMBER()
  MAP
    MathAdd(LONG a, LONG b),LONG,C,NAME('MathAdd'),EXPORT
    Multiply(LONG a, LONG b),LONG,C,NAME('Multiply'),EXPORT
  END

MathAdd PROCEDURE(LONG a, LONG b)
  CODE
  RETURN(a + b)

Multiply PROCEDURE(LONG a, LONG b)
  CODE
  RETURN(a * b)
").

test_mathadd :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    exec_procedure(AST, 'MathAdd', [3, 4], Result),
    format("  MathAdd(3, 4) = ~w", [Result]),
    ( Result =:= 7 -> format(" [PASS]~n") ; format(" [FAIL: expected 7]~n") ).

test_multiply :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    exec_procedure(AST, 'Multiply', [5, 6], Result),
    format("  Multiply(5, 6) = ~w", [Result]),
    ( Result =:= 30 -> format(" [PASS]~n") ; format(" [FAIL: expected 30]~n") ).

test_from_file :-
    read_file_to_codes('../python-dll/MathLib.clw', Codes, []),
    parse_clarion(Codes, AST),
    exec_procedure(AST, 'MathAdd', [10, 20], R1),
    exec_procedure(AST, 'Multiply', [7, 8], R2),
    format("  MathLib.clw MathAdd(10,20)=~w", [R1]),
    ( R1 =:= 30 -> format(" [PASS]~n") ; format(" [FAIL]~n") ),
    format("  MathLib.clw Multiply(7,8)=~w", [R2]),
    ( R2 =:= 56 -> format(" [PASS]~n") ; format(" [FAIL]~n") ).

%% ==========================================================================
%% Control flow tests
%% ==========================================================================

test_if_then_dot :-
    Src = "
  MEMBER()
  MAP
    TestIf(LONG),LONG
  END

TestIf PROCEDURE(LONG val)
  CODE
  IF val = 1 THEN RETURN(10).
  RETURN(20)
",
    parse_clarion(Src, AST),
    format("  IF expr THEN statement ."),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 20 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

test_if_block :-
    Src = "
  MEMBER()
  MAP
    TestIf(LONG),LONG
  END

TestIf PROCEDURE(LONG val)
  CODE
  IF val = 1
    RETURN(10)
  END
  RETURN(20)
",
    parse_clarion(Src, AST),
    format("  IF expr / stmts / END"),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 20 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

test_if_else_block :-
    Src = "
  MEMBER()
  MAP
    TestIf(LONG),LONG
  END

TestIf PROCEDURE(LONG val)
  CODE
  IF val = 1
    RETURN(10)
  ELSE
    RETURN(30)
  END
",
    parse_clarion(Src, AST),
    format("  IF expr / stmts / ELSE / stmts / END"),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 30 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

test_loop_break :-
    Src = "
  MEMBER()
  MAP
    TestLoop(LONG),LONG
  END

TestLoop PROCEDURE(LONG count)
i LONG(0)
  CODE
  LOOP
    IF i = count THEN BREAK.
    i = i + 1
  END
  RETURN(i)
",
    parse_clarion(Src, AST),
    format("  LOOP / stmts / END and BREAK"),
    exec_procedure(AST, 'TestLoop', [5], R1),
    ( R1 =:= 5 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

%% ==========================================================================
%% Expression & assignment tests
%% ==========================================================================

test_qualified_names :-
    Src = "
  MEMBER()
DiagFile FILE,DRIVER('DOS'),PRE(DX)
Record     RECORD
RecordID     LONG
           END
         END
  MAP
    TestQual(),LONG
  END

TestQual PROCEDURE()
  CODE
  DX:RecordID = 100
  RETURN(DX:RecordID)
",
    parse_clarion(Src, AST),
    format("  Qualified names (DX:RecordID)"),
    exec_procedure(AST, 'TestQual', [], R1),
    ( R1 =:= 100 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

test_compound_assign :-
    Src = "
  MEMBER()
  MAP
    TestAdd(LONG),LONG
  END

TestAdd PROCEDURE(LONG val)
i LONG(10)
  CODE
  i += val
  RETURN(i)
",
    parse_clarion(Src, AST),
    format("  Compound assignment (i += val)"),
    exec_procedure(AST, 'TestAdd', [5], R1),
    ( R1 =:= 15 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

%% ==========================================================================
%% Builtin & procedure call tests
%% ==========================================================================

test_procedure_call :-
    Src = "
  MEMBER()
  MAP
    Square(LONG),LONG
    TestCall(LONG),LONG
  END

Square PROCEDURE(LONG n)
  CODE
  RETURN(n * n)

TestCall PROCEDURE(LONG n)
  CODE
  RETURN(Square(n) + 1)
",
    parse_clarion(Src, AST),
    format("  Procedure call (Square(n))"),
    exec_procedure(AST, 'TestCall', [4], R1),
    ( R1 =:= 17 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

test_size_intrinsic :-
    Src = "
  MEMBER()
DiagBuf GROUP,PRE(DB)
RecordID  LONG
PatientID LONG
        END
  MAP
    TestSize(),LONG
  END

TestSize PROCEDURE()
  CODE
  RETURN(SIZE(DiagBuf))
",
    parse_clarion(Src, AST),
    format("  SIZE(DiagBuf)"),
    exec_procedure(AST, 'TestSize', [], R1),
    ( R1 =:= 8 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

%% ==========================================================================
%% Integration tests (file I/O)
%% ==========================================================================

test_diagstore_exec :-
    read_file_to_codes('../diagnosis-store/DiagnosisStore.clw', Codes, []),
    parse_clarion(Codes, AST),
    init_file_io,
    format("  DSOpenStore()"),
    exec_procedure(AST, 'DSOpenStore', [], R1),
    ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ),
    format("  DSCreateDiagnosis(...)"),
    exec_procedure(AST, 'DSCreateDiagnosis', [123, "C34.1", "Lung Cancer", "T2", "N0", "M0", "IIA", 0], R2),
    ( R2 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) ).

test_sensorlib_exec :-
    File = '../sensor-data/SensorLib.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    parse_clarion(Codes, AST),
    init_file_io,

    format("  SSOpen()"),
    exec_procedure(AST, 'SSOpen', [], R0),
    ( R0 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R0=~w]~n", [R0]) ),

    format("  SSAddReading(1, 100, 50)"),
    exec_procedure(AST, 'SSAddReading', [1, 100, 50], R1),
    ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ),

    format("  SSAddReading(2, 200, 25)"),
    exec_procedure(AST, 'SSAddReading', [2, 200, 25], R2),
    ( R2 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) ),

    format("  SSAddReading(3, 300, 10)"),
    exec_procedure(AST, 'SSAddReading', [3, 300, 10], R3),
    ( R3 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R3=~w]~n", [R3]) ),

    format("  SSCalculateWeightedAverage() = 152"),
    exec_procedure(AST, 'SSCalculateWeightedAverage', [], Avg),
    ( Avg =:= 152 -> format(" [PASS]~n") ; format(" [FAIL: Avg=~w]~n", [Avg]) ),

    format("  SSCleanupLowReadings(150) = 1"),
    exec_procedure(AST, 'SSCleanupLowReadings', [150], Removed),
    ( Removed =:= 1 -> format(" [PASS]~n") ; format(" [FAIL: Removed=~w]~n", [Removed]) ),

    format("  SSCalculateWeightedAverage() = 228"),
    exec_procedure(AST, 'SSCalculateWeightedAverage', [], Avg2),
    ( Avg2 =:= 228 -> format(" [PASS]~n") ; format(" [FAIL: Avg2=~w]~n", [Avg2]) ),

    format("  SSClose()"),
    exec_procedure(AST, 'SSClose', [], R4),
    ( R4 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R4=~w]~n", [R4]) ).

test_stats_calc :-
    File = '../stats-calc/StatsLib.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    parse_clarion(Codes, AST),
    format("  CalculateStats(3)"),
    ( exec_procedure(AST, 'CalculateStats', [3], R1) ->
        ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) )
    ; format(" [FAIL: exec CalculateStats]~n")
    ),
    format("  Classify(5) = 1 (Low)"),
    ( exec_procedure(AST, 'Classify', [5], R2) ->
        ( R2 =:= 1 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) )
    ; format(" [FAIL: exec Classify]~n")
    ).

%% ==========================================================================
%% Main
%% ==========================================================================

%% ==========================================================================
%% GUI form simulation tests
%% ==========================================================================

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

test_form_parse :-
    form_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, _, Globals, _, Procs),
    format("  PROGRAM with WINDOW parses"),
    ( length(Globals, 4),  % X, Y, Result, window
      Procs = [procedure('_main', [], void, [], _)]
    -> format(" [PASS]~n")
    ; format(" [FAIL]~n"), format("    globals=~w procs=~w~n", [Globals, Procs])
    ).

test_form_calc :-
    form_source(Src),
    parse_clarion(Src, AST),
    % CalcBtn=1, CloseBtn=2; simulate: press Calc then Close
    exec_program(AST, [1, 2], Result),
    format("  Form calc: 50*30=1500"),
    ( Result =:= 1500 -> format(" [PASS]~n")
    ; format(" [FAIL] got ~w~n", [Result])
    ).

test_form_close_only :-
    form_source(Src),
    parse_clarion(Src, AST),
    % Only press Close — Result stays 0
    exec_program(AST, [2], Result),
    format("  Form close only: Result=0"),
    ( Result =:= 0 -> format(" [PASS]~n")
    ; format(" [FAIL] got ~w~n", [Result])
    ).

test_form_multi_calc :-
    form_source(Src),
    parse_clarion(Src, AST),
    % Press Calc twice then Close — same result since globals don't change
    exec_program(AST, [1, 1, 2], Result),
    format("  Form multi calc: Result=1500"),
    ( Result =:= 1500 -> format(" [PASS]~n")
    ; format(" [FAIL] got ~w~n", [Result])
    ).

test_form_no_events :-
    form_source(Src),
    parse_clarion(Src, AST),
    % No events — accept loop exits immediately, Result stays 0
    exec_program(AST, [], Result),
    format("  Form no events: Result=0"),
    ( Result =:= 0 -> format(" [PASS]~n")
    ; format(" [FAIL] got ~w~n", [Result])
    ).

test_formdemo_parse :-
    File = '../form-demo/FormDemo.clw',
    ( exists_file(File) -> true ; format("  [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    parse_clarion(Codes, AST),
    AST = program(_, _, Globals, _, Procs),
    format("  FormDemo.clw parse"),
    ( length(Globals, 5),  % SensorID, Reading, Weight, Result, window
      Procs = [procedure('_main', [], void, [], Body)],
      length(Body, 4)      % OPEN, ACCEPT, CLOSE, RETURN
    -> format(" [PASS]~n")
    ; format(" [FAIL]~n")
    ).

%% ==========================================================================
%% Main
%% ==========================================================================

run(Test) :-
    ( catch(call(Test), E, (format("  [ERROR: ~w]~n", [E])))
    -> true
    ; format("  [SKIPPED: ~w]~n", [Test])
    ).

main :-
    format("--- Interpreter Tests (clarion_interpreter.pl) ---~n~n"),
    format("Arithmetic:~n"),
    run(test_mathadd),
    run(test_multiply),
    run(test_from_file),
    nl,
    format("Control flow:~n"),
    run(test_if_then_dot),
    run(test_if_block),
    run(test_if_else_block),
    run(test_loop_break),
    nl,
    format("Expressions & assignment:~n"),
    run(test_qualified_names),
    run(test_compound_assign),
    nl,
    format("Builtins & procedure calls:~n"),
    run(test_procedure_call),
    run(test_size_intrinsic),
    nl,
    format("Integration (file I/O):~n"),
    run(test_diagstore_exec),
    run(test_sensorlib_exec),
    run(test_stats_calc),
    nl,
    format("GUI form simulation:~n"),
    run(test_form_parse),
    run(test_form_calc),
    run(test_form_close_only),
    run(test_form_multi_calc),
    run(test_form_no_events),
    run(test_formdemo_parse),
    format("~nAll interpreter tests complete.~n").
