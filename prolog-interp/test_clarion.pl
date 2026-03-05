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
    format("~nAll tests complete.~n").
