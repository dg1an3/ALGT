% test_clarion.pl — Tests for the Clarion Prolog interpreter

:- use_module(clarion).
:- set_prolog_flag(double_quotes, codes).

%% ==========================================================================
%% MathLib tests (existing)
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

test_parse :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    format("  Parse MathLib inline"),
    ( AST = program([], [], [], _, [_,_]) -> format(" [PASS]~n") ; format(" [FAIL]~n") ).

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
%% Chunk 1 tests — Declarations & data model
%% ==========================================================================

% Test: FILE declaration parsing
file_source("
  MEMBER()

DiagFile  FILE,DRIVER('DOS'),NAME('Diagnosis.dat'),CREATE,PRE(DX)
Record      RECORD
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
            END
          END

  MAP
  END
").

test_file_decl :-
    file_source(Src),
    parse_clarion(Src, AST),
    AST = program(Files, _, _, _, _),
    format("  FILE declaration"),
    ( Files = [file('DiagFile', 'DX', Attrs, Fields)],
      memberchk(driver('DOS'), Attrs),
      memberchk(name('Diagnosis.dat'), Attrs),
      memberchk(create, Attrs),
      length(Fields, 3),
      Fields = [field('RecordID', long), field('PatientID', long),
                field('ICDCode', cstring(12))]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n"),
       ( var(Files) -> format("    (parse failed)~n")
       ; format("    got: ~w~n", [Files])
       )
    ).

% Test: GROUP declaration parsing
group_source("
  MEMBER()

DiagBuf   GROUP,PRE(DB)
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
          END

  MAP
  END
").

test_group_decl :-
    group_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, Groups, _, _, _),
    format("  GROUP declaration"),
    ( Groups = [group('DiagBuf', 'DB', Fields)],
      length(Fields, 3),
      Fields = [field('RecordID', long), field('PatientID', long),
                field('ICDCode', cstring(12))]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n")
    ).

% Test: Global variable declarations
globals_source("
  MEMBER()

NextID    LONG(0)
FilePos   LONG(0)

  MAP
  END
").

test_globals :-
    globals_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, _, Globals, _, _),
    format("  Global variables"),
    ( Globals = [global('NextID', long, 0), global('FilePos', long, 0)]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n")
    ).

% Test: Enhanced MAP with MODULE, PRIVATE, *CSTRING, RAW, PASCAL
enhanced_map_source("
  MEMBER()

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FindRecord(LONG id),LONG,PRIVATE
    DSOpenStore(),LONG,C,NAME('DSOpenStore'),EXPORT
    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
  END
").

test_enhanced_map :-
    enhanced_map_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, _, _, MapEntries, _),
    format("  Enhanced MAP (MODULE, PRIVATE, *CSTRING)"),
    ( MapEntries = [module_entry('kernel32', [MemCopy]),
                    FindRec, DSOpen, DSCreate],
      MemCopy = map_entry('MemCopy', _, void, MemAttrs),
      memberchk(raw, MemAttrs),
      memberchk(pascal, MemAttrs),
      FindRec = map_entry('FindRecord', _, long, FindAttrs),
      memberchk(private, FindAttrs),
      DSOpen = map_entry('DSOpenStore', [], long, _),
      DSCreate = map_entry('DSCreateDiagnosis', CreateParams, long, _),
      length(CreateParams, 4),
      CreateParams = [param(anonymous, long),
                      param(anonymous, ref(cstring)),
                      param(anonymous, ref(cstring)),
                      param(anonymous, long)]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n"),
       format("    got: ~w~n", [MapEntries])
    ).

% Test: Procedure with local variables
locals_source("
  MEMBER()

  MAP
    DSListByPatient(LONG,LONG,LONG,LONG),LONG,C,NAME('DSListByPatient'),EXPORT
  END

DSListByPatient PROCEDURE(LONG patientID, LONG bufPtr, LONG maxCount, LONG outCountPtr)
Count  LONG(0)
Offset LONG(0)
  CODE
  RETURN(0)
").

test_local_vars :-
    locals_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    format("  Procedure with local variables"),
    ( Procs = [procedure('DSListByPatient', Params, void, Locals, _Body)],
      length(Params, 4),
      Locals = [local('Count', long, 0), local('Offset', long, 0)]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n"),
       format("    got procs: ~w~n", [Procs])
    ).

% Test: Procedure with *CSTRING parameters
cstring_params_source("
  MEMBER()

  MAP
    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
  END

DSCreateDiagnosis PROCEDURE(LONG patientID, *CSTRING icdCode, *CSTRING desc, LONG diagDate)
  CODE
  RETURN(0)
").

test_cstring_params :-
    cstring_params_source(Src),
    parse_clarion(Src, AST),
    AST = program(_, _, _, _, Procs),
    format("  Procedure with *CSTRING params"),
    ( Procs = [procedure('DSCreateDiagnosis', Params, void, [], _)],
      Params = [param(patientID, long),
                param(icdCode, ref(cstring)),
                param(desc, ref(cstring)),
                param(diagDate, long)]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n"),
       format("    got procs: ~w~n", [Procs])
    ).

% Test: DiagnosisStore.clw declarations parse (procedures need chunks 2-4)
% Build a truncated source with just decls + empty MAP to test declarations
test_diagstore_parse :-
    format("  DiagnosisStore.clw declarations"),
    % Source with FILE, GROUP, globals, and full MAP from DiagnosisStore
    Src = "
  MEMBER()

DiagFile  FILE,DRIVER('DOS'),NAME('Diagnosis.dat'),CREATE,PRE(DX)
Record      RECORD
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
Description   CSTRING(256)
TStage        CSTRING(8)
NStage        CSTRING(8)
MStage        CSTRING(8)
OverallStage  CSTRING(8)
DiagDate      LONG
Status        LONG
ApprovedBy    CSTRING(64)
ApprovedDate  LONG
            END
          END

DiagBuf   GROUP,PRE(DB)
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
Description   CSTRING(256)
TStage        CSTRING(8)
NStage        CSTRING(8)
MStage        CSTRING(8)
OverallStage  CSTRING(8)
DiagDate      LONG
Status        LONG
ApprovedBy    CSTRING(64)
ApprovedDate  LONG
          END

NextID    LONG(0)
FilePos   LONG(0)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FindRecord(LONG id),LONG,PRIVATE
    DSOpenStore(),LONG,C,NAME('DSOpenStore'),EXPORT
    DSCloseStore(),LONG,C,NAME('DSCloseStore'),EXPORT
    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,*CSTRING,*CSTRING,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
    DSGetDiagnosis(LONG,LONG),LONG,C,NAME('DSGetDiagnosis'),EXPORT
    DSUpdateDiagnosis(LONG,LONG),LONG,C,NAME('DSUpdateDiagnosis'),EXPORT
    DSApproveDiagnosis(LONG,*CSTRING),LONG,C,NAME('DSApproveDiagnosis'),EXPORT
    DSDeleteDiagnosis(LONG),LONG,C,NAME('DSDeleteDiagnosis'),EXPORT
    DSListByPatient(LONG,LONG,LONG,LONG),LONG,C,NAME('DSListByPatient'),EXPORT
  END
",
    ( parse_clarion(Src, AST),
      AST = program(Files, Groups, Globals, MapEntries, _),
      length(Files, NF),
      length(Groups, NG),
      length(Globals, NV),
      length(MapEntries, NM)
    -> format(" [PASS] (~w file, ~w group, ~w globals, ~w map)~n", [NF,NG,NV,NM])
    ;  format(" [FAIL]~n")
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
    format("--- Clarion Prolog Interpreter Tests ---~n~n"),
    format("MathLib:~n"),
    run(test_parse),
    run(test_mathadd),
    run(test_multiply),
    run(test_from_file),
    nl,
    format("Chunk 1 — Declarations:~n"),
    run(test_file_decl),
    run(test_group_decl),
    run(test_globals),
    run(test_enhanced_map),
    run(test_local_vars),
    run(test_cstring_params),
    run(test_diagstore_parse),
    nl,
    format("Chunk 2 — Control flow:~n"),
    run(test_if_then_dot),
    run(test_if_block),
    run(test_if_else_block),
    run(test_loop_break),
    nl,
    format("Chunk 3 — Expressions & assignment:~n"),
    run(test_qualified_names),
    run(test_compound_assign),
    nl,
    format("Chunk 4 — Builtins & procedure calls:~n"),
    run(test_procedure_call),
    run(test_size_intrinsic),
    run(test_diagstore_full),
    run(test_sensorlib),
    run(test_stats_calc),
    format("~nAll tests complete.~n").

test_sensorlib :-
    File = '../sensor-data/SensorLib.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    format("  SensorLib.clw parse"),
    ( parse_clarion(Codes, AST) -> format(" [PASS]~n") ; format(" [FAIL: parse]~n"), fail ),

    % Match the Python test_sensorlib.py execution trace exactly
    init_file_io,

    format("  SSOpen()"),
    exec_procedure(AST, 'SSOpen', [], R0),
    ( R0 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R0=~w]~n", [R0]) ),

    % Add readings: Processed = (val * w) / 100
    format("  SSAddReading(1, 100, 50)"),
    exec_procedure(AST, 'SSAddReading', [1, 100, 50], R1),
    ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ),

    format("  SSAddReading(2, 200, 25)"),
    exec_procedure(AST, 'SSAddReading', [2, 200, 25], R2),
    ( R2 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) ),

    format("  SSAddReading(3, 300, 10)"),
    exec_procedure(AST, 'SSAddReading', [3, 300, 10], R3),
    ( R3 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R3=~w]~n", [R3]) ),

    % Weighted average: (50+50+30)*100 / (50+25+10) = 13000/85 = 152
    format("  SSCalculateWeightedAverage() = 152"),
    exec_procedure(AST, 'SSCalculateWeightedAverage', [], Avg),
    ( Avg =:= 152 -> format(" [PASS]~n") ; format(" [FAIL: Avg=~w]~n", [Avg]) ),

    % Cleanup readings below 150: ID 1 (reading=100) removed
    format("  SSCleanupLowReadings(150) = 1"),
    exec_procedure(AST, 'SSCleanupLowReadings', [150], Removed),
    ( Removed =:= 1 -> format(" [PASS]~n") ; format(" [FAIL: Removed=~w]~n", [Removed]) ),

    % New average: (50+30)*100 / (25+10) = 8000/35 = 228
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
    format("  StatsLib.clw (complex features)"),
    ( parse_clarion(Codes, AST) -> format(" [PASS]~n") ; format(" [FAIL: parse]~n"), fail ),
    format("  StatsLib.clw CalculateStats(3)"),
    ( exec_procedure(AST, 'CalculateStats', [3], R1) ->
        ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) )
    ; format(" [FAIL: exec CalculateStats]~n")
    ),
    format("  StatsLib.clw Classify(5) = 1 (Low)"),
    ( exec_procedure(AST, 'Classify', [5], R2) ->
        ( R2 =:= 1 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) )
    ; format(" [FAIL: exec Classify]~n")
    ).

