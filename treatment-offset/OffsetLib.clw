  MEMBER()

  MAP
    OLInit(),LONG,C,NAME('OLInit'),EXPORT
    OLSetField(LONG id, LONG val),LONG,C,NAME('OLSetField'),EXPORT
    OLCalcBtn(),LONG,C,NAME('OLCalcBtn'),EXPORT
    OLClearBtn(),LONG,C,NAME('OLClearBtn'),EXPORT
    OLGetVar(LONG id),LONG,C,NAME('OLGetVar'),EXPORT
    ISqrt(LONG),LONG
  END

! Variable IDs:
!   1=APValue, 2=APDir(1=Ant,2=Post)
!   3=SIValue, 4=SIDir(1=Sup,2=Inf)
!   5=LRValue, 6=LRDir(1=Left,2=Right)
!   7=Magnitude, 8=OffsetDate, 9=OffsetTime, 10=DataSource
! Shift values in mm, always positive after normalization
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

OLInit PROCEDURE()
  CODE
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
  RETURN 0

OLSetField PROCEDURE(LONG id, LONG val)
  CODE
  CASE id
  OF 1
    IF val < 0
      APValue = 0 - val
      IF APDir = 1 THEN APDir = 2 ELSE APDir = 1.
    ELSE
      APValue = val
    END
  OF 2
    APDir = val
  OF 3
    IF val < 0
      SIValue = 0 - val
      IF SIDir = 1 THEN SIDir = 2 ELSE SIDir = 1.
    ELSE
      SIValue = val
    END
  OF 4
    SIDir = val
  OF 5
    IF val < 0
      LRValue = 0 - val
      IF LRDir = 1 THEN LRDir = 2 ELSE LRDir = 1.
    ELSE
      LRValue = val
    END
  OF 6
    LRDir = val
  OF 7
    Magnitude = val
  OF 8
    OffsetDate = val
  OF 9
    OffsetTime = val
  OF 10
    DataSource = val
  ELSE
    RETURN -1
  END
  RETURN 0

OLCalcBtn PROCEDURE()
  CODE
  Magnitude = ISqrt(APValue * APValue + SIValue * SIValue + LRValue * LRValue)
  RETURN Magnitude

OLClearBtn PROCEDURE()
  CODE
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
  RETURN 0

OLGetVar PROCEDURE(LONG id)
  CODE
  CASE id
  OF 1
    RETURN APValue
  OF 2
    RETURN APDir
  OF 3
    RETURN SIValue
  OF 4
    RETURN SIDir
  OF 5
    RETURN LRValue
  OF 6
    RETURN LRDir
  OF 7
    RETURN Magnitude
  OF 8
    RETURN OffsetDate
  OF 9
    RETURN OffsetTime
  OF 10
    RETURN DataSource
  END
  RETURN -99999

! Integer square root via Newton's method
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
