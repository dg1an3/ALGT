#!----------------------------------------------------------------
#! BisimProof.tpl -- Clarion template family for bisimulation proof
#!
#! Emits Clarion source code that mirrors the Prolog-side proof in
#!
#!   simulators/clarion/unified/bisimulation.pl
#!   simulators/clarion/unified/state_graph_lemmas.pl
#!
#! The template is split into two roles, matching the user's design:
#!
#!   (1) SIGMA and PI models -- TEMPLATE CODE.
#!       The SigmaSnapshot and PiSnapshot extensions generate the
#!       observable-state group buffer, the sigma projection (read
#!       local variables into the buffer) and the pi projection
#!       (query the DLL's exported OLGetVar into the buffer).
#!
#!   (2) Structural lemmas -- INSERTED CODE.
#!       The LemmaCheck extension wraps each event handler (OLInit,
#!       OLSetField, OLCalcBtn, OLClearBtn) with Pre/Post snapshots
#!       via #AT embed points and calls BisimCheckLemma to assert
#!       the delta equation for that event. Lemma failures raise a
#!       trace event that the CDB tooling can pick up directly.
#!
#! Attach in the Clarion Application Builder, or by adding the
#! template to your .cwproj's <Templates> list:
#!
#!   <Templates Include="BisimProof.tpl" />
#!----------------------------------------------------------------

#TEMPLATE(BisimProof,'Bisimulation proof scaffolding for observable-state DLLs')
#!
#! Shared data declarations: the observable-state buffer and the
#! pre/post snapshots used by the lemma checks.
#!
#GROUP(%BisimDataDecls)
BISIM:Obs            GROUP,PRE(BO)
  APValue              LONG
  APDir                LONG
  SIValue              LONG
  SIDir                LONG
  LRValue              LONG
  LRDir                LONG
  Magnitude            LONG
  OffsetDate           LONG
  OffsetTime           LONG
  DataSource           LONG
                     END
BISIM:Pre            LIKE(BISIM:Obs)
BISIM:Post           LIKE(BISIM:Obs)
BISIM:Expected       LIKE(BISIM:Obs)
BISIM:EventName      CSTRING(32)
BISIM:EventArg1      LONG
BISIM:EventArg2      LONG
#ENDGROUP
#!
#! The sigma projection, emitted into the target procedure as a
#! reusable ROUTINE. Reads the module-level observables into a
#! caller-supplied snapshot buffer.
#!
#GROUP(%BisimSigmaRoutine)
BisimSigma           ROUTINE
  BO:APValue    = APValue
  BO:APDir      = APDir
  BO:SIValue    = SIValue
  BO:SIDir      = SIDir
  BO:LRValue    = LRValue
  BO:LRDir      = LRDir
  BO:Magnitude  = Magnitude
  BO:OffsetDate = OffsetDate
  BO:OffsetTime = OffsetTime
  BO:DataSource = DataSource
#ENDGROUP
#!
#! The pi projection: observes the DLL through its own public
#! interface (OLGetVar). Used when the target is a separate
#! process or is compiled without source access.
#!
#GROUP(%BisimPiRoutine)
BisimPi              ROUTINE
  BO:APValue    = OLGetVar(1)
  BO:APDir      = OLGetVar(2)
  BO:SIValue    = OLGetVar(3)
  BO:SIDir      = OLGetVar(4)
  BO:LRValue    = OLGetVar(5)
  BO:LRDir      = OLGetVar(6)
  BO:Magnitude  = OLGetVar(7)
  BO:OffsetDate = OLGetVar(8)
  BO:OffsetTime = OLGetVar(9)
  BO:DataSource = OLGetVar(10)
