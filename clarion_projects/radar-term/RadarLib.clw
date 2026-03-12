  MEMBER()
! =============================================================================
! RadarLib.clw — Radar terminal station/picture/parameter management DLL
!
! Original Modula-2 (E250TERM.MOD):
!   PROCEDURE Options;
!   (* Interactive menu: Phone, Comm port, Baud rate, AutoInterval *)
!
! Original Pascal (RADAR.PAS):
!   procedure LoadStation;
!   procedure SelectStation;
!
! Clarion is case-insensitive; this file uses variant casing to demonstrate.
! =============================================================================

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

! Original Pascal (RADAR.PAS):
!   type PicRec = record
!     FileName: string[12];
!     FileDate, FileTime: integer;
!     Time: TimeRec;
!     Tilt: TiltType;
!     Range: RangeType;
!     Gain: GainType;
!   end;
!
!   procedure InsertPic(ForPic: PicRec);
!   { Insert picture into sorted list }

PictureFile FILE,DRIVER('DOS'),NAME('Pictures.dat'),CREATE,PRE(PIC)
record      RECORD
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
baudRate      LONG
autoInterval  LONG
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

! Original Pascal (RADAR.PAS):
!   type TiltType = 0..11;
!        RangeType = 0..4;
!        GainType = 1..17;
!        ModeType = (Modem, Interactive, WaitPic, RxPic, RxGraph);
!
!   procedure SetParams(ForBuf: Gen8Type; var Params: ParamType);

ParamBuf GROUP,PRE(PM)
Tilt          LONG
Range         LONG
Gain          LONG
         END

curTilt    BYTE(0)
curRange   BYTE(0)
curGain    BYTE(1)
curMode    BYTE(0)
CurStation LONG(0)
picCount   LONG(0)
stCount    LONG(0)

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

! =============================================================================
! Station management procedures
!
! Original Modula-2 (E250TERM.MOD):
!   PROCEDURE Options;
!   (* Interactive menu: Phone, Comm port, Baud rate, AutoInterval *)
!
! Original Pascal (RADAR.PAS):
!   procedure LoadStation;
!   procedure SelectStation;
! =============================================================================

RLOpen Procedure()
  Code
  OPEN(StationFile)
  If ERRORCODE()
    CREATE(StationFile)
    If ERRORCODE() Then Return -1.
    OPEN(StationFile)
    If ERRORCODE() Then Return -1.
  END
  OPEN(PictureFile)
  If ERRORCODE()
    CREATE(PictureFile)
    If ERRORCODE() Then Return -1.
    OPEN(PictureFile)
    If ERRORCODE() Then Return -1.
  END
  ! Count existing stations
  stCount = 0
  SET(StationFile)
  LOOP
    NEXT(StationFile)
    If ERRORCODE() Then BREAK.
    stCount += 1
  END
  ! Count existing pictures
  picCount = 0
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    If ERRORCODE() Then BREAK.
    picCount += 1
  END
  curTilt = 0
  curRange = 0
  curGain = 1
  curMode = 0
  CurStation = 0
  Return 0

RLClose Procedure()
  Code
  CLOSE(StationFile)
  CLOSE(PictureFile)
  Return 0

RLAddStation Procedure(LONG number, LONG namePtr, LONG nameLen, LONG phonePtr, LONG phoneLen, LONG commPort, LONG baudRate, LONG autoInterval)
  Code
  CLEAR(ST:Record)
  ST:Number = number
  If nameLen > 30 Then nameLen = 30.
  If nameLen > 0
    MemCopy(ADDRESS(ST:Name), namePtr, nameLen)
  END
  If phoneLen > 20 Then phoneLen = 20.
  If phoneLen > 0
    MemCopy(ADDRESS(ST:Phone), phonePtr, phoneLen)
  END
  ST:CommPort = commPort
  ST:BaudRate = baudRate
  ST:AutoInterval = autoInterval
  ADD(StationFile)
  If ERRORCODE() Then Return -1.
  stCount += 1
  Return 0

