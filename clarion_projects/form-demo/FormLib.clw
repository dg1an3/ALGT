  MEMBER()

  MAP
    FLInit(),LONG,C,NAME('FLInit'),EXPORT
    FLSetField(LONG id, LONG val),LONG,C,NAME('FLSetField'),EXPORT
    FLCalcBtn(),LONG,C,NAME('FLCalcBtn'),EXPORT
    FLClearBtn(),LONG,C,NAME('FLClearBtn'),EXPORT
    FLGetVar(LONG id),LONG,C,NAME('FLGetVar'),EXPORT
  END

! Variable IDs: 1=SensorID, 2=Reading, 3=Weight, 4=Result, 5=SensorType
SensorID   LONG(0)
Reading    LONG(0)
Weight     LONG(0)
Result     LONG(0)
SensorType LONG(1)

FLInit PROCEDURE()
  CODE
  SensorID = 0
  Reading = 0
  Weight = 0
  Result = 0
  SensorType = 1
  RETURN 0

FLSetField PROCEDURE(LONG id, LONG val)
  CODE
  CASE id
  OF 1
    SensorID = val
  OF 2
    Reading = val
  OF 3
    Weight = val
  OF 4
    Result = val
  OF 5
    SensorType = val
  ELSE
    RETURN -1
  END
  RETURN 0

FLCalcBtn PROCEDURE()
  CODE
  Result = ((Reading * Weight) / 100) * SensorType
  RETURN Result

FLClearBtn PROCEDURE()
  CODE
  SensorID = 0
  Reading = 0
  Weight = 0
  Result = 0
  SensorType = 1
  RETURN 0

FLGetVar PROCEDURE(LONG id)
  CODE
  CASE id
  OF 1
    RETURN SensorID
  OF 2
    RETURN Reading
  OF 3
    RETURN Weight
  OF 4
    RETURN Result
  OF 5
    RETURN SensorType
  END
  RETURN -99999