#ENDGROUP
#!
#! The shared delta-step: applies the abstract event equations to
#! BISIM:Expected so the lemma check can compare with BISIM:Post.
#!
#! This is the Clarion-side analogue of bisimulation:abs_step/3
#! and must stay in lockstep with it. Each event arm is labelled so
#! future events can be added by extending both the Prolog module
#! and this group.
#!
#GROUP(%BisimDeltaRoutine)
BisimDelta           ROUTINE
  BISIM:Expected = BISIM:Pre
  CASE BISIM:EventName
  OF 'init'
    CLEAR(BISIM:Expected)
    BISIM:Expected.APDir = 1
    BISIM:Expected.SIDir = 1
    BISIM:Expected.LRDir = 1
    BISIM:Expected.DataSource = 1
  OF 'clear'
    CLEAR(BISIM:Expected)
    BISIM:Expected.APDir = 1
    BISIM:Expected.SIDir = 1
    BISIM:Expected.LRDir = 1
    BISIM:Expected.DataSource = 1
  OF 'calc'
    BISIM:Expected.Magnitude = |
        ISqrt(BISIM:Pre.APValue * BISIM:Pre.APValue + |
              BISIM:Pre.SIValue * BISIM:Pre.SIValue + |
              BISIM:Pre.LRValue * BISIM:Pre.LRValue)
  OF 'set'
    CASE BISIM:EventArg1
    OF 1
      IF BISIM:EventArg2 < 0
        BISIM:Expected.APValue = 0 - BISIM:EventArg2
        IF BISIM:Pre.APDir = 1 THEN BISIM:Expected.APDir = 2 ELSE BISIM:Expected.APDir = 1.
      ELSE
        BISIM:Expected.APValue = BISIM:EventArg2
      END
    OF 2;  BISIM:Expected.APDir      = BISIM:EventArg2
    OF 3
      IF BISIM:EventArg2 < 0
        BISIM:Expected.SIValue = 0 - BISIM:EventArg2
        IF BISIM:Pre.SIDir = 1 THEN BISIM:Expected.SIDir = 2 ELSE BISIM:Expected.SIDir = 1.
      ELSE
        BISIM:Expected.SIValue = BISIM:EventArg2
      END
    OF 4;  BISIM:Expected.SIDir      = BISIM:EventArg2
    OF 5
      IF BISIM:EventArg2 < 0
        BISIM:Expected.LRValue = 0 - BISIM:EventArg2
        IF BISIM:Pre.LRDir = 1 THEN BISIM:Expected.LRDir = 2 ELSE BISIM:Expected.LRDir = 1.
      ELSE
        BISIM:Expected.LRValue = BISIM:EventArg2
      END
    OF 6;  BISIM:Expected.LRDir      = BISIM:EventArg2
    OF 7;  BISIM:Expected.Magnitude  = BISIM:EventArg2
    OF 8;  BISIM:Expected.OffsetDate = BISIM:EventArg2
    OF 9;  BISIM:Expected.OffsetTime = BISIM:EventArg2
    OF 10; BISIM:Expected.DataSource = BISIM:EventArg2
    END
  END
#ENDGROUP
#!
#! The lemma-check routine: compare BISIM:Post against
#! BISIM:Expected. A mismatch is emitted as a trace line that the
#! CDB comparator (clarion_projects/treatment-offset/
#! compare_cdb_prolog.py) already understands.
#!
#GROUP(%BisimCheckRoutine)
BisimCheckLemma      ROUTINE
  DO BisimDelta
  IF BISIM:Post <> BISIM:Expected
    OutputDebugString('BISIM_FAIL event=' & BISIM:EventName & |
        ' arg1=' & BISIM:EventArg1 & ' arg2=' & BISIM:EventArg2)
  END
#ENDGROUP

#!================================================================
#! EXTENSION (1): SigmaPiProjection
#!
#! Attach to the PROCEDURE that owns the observable state (in the
#! OffsetLib case, every OLxxx procedure). Emits the data
#! declarations, sigma/pi routines and delta/check routines as
#! TEMPLATE CODE so they are available wherever the extension is
#! instantiated.
#!================================================================
#EXTENSION(BisimSigmaPiProjection,'Emit sigma and pi projection routines'),PROCEDURE
#!
#PROMPT('Projection to generate',RADIO),%BisimProjection
#PROMPT('Sigma (in-process, read locals)',RADIO),%BisimProjSigma
#PROMPT('Pi (external, call OLGetVar)',RADIO),%BisimProjPi
#PROMPT('Both',RADIO),%BisimProjBoth
#PROMPT('Emit delta/check routines',CHECK),%BisimEmitCheck,DEFAULT(1)
#!
#AT(%DataSection)
%[%BisimDataDecls]
#ENDAT
#!
#AT(%ProcedureRoutines)
#IF(%BisimProjection = %BisimProjSigma OR %BisimProjection = %BisimProjBoth)
%[%BisimSigmaRoutine]
#ENDIF
#IF(%BisimProjection = %BisimProjPi OR %BisimProjection = %BisimProjBoth)
%[%BisimPiRoutine]
#ENDIF
#IF(%BisimEmitCheck)
%[%BisimDeltaRoutine]
%[%BisimCheckRoutine]
#ENDIF
#ENDAT

