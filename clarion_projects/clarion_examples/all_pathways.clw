!============================================================
! all_pathways.clw - Exercises every pathway in the railroad diagrams
!
! Productions covered:
!   program (PROGRAM form), top_decl_item (FILE, GROUP, QUEUE,
!     CLASS, WINDOW, array, global), map_block, map_entry_or_module
!     (all 3 forms), procedure, routine, field_decl,
!   statement (all 23 alternatives), expr (all operator paths),
!   type (all 19 type forms), control_decl (all 6 control types),
!   window_attr (AT, CENTER)
!============================================================

  PROGRAM

!------------------------------------------------------------
! map_block: MAP ... END
! map_entry_or_module: all 3 alternatives
!   (1) MODULE('name') ... END
!   (2) Name(params),RetType,Attrs
!   (3) Name PROCEDURE[(params)],RetType,Attrs
!------------------------------------------------------------
  MAP
    ! Alt 2: Name(params),RetType,Attrs -- with C and EXPORT
    ComputeSum(LONG, LONG),LONG,C,NAME('ComputeSum')
    ! Alt 2: Name(params) -- void return, no attrs
    ShowResult(CSTRING)
    ! Alt 3: Name PROCEDURE(params),RetType
    Classify PROCEDURE(LONG Score),LONG
    ! Alt 3: Name PROCEDURE -- no params, void return
    Initialize PROCEDURE
    ! Alt 1: MODULE block
    MODULE('AllPathways')
      ModuleProc(LONG),LONG,EXPORT
    END
  END

!------------------------------------------------------------
! top_decl_item: FILE declaration
!   Exercises file_attrs, key_decls, record_block, field_decl
!------------------------------------------------------------
SensorFile  FILE,DRIVER('TOPSPEED'),PRE(Sens),CREATE,NAME('sensor.tps')
SensByID      KEY(Sens:SensorID),PRIMARY
SensByName    KEY(Sens:SensorName),NOCASE,DUP,OPT
Record        RECORD
SensorID        LONG
SensorName      STRING(30)
Reading         REAL
Weight          SHORT
Active          BYTE
              END
            END

!------------------------------------------------------------
! top_decl_item: GROUP declaration (with PRE)
!------------------------------------------------------------
OffsetGrp   GROUP,PRE(Off)
Lateral       REAL
Vertical      REAL
Longitudinal  REAL
            END

!------------------------------------------------------------
! top_decl_item: QUEUE declaration
!------------------------------------------------------------
ResultQ     QUEUE
Value         LONG
Label         STRING(20)
            END

!------------------------------------------------------------
! top_decl_item: CLASS declaration (with parent, TYPE, VIRTUAL)
!------------------------------------------------------------
BaseCalc    CLASS,TYPE
Factor        LONG
Init          PROCEDURE
Compute       PROCEDURE(LONG Input),LONG,VIRTUAL
            END

DerivedCalc CLASS(BaseCalc),TYPE
Offset        LONG
Init          PROCEDURE
Compute       PROCEDURE(LONG Input),LONG,VIRTUAL
            END

!------------------------------------------------------------
! top_decl_item: WINDOW declaration
!   Exercises window_attr: AT(x,y,w,h) and CENTER
!   Exercises control_decl: PROMPT, ENTRY, BUTTON, STRING(format),
!     STRING('text'), LIST
!------------------------------------------------------------
MainWin     WINDOW('All Pathways Demo'),AT(,,320,200),CENTER
              PROMPT('Sensor ID:'),AT(10,10)
              ENTRY(@n9),AT(100,10,80,12),USE(SenInput)
              ENTRY(@s30),AT(100,30,150,12),USE(NameInput)
              STRING(@n12),AT(100,50,80,12),USE(?ResultDisplay)
              STRING('Status: Ready'),AT(10,170,200,12),USE(?StatusText)
              BUTTON('&Calculate'),AT(10,80,80,20),USE(?CalcBtn)
              BUTTON('&Clear'),AT(100,80,80,20),USE(?ClearBtn)
              BUTTON('&Quit'),AT(200,80,80,20),USE(?QuitBtn)
              LIST,AT(10,110,300,50),USE(?CategoryList),DROP(5),FROM('Low|Medium|High|Critical')
            END

