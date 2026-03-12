  MEMBER()
StationFile FILE,DRIVER('DOS'),NAME('Stations.dat'),CREATE,PRE(ST)
Record      RECORD
Number        LONG
Name          STRING(30)
Phone         STRING(20)
CommPort      BYTE
BaudRate      LONG
AutoInterval  LONG
            END
          END

PictureFile FILE,DRIVER('DOS'),NAME('Pictures.dat'),CREATE,PRE(PIC)
Record      RECORD
FileName      STRING(12)
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
            END
          END

StBuf GROUP,PRE(SB)
Number        LONG
Name          STRING(30)
Phone         STRING(20)
CommPort      BYTE
BaudRate      LONG
AutoInterval  LONG
      END

PicTemp   FILE,DRIVER('DOS'),NAME('PicTemp.dat'),CREATE,PRE(PT)
Record      RECORD
FileName      STRING(12)
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
            END
          END

PicBuf GROUP,PRE(PB)
FileName      STRING(12)
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
       END

ParamBuf GROUP,PRE(PM)
Tilt          LONG
Range         LONG
Gain          LONG
         END

CurTilt    BYTE(0)
CurRange   BYTE(0)
CurGain    BYTE(1)
CurMode    BYTE(0)
CurStation LONG(0)
PicCount   LONG(0)
StCount    LONG(0)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    RLOpen(),LONG,C,NAME('RLOpen'),EXPORT
    RLClose(),LONG,C,NAME('RLClose'),EXPORT
    RLAddStation(LONG number, LONG namePtr, LONG nameLen, LONG phonePtr, LONG phoneLen, LONG commPort, LONG baudRate, LONG autoInterval),LONG,C,NAME('RLAddStation'),EXPORT
    RLGetStation(LONG index, LONG bufPtr),LONG,C,NAME('RLGetStation'),EXPORT
    RLGetStationCount(),LONG,C,NAME('RLGetStationCount'),EXPORT
    RLSelectStation(LONG index),LONG,C,NAME('RLSelectStation'),EXPORT
    RLSetParams(LONG tilt, LONG range, LONG gain),LONG,C,NAME('RLSetParams'),EXPORT
    RLGetParams(LONG bufPtr),LONG,C,NAME('RLGetParams'),EXPORT
    RLSetMode(LONG mode),LONG,C,NAME('RLSetMode'),EXPORT
    RLGetMode(),LONG,C,NAME('RLGetMode'),EXPORT
    RLAddPicture(LONG namePtr, LONG nameLen, LONG year, LONG month, LONG day, LONG hour, LONG minute, LONG tilt, LONG range, LONG gain),LONG,C,NAME('RLAddPicture'),EXPORT
    RLGetPicture(LONG index, LONG bufPtr),LONG,C,NAME('RLGetPicture'),EXPORT
    RLGetPictureCount(),LONG,C,NAME('RLGetPictureCount'),EXPORT
    RLDeletePicture(LONG index),LONG,C,NAME('RLDeletePicture'),EXPORT
    RLRangeToKm(LONG rangeCode),LONG,C,NAME('RLRangeToKm'),EXPORT
  END

