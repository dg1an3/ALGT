  MEMBER()

! ===================================================================
! OffsetLibBisim.clw -- illustrative example of BisimProof.tpl output
!
! This file shows the Clarion source that would be produced if the
! BisimProof.tpl extensions were applied to OffsetLib.clw
! (treatment-offset project):
!
!   * BisimSigmaPiProjection on OLInit (with 'Both' + 'Emit check')
!       generates BISIM:Obs / BISIM:Pre / BISIM:Post declarations
!       and the BisimSigma, BisimPi, BisimDelta, BisimCheckLemma
!       routines.
!
!   * BisimLemmaCheck applied to each event handler, producing the
!       pre/post snapshot + lemma-check INSERTED CODE at
!       %BeforeFirstStatement and %BeforeReturn.
!
! Build this alongside OffsetLib.clw only when you want the runtime
! lemma-check overhead; the Prolog-side proof
! (simulators/clarion/unified/test_bisimulation.pl) runs the same
! structural lemmas symbolically and is the primary verification
! path.
! ===================================================================

  MAP
    OLInit(),LONG,C,NAME('OLInit'),EXPORT
    OLSetField(LONG id, LONG val),LONG,C,NAME('OLSetField'),EXPORT
    OLCalcBtn(),LONG,C,NAME('OLCalcBtn'),EXPORT
    OLClearBtn(),LONG,C,NAME('OLClearBtn'),EXPORT
    OLGetVar(LONG id),LONG,C,NAME('OLGetVar'),EXPORT
    ISqrt(LONG),LONG
    MODULE('kernel32.dll')
      OutputDebugString(*CSTRING),PASCAL,NAME('OutputDebugStringA')
    END
  END

! ----- module state (observable variables) -----
APValue    LONG(0)
APDir      LONG(1)
SIValue    LONG(0)
SIDir      LONG(1)
LRValue    LONG(0)
LRDir      LONG(1)
Magnitude  LONG(0)
OffsetDate LONG(0)
OffsetTime LONG(0)
DataSource LONG(1)

! ----- BISIM: data declarations emitted by the template -----
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

!-----------------------------------------------------------------
! OLInit: Apply BisimLemmaCheck extension with EventName='init'.
! The INSERTED CODE sits at %BeforeFirstStatement and %BeforeReturn.
!-----------------------------------------------------------------
OLInit PROCEDURE()
  CODE
  ! [INSERTED: BisimLemmaCheck @ %BeforeFirstStatement]
  DO BisimSigma
  BISIM:Pre = BISIM:Obs
  BISIM:EventName = 'init'
  BISIM:EventArg1 = 0
  BISIM:EventArg2 = 0
  ! [ORIGINAL BODY]
  APValue = 0
  APDir = 1
  SIValue = 0
  SIDir = 1
  LRValue = 0
  LRDir = 1
  Magnitude = 0
  OffsetDate = 0
  OffsetTime = 0
  DataSource = 1
  ! [INSERTED: BisimLemmaCheck @ %BeforeReturn]
  DO BisimSigma
  BISIM:Post = BISIM:Obs
  DO BisimCheckLemma
  RETURN 0

!-----------------------------------------------------------------
! OLSetField: EventName='set', arg1=id, arg2=val
!-----------------------------------------------------------------
OLSetField PROCEDURE(LONG id, LONG val)
  CODE
  ! [INSERTED @ %BeforeFirstStatement]
  DO BisimSigma
  BISIM:Pre = BISIM:Obs
  BISIM:EventName = 'set'
  BISIM:EventArg1 = id
  BISIM:EventArg2 = val
  ! [ORIGINAL BODY]
  CASE id
  OF 1
    IF val < 0
      APValue = 0 - val
      IF APDir = 1 THEN APDir = 2 ELSE APDir = 1.
    ELSE
      APValue = val
    END
  OF 2; APDir = val
  OF 3
    IF val < 0
      SIValue = 0 - val
      IF SIDir = 1 THEN SIDir = 2 ELSE SIDir = 1.
    ELSE
      SIValue = val
    END
  OF 4; SIDir = val
  OF 5
    IF val < 0
      LRValue = 0 - val
      IF LRDir = 1 THEN LRDir = 2 ELSE LRDir = 1.
    ELSE
      LRValue = val
    END
  OF 6; LRDir = val
  OF 7; Magnitude = val
  OF 8; OffsetDate = val
  OF 9; OffsetTime = val
  OF 10; DataSource = val
  ELSE
    ! [INSERTED @ %BeforeReturn -- early return variant]
    DO BisimSigma
    BISIM:Post = BISIM:Obs
    DO BisimCheckLemma
    RETURN -1
  END
  ! [INSERTED @ %BeforeReturn]
  DO BisimSigma
  BISIM:Post = BISIM:Obs
  DO BisimCheckLemma
  RETURN 0

!-----------------------------------------------------------------
! OLCalcBtn: EventName='calc'
!-----------------------------------------------------------------
OLCalcBtn PROCEDURE()
  CODE
  DO BisimSigma
  BISIM:Pre = BISIM:Obs
  BISIM:EventName = 'calc'
  BISIM:EventArg1 = 0
  BISIM:EventArg2 = 0
  Magnitude = ISqrt(APValue * APValue + SIValue * SIValue + LRValue * LRValue)
  DO BisimSigma
  BISIM:Post = BISIM:Obs
  DO BisimCheckLemma
  RETURN Magnitude

!-----------------------------------------------------------------
! OLClearBtn: EventName='clear'
!-----------------------------------------------------------------
OLClearBtn PROCEDURE()
  CODE
  DO BisimSigma
  BISIM:Pre = BISIM:Obs
  BISIM:EventName = 'clear'
  BISIM:EventArg1 = 0
  BISIM:EventArg2 = 0
  APValue = 0
  APDir = 1
  SIValue = 0
  SIDir = 1
  LRValue = 0
  LRDir = 1
  Magnitude = 0
  OffsetDate = 0
  OffsetTime = 0
  DataSource = 1
  DO BisimSigma
  BISIM:Post = BISIM:Obs
  DO BisimCheckLemma
  RETURN 0

OLGetVar PROCEDURE(LONG id)
  CODE
  CASE id
  OF 1;  RETURN APValue
  OF 2;  RETURN APDir
  OF 3;  RETURN SIValue
  OF 4;  RETURN SIDir
  OF 5;  RETURN LRValue
  OF 6;  RETURN LRDir
  OF 7;  RETURN Magnitude
  OF 8;  RETURN OffsetDate
  OF 9;  RETURN OffsetTime
  OF 10; RETURN DataSource
  END
  RETURN -99999

!=================================================================
! TEMPLATE-GENERATED ROUTINES
! (From BisimSigmaPiProjection extension, 'Both' projection mode.)
!=================================================================

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

BisimCheckLemma      ROUTINE
  DO BisimDelta
  IF BISIM:Post <> BISIM:Expected
    OutputDebugString('BISIM_FAIL event=' & BISIM:EventName & |
        ' arg1=' & BISIM:EventArg1 & ' arg2=' & BISIM:EventArg2)
  END

! Integer square root via Newton's method (reused from OffsetLib.clw)
ISqrt PROCEDURE(LONG n)
x  LONG
x1 LONG
  CODE
  IF n <= 0 THEN RETURN 0.
  x = n
  x1 = (x + 1) / 2
  LOOP WHILE x1 < x
    x = x1
    x1 = (x + n / x) / 2
  END
  RETURN x