!------------------------------------------------------------
! top_decl_item: array declaration
!------------------------------------------------------------
Buckets     LONG,DIM(10)

!------------------------------------------------------------
! top_decl_item: global variable -- both forms (with and without init)
!------------------------------------------------------------
MaxRetries  LONG(3)
TotalCount  LONG

!------------------------------------------------------------
! type: all type forms (used across declarations above and locals below)
!   LONG, SHORT, BYTE, REAL, SREAL, DATE, TIME
!   DECIMAL, DECIMAL(size), DECIMAL(size,prec)
!   PDECIMAL, PDECIMAL(size), PDECIMAL(size,prec)
!   CSTRING, CSTRING(size), PSTRING, PSTRING(size)
!   STRING, STRING(size)
!------------------------------------------------------------

  CODE
    Initialize()

!============================================================
! procedure: ident PROCEDURE proc_def_params return_type
!   local_vars CODE statements
!============================================================
Initialize PROCEDURE
  CODE
    TotalCount = 0
    ShowResult('Initialized')

!------------------------------------------------------------
! Procedure with params and return type (exercises return_type path)
!------------------------------------------------------------
ComputeSum PROCEDURE(LONG ValA, LONG ValB)
Result  LONG
  CODE
    Result = ValA + ValB
    RETURN Result

!------------------------------------------------------------
! Procedure with all type variants as locals
!------------------------------------------------------------
ShowResult PROCEDURE(CSTRING Msg)
! local_vars: exercises every type path
LocalLong     LONG(0)
LocalShort    SHORT
LocalByte     BYTE
LocalReal     REAL
LocalSReal    SREAL
LocalDate     DATE
LocalTime     TIME
LocalDec      DECIMAL
LocalDec5     DECIMAL(5)
LocalDec10_2  DECIMAL(10,2)
LocalPDec     PDECIMAL
LocalPDec5    PDECIMAL(5)
LocalPDec10_2 PDECIMAL(10,2)
LocalCS       CSTRING
LocalCS50     CSTRING(50)
LocalPS       PSTRING
LocalPS50     PSTRING(50)
LocalStr      STRING
LocalStr80    STRING(80)

  CODE
    LocalLong = 42
    RETURN

!------------------------------------------------------------
! Classify: exercises CASE/OF/OF-range/ELSE
!------------------------------------------------------------
Classify PROCEDURE(LONG Score)
Category  LONG
  CODE
    ! statement: CASE expr / OF val / OF range / ELSE / END
    CASE Score
    OF 0
      Category = 0
    OF 1 TO 50
      Category = 1
    OF 51 TO 100
      Category = 2
    ELSE
      Category = 3
    END
    RETURN Category

!------------------------------------------------------------
! ModuleProc: exercises various statement alternatives
!------------------------------------------------------------
ModuleProc PROCEDURE(LONG Mode)
Counter   LONG
Sum       LONG
Idx       LONG
Temp      LONG
Flag      LONG

  CODE
    !-- statement: assign (ident = expr) --
    Counter = 0
    Sum = 0

    !-- statement: assign (ident += expr) --
    Counter += 1

    !-- statement: array assign (ident[expr] = expr) --
    Buckets[1] = 100
    Buckets[Counter] = 200

    !-- statement: IF expr THEN stmt . (single-line IF) --
    IF Mode = 0 THEN RETURN 0.

    !-- statement: IF / ELSIF / ELSE / END (multi-line) --
    IF Mode = 1
      Sum = 10
    ELSIF Mode = 2
      Sum = 20
    ELSIF Mode = 3
      Sum = 30
    ELSE
      Sum = 40
    END

    !-- statement: LOOP var = start TO end / END --
    LOOP Idx = 1 TO 10
      Sum = Sum + Idx
      !-- statement: IF with BREAK --
      IF Sum > 100
        BREAK
      END
    END

    !-- statement: LOOP WHILE cond / END --
    Counter = 0
    LOOP WHILE Counter < 5
      Counter = Counter + 1
    END

    !-- statement: LOOP UNTIL cond / END --
    Counter = 0
    LOOP UNTIL Counter >= 5
      Counter = Counter + 1
    END

    !-- statement: LOOP / BREAK / END (infinite loop with break) --
    LOOP
      Counter += 1
      IF Counter > 10
        BREAK
      END
    END

    !-- statement: CYCLE --
    LOOP Idx = 1 TO 10
      IF Idx % 2 = 0
        CYCLE
      END
      Sum += Idx
    END

    !-- statement: DISPLAY --
    DISPLAY

    !-- statement: DO name (routine call) --
    DO HelperRoutine

    !-- statement: call(Name, Args) --
    Temp = ComputeSum(Sum, Counter)

    !-- statement: DELETE(name) --
    DELETE(ResultQ)

    !-- statement: RETURN expr --
    RETURN Temp

