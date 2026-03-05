  MEMBER()

SensorReadings FILE,DRIVER('ODBC'),NAME('SensorReadings'),OWNER('OdbcDemo'),CREATE,PRE(SR)
ReadingKey       KEY(SR:ReadingID),PRIMARY
Record           RECORD
ReadingID          LONG
SensorID           LONG
Value              LONG
Weight             LONG
Timestamp          LONG
                 END
               END

ReadBuf   GROUP,PRE(RB)
ReadingID     LONG
SensorID      LONG
Value         LONG
Weight        LONG
Timestamp     LONG
          END

NextID    LONG(0)
FilePos   LONG(0)
LastErr   LONG(0)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    ODBCOpen(),LONG,C,NAME('ODBCOpen'),EXPORT
    ODBCClose(),LONG,C,NAME('ODBCClose'),EXPORT
    ODBCAddReading(LONG,LONG,LONG),LONG,C,NAME('ODBCAddReading'),EXPORT
    ODBCGetReading(LONG,LONG),LONG,C,NAME('ODBCGetReading'),EXPORT
    ODBCCountReadings(),LONG,C,NAME('ODBCCountReadings'),EXPORT
    ODBCDeleteAll(),LONG,C,NAME('ODBCDeleteAll'),EXPORT
    ODBCGetLastError(),LONG,C,NAME('ODBCGetLastError'),EXPORT
  END

ODBCOpen PROCEDURE()
  CODE
  OPEN(SensorReadings)
  LastErr = ERRORCODE()
  IF LastErr
    CREATE(SensorReadings)
    LastErr = ERRORCODE()
    IF LastErr THEN RETURN -2.
    OPEN(SensorReadings)
    LastErr = ERRORCODE()
    IF LastErr THEN RETURN -3.
  END
  NextID = 0
  SET(SensorReadings)
  LOOP
    NEXT(SensorReadings)
    IF ERRORCODE() THEN BREAK.
    IF SR:ReadingID >= NextID
      NextID = SR:ReadingID
    END
  END
  NextID += 1
  RETURN 0

ODBCClose PROCEDURE()
  CODE
  CLOSE(SensorReadings)
  RETURN 0

ODBCAddReading PROCEDURE(LONG sensorID, LONG value, LONG weight)
  CODE
  CLEAR(SR:Record)
  SR:ReadingID = NextID
  NextID += 1
  SR:SensorID = sensorID
  SR:Value = value
  SR:Weight = weight
  SR:Timestamp = TODAY()
  ADD(SensorReadings)
  IF ERRORCODE() THEN RETURN -2.
  RETURN SR:ReadingID

ODBCGetReading PROCEDURE(LONG id, LONG bufPtr)
  CODE
  SET(SensorReadings)
  LOOP
    NEXT(SensorReadings)
    IF ERRORCODE() THEN RETURN -1.
    IF SR:ReadingID = id
      RB:ReadingID = SR:ReadingID
      RB:SensorID = SR:SensorID
      RB:Value = SR:Value
      RB:Weight = SR:Weight
      RB:Timestamp = SR:Timestamp
      MemCopy(bufPtr, ADDRESS(ReadBuf), SIZE(ReadBuf))
      RETURN 0
    END
  END
  RETURN -1

ODBCCountReadings PROCEDURE()
Count  LONG(0)
  CODE
  SET(SensorReadings)
  LOOP
    NEXT(SensorReadings)
    IF ERRORCODE() THEN BREAK.
    Count += 1
  END
  RETURN Count

ODBCDeleteAll PROCEDURE()
  CODE
  SET(SensorReadings)
  LOOP
    NEXT(SensorReadings)
    IF ERRORCODE() THEN BREAK.
    DELETE(SensorReadings)
    IF ERRORCODE() THEN BREAK.
  END
  RETURN 0

ODBCGetLastError PROCEDURE()
  CODE
  RETURN LastErr