#!================================================================
#! EXTENSION (2): LemmaCheck
#!
#! Attach to each event handler procedure. Emits INSERTED CODE at
#! the procedure's entry and exit embed points:
#!
#!   %BeforeFirstStatement: capture BISIM:Pre via sigma.
#!   %BeforeReturn:         capture BISIM:Post via sigma and run
#!                          the lemma check for this event.
#!
#! The #PROMPT values bind the event name and up to two argument
#! sources (usually Clarion parameter references like 'id' and
#! 'val' for OLSetField).
#!================================================================
#EXTENSION(BisimLemmaCheck,'Insert pre/post lemma check around event handler'),PROCEDURE
#!
#PROMPT('Event name',@S32),%BisimEventName
#PROMPT('Event arg 1 (expression, 0 if none)',@S64),%BisimArg1,DEFAULT('0')
#PROMPT('Event arg 2 (expression, 0 if none)',@S64),%BisimArg2,DEFAULT('0')
#PROMPT('Projection (sigma or pi)',DROP('sigma|pi')),%BisimProjUse,DEFAULT('sigma')
#!
#AT(%BeforeFirstStatement)
  ! BISIM: capture pre-state via %BisimProjUse
  DO Bisim%BisimProjUse
  BISIM:Pre = BISIM:Obs
  BISIM:EventName = '%BisimEventName'
  BISIM:EventArg1 = %BisimArg1
  BISIM:EventArg2 = %BisimArg2
#ENDAT
#!
#AT(%BeforeReturn)
  ! BISIM: capture post-state and assert lemma equation
  DO Bisim%BisimProjUse
  BISIM:Post = BISIM:Obs
  DO BisimCheckLemma
#ENDAT

#!================================================================
#! EXTENSION (3): TraceLog
#!
#! Optional: dump each pre/post snapshot to a log file so the
#! trace can be diffed against the Prolog side offline.
#!================================================================
#EXTENSION(BisimTraceLog,'Log sigma/pi snapshots to a file for offline diffing'),PROCEDURE
#!
#PROMPT('Log file name',@S64),%BisimLogFile,DEFAULT('bisim.log')
#!
#AT(%DataSection)
BISIM:Log            CSTRING(256)
BISIM:LogFile        FILE,DRIVER('ASCII'),CREATE,NAME('%BisimLogFile'),PRE(BL),THREAD
Record                 RECORD
Line                     CSTRING(256)
                       END
                     END
#ENDAT
#!
#AT(%BeforeReturn)
  OPEN(BISIM:LogFile,42h)
  IF ERRORCODE() THEN CREATE(BISIM:LogFile); OPEN(BISIM:LogFile,42h).
  BL:Line = 'CALL ' & BISIM:EventName & '(' & BISIM:EventArg1 & ',' & |
            BISIM:EventArg2 & ') pre=' & |
            BISIM:Pre.APValue & ',' & BISIM:Pre.APDir & ',' & |
            BISIM:Pre.SIValue & ',' & BISIM:Pre.SIDir & ',' & |
            BISIM:Pre.LRValue & ',' & BISIM:Pre.LRDir & ',' & |
            BISIM:Pre.Magnitude & ',' & BISIM:Pre.OffsetDate & ',' & |
            BISIM:Pre.OffsetTime & ',' & BISIM:Pre.DataSource & |
            ' post=' & |
            BISIM:Post.APValue & ',' & BISIM:Post.APDir & ',' & |
            BISIM:Post.SIValue & ',' & BISIM:Post.SIDir & ',' & |
            BISIM:Post.LRValue & ',' & BISIM:Post.LRDir & ',' & |
            BISIM:Post.Magnitude & ',' & BISIM:Post.OffsetDate & ',' & |
            BISIM:Post.OffsetTime & ',' & BISIM:Post.DataSource
  ADD(BISIM:LogFile)
  CLOSE(BISIM:LogFile)
#ENDAT