RLGetStation Procedure(LONG index, LONG bufPtr)
cnt LONG(0)
  Code
  SET(StationFile)
  LOOP
    NEXT(StationFile)
    If ERRORCODE() Then Return -1.
    cnt += 1
    If cnt = index
      SB:Number = ST:Number
      SB:Name = ST:Name
      SB:Phone = ST:Phone
      SB:CommPort = ST:CommPort
      SB:baudRate = ST:BaudRate
      SB:autoInterval = ST:AutoInterval
      MemCopy(bufPtr, ADDRESS(StBuf), SIZE(StBuf))
      Return 0
    END
  END
  Return -1

RLGetStationCount Procedure()
  Code
  Return stCount

RLSelectStation Procedure(LONG index)
  Code
  If index < 1 OR index > stCount Then Return -1.
  CurStation = index
  Return 0

! =============================================================================
! Parameter control procedures
!
! Original Pascal (RADAR.PAS):
!   type TiltType = 0..11;
!        RangeType = 0..4;
!        GainType = 1..17;
!        ModeType = (Modem, Interactive, WaitPic, RxPic, RxGraph);
!
!   procedure SetParams(ForBuf: Gen8Type; var Params: ParamType);
! =============================================================================

RLSetParams Procedure(LONG tilt, LONG range, LONG gain)
  Code
  If tilt < 0 OR tilt > 11 Then Return -1.
  If range < 0 OR range > 4 Then Return -1.
  If gain < 1 OR gain > 17 Then Return -1.
  curTilt = tilt
  curRange = range
  curGain = gain
  Return 0

RLGetParams Procedure(LONG bufPtr)
  Code
  PM:Tilt = curTilt
  PM:Range = curRange
  PM:Gain = curGain
  MemCopy(bufPtr, ADDRESS(ParamBuf), SIZE(ParamBuf))
  Return 0

RLSetMode Procedure(LONG mode)
  Code
  If mode < 0 OR mode > 3 Then Return -1.
  curMode = mode
  Return 0

RLGetMode Procedure()
  Code
  Return curMode

! =============================================================================
! Picture management procedures
!
! Original Pascal (RADAR.PAS):
!   type PicRec = record
!     FileName: string[12];
!     FileDate, FileTime: integer;
!     Time: TimeRec;
!     Tilt: TiltType;
!     Range: RangeType;
!     Gain: GainType;
!   end;
!
!   procedure InsertPic(ForPic: PicRec);
!   { Insert picture into sorted list }
! =============================================================================

RLAddPicture Procedure(LONG namePtr, LONG nameLen, LONG year, LONG month, LONG day, LONG hour, LONG minute, LONG tilt, LONG range, LONG gain)
  Code
  CLEAR(PIC:Record)
  If nameLen > 12 Then nameLen = 12.
  If nameLen > 0
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
  If ERRORCODE() Then Return -1.
  picCount += 1
  Return picCount

RLGetPicture Procedure(LONG index, LONG bufPtr)
cnt LONG(0)
  Code
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    If ERRORCODE() Then Return -1.
    cnt += 1
    If cnt = index
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
      Return 0
    END
  END
  Return -1

RLGetPictureCount Procedure()
  Code
  Return picCount

RLDeletePicture Procedure(LONG index)
cnt LONG(0)
  Code
  If index < 1 OR index > picCount Then Return -1.
  ! DOS driver does not support DELETE; copy all except target to temp file
  CREATE(PicTemp)
  OPEN(PicTemp)
  If ERRORCODE() Then Return -1.
  cnt = 0
  SET(PictureFile)
  LOOP
    NEXT(PictureFile)
    If ERRORCODE() Then BREAK.
    cnt += 1
    If cnt <> index
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
  picCount -= 1
  Return 0

! =============================================================================
! Range conversion
!
! Original: Range codes 0-4 map to 25/50/100/200/400 km radar range
! Used in E250SCRN.MOD WriteRngMks for drawing concentric range circles
! =============================================================================

RLRangeToKm Procedure(LONG rangeCode)
  Code
  Case rangeCode
  Of 0
    Return 25
  Of 1
    Return 50
  Of 2
    Return 100
  Of 3
    Return 200
  Of 4
    Return 400
  END
  Return -1
