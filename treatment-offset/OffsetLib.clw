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
!   1=Anterior, 2=Superior, 3=Lateral, 4=Magnitude
!   5=OffsetDate, 6=OffsetTime, 7=DataSource
! Shift values in mm (e.g. 15 = 1.5 cm)
Anterior   LONG(0)
Superior   LONG(0)
Lateral    LONG(0)
Magnitude  LONG(0)
OffsetDate LONG(0)
OffsetTime LONG(0)
DataSource LONG(1)

OLInit PROCEDURE()
  CODE
  Anterior = 0
  Superior = 0
  Lateral = 0
  Magnitude = 0
  OffsetDate = 0
  OffsetTime = 0
  DataSource = 1
  RETURN 0

OLSetField PROCEDURE(LONG id, LONG val)
  CODE
  CASE id
  OF 1
    Anterior = val
  OF 2
    Superior = val
  OF 3
    Lateral = val
  OF 4
    Magnitude = val
  OF 5
    OffsetDate = val
  OF 6
    OffsetTime = val
  OF 7
    DataSource = val
  ELSE
    RETURN -1
  END
  RETURN 0

OLCalcBtn PROCEDURE()
  CODE
  Magnitude = ISqrt(Anterior * Anterior + Superior * Superior + Lateral * Lateral)
  RETURN Magnitude

OLClearBtn PROCEDURE()
  CODE
  Anterior = 0
  Superior = 0
  Lateral = 0
  Magnitude = 0
  OffsetDate = 0
  OffsetTime = 0
  DataSource = 1
  RETURN 0

OLGetVar PROCEDURE(LONG id)
  CODE
  CASE id
  OF 1
    RETURN Anterior
  OF 2
    RETURN Superior
  OF 3
    RETURN Lateral
  OF 4
    RETURN Magnitude
  OF 5
    RETURN OffsetDate
  OF 6
    RETURN OffsetTime
  OF 7
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