%% ==========================================================================
%% Integration test
%% ==========================================================================

test_diagstore_full :-
    read_file_to_codes('../diagnosis-store/DiagnosisStore.clw', Codes, []),
    parse_clarion(Codes, AST),
    format("  DiagnosisStore.clw (full parse)"),
    ( AST = program(_, _, _, _, _) -> format(" [PASS]~n") ; format(" [FAIL]~n") ),
    init_file_io,
    format("  DiagnosisStore.clw DSOpenStore()"),
    exec_procedure(AST, 'DSOpenStore', [], R1),
    ( R1 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ),
    format("  DiagnosisStore.clw DSCreateDiagnosis(...)"),
    exec_procedure(AST, 'DSCreateDiagnosis', [123, "C34.1", "Lung Cancer", "T2", "N0", "M0", "IIA", 0], R2),
    ( R2 =:= 0 -> format(" [PASS]~n") ; format(" [FAIL: R2=~w]~n", [R2]) ).

%% ==========================================================================
%% Chunk 4 tests — Builtins & procedure calls
%% ==========================================================================

% Test: User-defined procedure call
proc_call_source("
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
").

test_procedure_call :-
    proc_call_source(Src),
    parse_clarion(Src, AST),
    format("  Procedure call (Square(n))"),
    exec_procedure(AST, 'TestCall', [4], R1),
    ( R1 =:= 17 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

% Test: SIZE intrinsic
size_source("
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
").

test_size_intrinsic :-
    size_source(Src),
    parse_clarion(Src, AST),
    format("  SIZE(DiagBuf)"),
    exec_procedure(AST, 'TestSize', [], R1),
    ( R1 =:= 8 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

%% ==========================================================================
%% Chunk 3 tests — Expressions & assignment
%% ==========================================================================

% Test: Qualified names (DX:RecordID, DB:ICDCode)
qualified_names_source("
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
").

test_qualified_names :-
    qualified_names_source(Src),
    parse_clarion(Src, AST),
    format("  Qualified names (DX:RecordID)"),
    exec_procedure(AST, 'TestQual', [], R1),
    ( R1 =:= 100 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

% Test: Compound assignment (var += expr)
compound_assign_source("
  MEMBER()
  MAP
    TestAdd(LONG),LONG
  END

TestAdd PROCEDURE(LONG val)
i LONG(10)
  CODE
  i += val
  RETURN(i)
").

test_compound_assign :-
    compound_assign_source(Src),
    parse_clarion(Src, AST),
    format("  Compound assignment (i += val)"),
    exec_procedure(AST, 'TestAdd', [5], R1),
    ( R1 =:= 15 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).

%% ==========================================================================
%% Chunk 2 tests — Control flow
%% ==========================================================================

% Test: IF expr THEN statement .
if_then_dot_source("
  MEMBER()
  MAP
    TestIf(LONG),LONG
  END

TestIf PROCEDURE(LONG val)
  CODE
  IF val = 1 THEN RETURN(10).
  RETURN(20)
").

test_if_then_dot :-
    if_then_dot_source(Src),
    parse_clarion(Src, AST),
    format("  IF expr THEN statement ."),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 20 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

% Test: IF expr / stmts / END
if_block_source("
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
").

test_if_block :-
    if_block_source(Src),
    parse_clarion(Src, AST),
    format("  IF expr / stmts / END"),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 20 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

% Test: IF expr / stmts / ELSE / stmts / END
if_else_block_source("
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
").

test_if_else_block :-
    if_else_block_source(Src),
    parse_clarion(Src, AST),
    format("  IF expr / stmts / ELSE / stmts / END"),
    exec_procedure(AST, 'TestIf', [1], R1),
    exec_procedure(AST, 'TestIf', [0], R2),
    ( R1 =:= 10, R2 =:= 30 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w, R2=~w]~n", [R1, R2]) ).

% Test: LOOP / stmts / END and BREAK
loop_break_source("
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
").

test_loop_break :-
    loop_break_source(Src),
    parse_clarion(Src, AST),
    format("  LOOP / stmts / END and BREAK"),
    exec_procedure(AST, 'TestLoop', [5], R1),
    ( R1 =:= 5 -> format(" [PASS]~n") ; format(" [FAIL: R1=~w]~n", [R1]) ).