RLOpen PROCEDURE()
  CODE
  OPEN(StationFile)
  IF ERRORCODE()
    CREATE(StationFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(StationFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  OPEN(PictureFile)
  IF ERRORCODE()
    CREATE(PictureFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(PictureFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  ! Count existing stations
  StCount = 0
  SET(StationFile)
  LOOP
    NEXT(StationFile)
    IF ERRORCODE() THEN BREAK.
    StCount += 1
  END
  ! Count existing pictures
  PicCount = 0
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    IF ERRORCODE() THEN BREAK.
    PicCount += 1
  END
  CurTilt = 0
  CurRange = 0
  CurGain = 1
  CurMode = 0
  CurStation = 0
  RETURN 0

RLClose PROCEDURE()
  CODE
  CLOSE(StationFile)
  CLOSE(PictureFile)
  RETURN 0

RLAddStation PROCEDURE(LONG number, LONG namePtr, LONG nameLen, LONG phonePtr, LONG phoneLen, LONG commPort, LONG baudRate, LONG autoInterval)
  CODE
  CLEAR(ST:Record)
  ST:Number = number
  IF nameLen > 30 THEN nameLen = 30.
  IF nameLen > 0
    MemCopy(ADDRESS(ST:Name), namePtr, nameLen)
  END
  IF phoneLen > 20 THEN phoneLen = 20.
  IF phoneLen > 0
    MemCopy(ADDRESS(ST:Phone), phonePtr, phoneLen)
  END
  ST:CommPort = commPort
  ST:BaudRate = baudRate
  ST:AutoInterval = autoInterval
  ADD(StationFile)
  IF ERRORCODE() THEN RETURN -1.
  StCount += 1
  RETURN 0

RLGetStation PROCEDURE(LONG index, LONG bufPtr)
Cnt LONG(0)
  CODE
  SET(StationFile)
  LOOP
    NEXT(StationFile)
    IF ERRORCODE() THEN RETURN -1.
    Cnt += 1
    IF Cnt = index
      SB:Number = ST:Number
      SB:Name = ST:Name
      SB:Phone = ST:Phone
      SB:CommPort = ST:CommPort
      SB:BaudRate = ST:BaudRate
      SB:AutoInterval = ST:AutoInterval
      MemCopy(bufPtr, ADDRESS(StBuf), SIZE(StBuf))
      RETURN 0
    END
  END
  RETURN -1

RLGetStationCount PROCEDURE()
  CODE
  RETURN StCount

RLSelectStation PROCEDURE(LONG index)
  CODE
  IF index < 1 OR index > StCount THEN RETURN -1.
  CurStation = index
  RETURN 0

RLSetParams PROCEDURE(LONG tilt, LONG range, LONG gain)
  CODE
  IF tilt < 0 OR tilt > 11 THEN RETURN -1.
  IF range < 0 OR range > 4 THEN RETURN -1.
  IF gain < 1 OR gain > 17 THEN RETURN -1.
  CurTilt = tilt
  CurRange = range
  CurGain = gain
  RETURN 0

RLGetParams PROCEDURE(LONG bufPtr)
  CODE
  PM:Tilt = CurTilt
  PM:Range = CurRange
  PM:Gain = CurGain
  MemCopy(bufPtr, ADDRESS(ParamBuf), SIZE(ParamBuf))
  RETURN 0

RLSetMode PROCEDURE(LONG mode)
  CODE
  IF mode < 0 OR mode > 3 THEN RETURN -1.
  CurMode = mode
  RETURN 0

RLGetMode PROCEDURE()
  CODE
  RETURN CurMode

RLAddPicture PROCEDURE(LONG namePtr, LONG nameLen, LONG year, LONG month, LONG day, LONG hour, LONG minute, LONG tilt, LONG range, LONG gain)
  CODE
  CLEAR(PIC:Record)
  IF nameLen > 12 THEN nameLen = 12.
  IF nameLen > 0
    MemCopy(ADDRESS(PIC:FileName), namePtr, nameLen)
  END
  PIC:Year = year
  PIC:Month = month
  PIC:Day = day
  PIC:Hour = hour
  PIC:Minute = minute
  PIC:Tilt = tilt
  PIC:Range = range
  PIC:Gain = gain
  ADD(PictureFile)
  IF ERRORCODE() THEN RETURN -1.
  PicCount += 1
  RETURN PicCount

RLGetPicture PROCEDURE(LONG index, LONG bufPtr)
Cnt LONG(0)
  CODE
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    IF ERRORCODE() THEN RETURN -1.
    Cnt += 1
    IF Cnt = index
      PB:FileName = PIC:FileName
      PB:Year = PIC:Year
      PB:Month = PIC:Month
      PB:Day = PIC:Day
      PB:Hour = PIC:Hour
      PB:Minute = PIC:Minute
      PB:Tilt = PIC:Tilt
      PB:Range = PIC:Range
      PB:Gain = PIC:Gain
      MemCopy(bufPtr, ADDRESS(PicBuf), SIZE(PicBuf))
      RETURN 0
    END
  END
  RETURN -1

RLGetPictureCount PROCEDURE()
  CODE
  RETURN PicCount

RLDeletePicture PROCEDURE(LONG index)
Cnt LONG(0)
  CODE
  IF index < 1 OR index > PicCount THEN RETURN -1.
  ! DOS driver does not support DELETE; copy all except target to temp file
  CREATE(PicTemp)
  OPEN(PicTemp)
  IF ERRORCODE() THEN RETURN -1.
  Cnt = 0
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    IF ERRORCODE() THEN BREAK.
    Cnt += 1
    IF Cnt <> index
      CLEAR(PT:Record)
      PT:FileName = PIC:FileName
      PT:Year = PIC:Year
      PT:Month = PIC:Month
      PT:Day = PIC:Day
      PT:Hour = PIC:Hour
      PT:Minute = PIC:Minute
      PT:Tilt = PIC:Tilt
      PT:Range = PIC:Range
      PT:Gain = PIC:Gain
      ADD(PicTemp)
    END
  END
  CLOSE(PicTemp)
  CLOSE(PictureFile)
  REMOVE('Pictures.dat')
  RENAME('PicTemp.dat','Pictures.dat')
  OPEN(PictureFile)
  PicCount -= 1
  RETURN 0

RLRangeToKm PROCEDURE(LONG rangeCode)
  CODE
  CASE rangeCode
  OF 0
    RETURN 25
  OF 1
    RETURN 50
  OF 2
    RETURN 100
  OF 3
    RETURN 200
  OF 4
    RETURN 400
  END
  RETURN -1
