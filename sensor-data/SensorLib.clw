  MEMBER()

SensorFile FILE,DRIVER('DOS'),NAME('Sensors.dat'),CREATE,PRE(SF)
Record      RECORD
ID            LONG
Reading       LONG
Weight        LONG
Processed     LONG
Status        LONG
            END
          END

GlobalBuf GROUP,PRE(GB)
ID            LONG
Reading       LONG
Weight        LONG
Processed     LONG
Status        LONG
          END

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    SSOpen(),LONG,C,NAME('SSOpen'),EXPORT
    SSClose(),LONG,C,NAME('SSClose'),EXPORT
    SSAddReading(LONG id, LONG val, LONG w),LONG,C,NAME('SSAddReading'),EXPORT
    SSGetReading(LONG id, LONG bufPtr),LONG,C,NAME('SSGetReading'),EXPORT
    SSCalculateWeightedAverage(),LONG,C,NAME('SSCalculateWeightedAverage'),EXPORT
    SSCleanupLowReadings(LONG threshold),LONG,C,NAME('SSCleanupLowReadings'),EXPORT
  END

SSOpen PROCEDURE()
  CODE
  OPEN(SensorFile)
  IF ERRORCODE()
    CREATE(SensorFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(SensorFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  RETURN 0

SSClose PROCEDURE()
  CODE
  CLOSE(SensorFile)
  RETURN 0

SSAddReading PROCEDURE(LONG id, LONG val, LONG w)
  CODE
  CLEAR(SF:Record)
  SF:ID = id
  SF:Reading = val
  SF:Weight = w
  ! Complex calculation: processed value
  SF:Processed = (val * w) / 100
  SF:Status = 1 ! Active
  ADD(SensorFile)
  IF ERRORCODE() THEN RETURN -2.
  RETURN 0

SSGetReading PROCEDURE(LONG id, LONG bufPtr)
Found LONG(0)
  CODE
  SET(SensorFile)
  LOOP
    NEXT(SensorFile)
    IF ERRORCODE() THEN BREAK.
    IF SF:ID = id
      GB:ID = SF:ID
      GB:Reading = SF:Reading
      GB:Weight = SF:Weight
      GB:Processed = SF:Processed
      GB:Status = SF:Status
      MemCopy(bufPtr, ADDRESS(GlobalBuf), SIZE(GlobalBuf))
      Found = 1
      BREAK
    END
  END
  IF Found = 0 THEN RETURN -1.
  RETURN 0

SSCalculateWeightedAverage PROCEDURE()
TotalValue LONG(0)
TotalWeight LONG(0)
  CODE
  SET(SensorFile)
  LOOP
    NEXT(SensorFile)
    IF ERRORCODE() THEN BREAK.
    IF SF:Status = 1
      TotalValue += SF:Processed
      TotalWeight += SF:Weight
    END
  END
  IF TotalWeight = 0 THEN RETURN 0.
  RETURN (TotalValue * 100) / TotalWeight

SSCleanupLowReadings PROCEDURE(LONG threshold)
RemovedCount LONG(0)
  CODE
  SET(SensorFile)
  LOOP
    NEXT(SensorFile)
    IF ERRORCODE() THEN BREAK.
    IF SF:Status = 1 AND SF:Reading < threshold
      SF:Status = 0 ! Deactivated
      PUT(SensorFile)
      IF ERRORCODE() = 0 THEN RemovedCount += 1.
    END
  END
  RETURN RemovedCount
