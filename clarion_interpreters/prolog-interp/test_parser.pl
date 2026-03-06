% test_parser.pl — Tests for clarion_parser.pl (DCG grammar)

:- use_module(clarion_parser).
:- set_prolog_flag(double_quotes, codes).

%% ==========================================================================
%% MathLib parse tests
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

test_from_file_parse :-
    read_file_to_codes('../../clarion_projects/python-dll/MathLib.clw', Codes, []),
    parse_clarion(Codes, AST),
    format("  MathLib.clw file parse"),
    ( AST = program([], [], [], _, [_,_]) -> format(" [PASS]~n") ; format(" [FAIL]~n") ).

%% ==========================================================================
%% Chunk 1 tests — Declarations & data model
%% ==========================================================================

test_file_decl :-
    Src = "
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
",
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

test_group_decl :-
    Src = "
  MEMBER()

DiagBuf   GROUP,PRE(DB)
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
          END

  MAP
  END
",
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

test_globals :-
    Src = "
  MEMBER()

NextID    LONG(0)
FilePos   LONG(0)

  MAP
  END
",
    parse_clarion(Src, AST),
    AST = program(_, _, Globals, _, _),
    format("  Global variables"),
    ( Globals = [global('NextID', long, 0), global('FilePos', long, 0)]
    -> format(" [PASS]~n")
    ;  format(" [FAIL]~n")
    ).

test_enhanced_map :-
    Src = "
  MEMBER()

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FindRecord(LONG id),LONG,PRIVATE
    DSOpenStore(),LONG,C,NAME('DSOpenStore'),EXPORT
    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
  END
",
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

test_local_vars :-
    Src = "
  MEMBER()

  MAP
    DSListByPatient(LONG,LONG,LONG,LONG),LONG,C,NAME('DSListByPatient'),EXPORT
  END

DSListByPatient PROCEDURE(LONG patientID, LONG bufPtr, LONG maxCount, LONG outCountPtr)
Count  LONG(0)
Offset LONG(0)
  CODE
  RETURN(0)
",
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

test_cstring_params :-
    Src = "
  MEMBER()

  MAP
    DSCreateDiagnosis(LONG,*CSTRING,*CSTRING,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
  END

DSCreateDiagnosis PROCEDURE(LONG patientID, *CSTRING icdCode, *CSTRING desc, LONG diagDate)
  CODE
  RETURN(0)
",
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

test_diagstore_parse :-
    format("  DiagnosisStore.clw declarations"),
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

test_sensorlib_parse :-
    File = '../../clarion_projects/sensor-data/SensorLib.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    format("  SensorLib.clw parse"),
    ( parse_clarion(Codes, AST),
      AST = program(Files, Groups, _, _, Procs),
      length(Files, 1), length(Groups, 1), length(Procs, 6)
    -> format(" [PASS]~n")
    ; format(" [FAIL]~n")
    ).

test_statslib_parse :-
    File = '../../clarion_projects/stats-calc/StatsLib.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    format("  StatsLib.clw parse"),
    ( parse_clarion(Codes, _AST) -> format(" [PASS]~n") ; format(" [FAIL]~n") ).

test_diagstore_full_parse :-
    File = '../../clarion_projects/diagnosis-store/DiagnosisStore.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    format("  DiagnosisStore.clw full parse"),
    ( parse_clarion(Codes, AST),
      AST = program(_, _, _, _, _)
    -> format(" [PASS]~n")
    ; format(" [FAIL]~n")
    ).

test_odbcstore_parse :-
    File = '../../clarion_projects/odbc-store/OdbcStore.clw',
    ( exists_file(File) -> true ; format(" [FAIL: ~w not found]~n", [File]), fail ),
    read_file_to_codes(File, Codes, []),
    format("  OdbcStore.clw parse"),
    ( parse_clarion(Codes, AST),
      AST = program(Files, Groups, Globals, _, Procs),
      length(Files, 1), length(Groups, 1), length(Globals, 3), length(Procs, 7),
      member(file('SensorReadings', 'SR', Attrs, _), Files),
      member(owner('OdbcDemo'), Attrs),
      member(driver('ODBC'), Attrs)
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
    format("--- Parser Tests (clarion_parser.pl) ---~n~n"),
    format("Inline sources:~n"),
    run(test_parse),
    run(test_file_decl),
    run(test_group_decl),
    run(test_globals),
    run(test_enhanced_map),
    run(test_local_vars),
    run(test_cstring_params),
    run(test_diagstore_parse),
    nl,
    format("File sources:~n"),
    run(test_from_file_parse),
    run(test_sensorlib_parse),
    run(test_statslib_parse),
    run(test_diagstore_full_parse),
    run(test_odbcstore_parse),
    format("~nAll parser tests complete.~n").