!------------------------------------------------------------
! routine: ident ROUTINE statements
!   Also exercises EXIT statement
!------------------------------------------------------------
HelperRoutine ROUTINE
    TotalCount += 1
    !-- statement: EXIT --
    EXIT

!------------------------------------------------------------
! Procedure exercising SELF/PARENT and method_call statements
!------------------------------------------------------------
BaseCalc.Init PROCEDURE
  CODE
    !-- statement: SELF.Prop = Expr --
    SELF.Factor = 1

BaseCalc.Compute PROCEDURE(LONG Input)
  CODE
    RETURN Input * SELF.Factor

DerivedCalc.Init PROCEDURE
  CODE
    !-- statement: PARENT.Method(Args) --
    PARENT.Init()
    SELF.Offset = 10

DerivedCalc.Compute PROCEDURE(LONG Input)
Intermediate  LONG
  CODE
    !-- statement: Obj.Method(Args) -- via PARENT call as expr --
    Intermediate = PARENT.Compute(Input)
    RETURN Intermediate + SELF.Offset

!------------------------------------------------------------
! Procedure exercising ACCEPT loop and all expression operators
!------------------------------------------------------------
AllExpressions PROCEDURE
! locals for expression testing
ValA    LONG
ValB    LONG
ValC    LONG
Res     LONG
StrA    CSTRING(50)
StrB    CSTRING(50)
StrC    CSTRING(100)
Flag    LONG

  CODE
    !-- expr: literals --
    ValA = 42
    ValB = -7
    StrA = 'hello'

    !-- expr: add(+), sub(-) --
    ValC = ValA + ValB
    ValC = ValA - ValB

    !-- expr: mul(*), div(/), modulo(%) --
    ValC = ValA * ValB
    ValC = ValA / ValB
    ValC = ValA % ValB

    !-- expr: string concat (&) --
    StrC = StrA & ' world'

    !-- expr: comparison operators: =, <>, <, <=, >, >= --
    IF ValA = ValB
      Res = 1
    END
    IF ValA <> ValB
      Res = 2
    END
    IF ValA < ValB
      Res = 3
    END
    IF ValA <= ValB
      Res = 4
    END
    IF ValA > ValB
      Res = 5
    END
    IF ValA >= ValB
      Res = 6
    END

    !-- expr: AND, OR --
    IF ValA > 0 AND ValB < 0
      Flag = 1
    END
    IF ValA = 0 OR ValB = 0
      Flag = 0
    END

    !-- expr: parenthesized sub-expression --
    ValC = (ValA + ValB) * (ValA - ValB)

    !-- expr: function call in expression --
    ValC = ComputeSum(ValA, ValB)

    !-- expr: array_ref in expression --
    ValC = Buckets[1]
    ValC = Buckets[ValA]

    !-- expr: equate reference --
    OPEN(MainWin)
    ACCEPT
      CASE ACCEPTED()
      OF ?CalcBtn
        Res = 1
      OF ?ClearBtn
        Res = 2
      OF ?QuitBtn
        BREAK
      END
    END

    !-- statement: bare RETURN (no expr) --
    RETURN
