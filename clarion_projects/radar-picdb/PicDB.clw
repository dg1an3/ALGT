  MEMBER()

! ============================================================================
! PicDB.clw -- Picture Database Management DLL
!
! Translated from E300DB radar system Modula-2 source:
!   Pictures.DEF / Pictures.MOD
!
! Original Modula-2 types:
!   PicFlag = (NotSaved, BeingDownLoaded)
!   PicFlagSet = SET OF PicFlag
!   PictureRec = RECORD
!     Tilt: TiltType;      {0..11}
!     Range: RangeType;    {0..4}
!     Gain: GainType;      {1..17}
!     TimeofPic: Time;     {day, minute fields}
!     Purge: CARDINAL;
!     Flags: PicFlagSet;
!     Size: CARDINAL;
!     Data: pointer;
!   END;
!
! Original procedures translated:
!   FileName()      -> PDEncodeFileName
!   FileParam()     -> PDDecodeFileName
!   AddPicture()    -> PDAddPicture   (sorted insertion by timestamp)
!   DeletePicture() -> PDDeletePicture (copy-skip-rename for DOS driver)
!
! Uses variant casing to demonstrate Clarion's case-insensitivity.
! ============================================================================

PicFile   FILE,DRIVER('DOS'),NAME('PicDB.dat'),CREATE,PRE(PF)
Record      RECORD
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
DataSize      LONG
FileName      STRING(12)
            END
          END

TempFile  FILE,DRIVER('DOS'),NAME('PicDB.tmp'),CREATE,PRE(TF)
Record      RECORD
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
DataSize      LONG
FileName      STRING(12)
            END
          END

PicBuf    GROUP,PRE(PB)
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
DataSize      LONG
FileName      STRING(12)
          END

! Decode output buffer: year(SHORT), month, day, hour, minute, tilt, range, gain
DecodeBuf GROUP,PRE(DC)
Year          SHORT
Month         BYTE
Day           BYTE
Hour          BYTE
Minute        BYTE
Tilt          BYTE
Range         BYTE
Gain          BYTE
          END

RecCount  LONG(0)
RecSize   LONG(0)
FileOpen  LONG(0)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    CountRecords(),LONG,PRIVATE
    CompareTime(SHORT y1, BYTE m1, BYTE d1, BYTE h1, BYTE mn1, |
                SHORT y2, BYTE m2, BYTE d2, BYTE h2, BYTE mn2),LONG,PRIVATE
    BuildFileName(BYTE hour, BYTE minute, BYTE tilt, BYTE range, BYTE gain, *STRING result),PRIVATE
    pdOpen(),LONG,C,NAME('PDOpen'),EXPORT
    pdClose(),LONG,C,NAME('PDClose'),EXPORT
    pdAddPicture(LONG yr, LONG mo, LONG dy, LONG hr, LONG mn, |
                 LONG tilt, LONG rng, LONG gain, LONG dataSize),LONG,C,NAME('PDAddPicture'),EXPORT
    pdGetPicture(LONG idx, LONG bufPtr),LONG,C,NAME('PDGetPicture'),EXPORT
    pdGetPictureCount(),LONG,C,NAME('PDGetPictureCount'),EXPORT
    pdDeletePicture(LONG idx),LONG,C,NAME('PDDeletePicture'),EXPORT
    pdEncodeFileName(LONG hr, LONG mn, LONG tilt, LONG rng, LONG gain, LONG bufPtr),LONG,C,NAME('PDEncodeFileName'),EXPORT
    pdDecodeFileName(LONG namePtr, LONG nameLen, LONG bufPtr),LONG,C,NAME('PDDecodeFileName'),EXPORT
    pdFindByParams(LONG tilt, LONG rng),LONG,C,NAME('PDFindByParams'),EXPORT
  END

! --------------------------------------------------------------------------
! CountRecords -- count total records in PicFile via sequential scan
! --------------------------------------------------------------------------
CountRecords PROCEDURE()
cnt LONG(0)
  CODE
  SET(PicFile)
  LOOP
    NEXT(PicFile)
    IF ERRORCODE() THEN BREAK.
    cnt += 1
  END
  RETURN cnt

! --------------------------------------------------------------------------
! CompareTime -- compare two timestamps
! Returns -1 if first < second, 0 if equal, 1 if first > second
! Used for sorted insertion (original Pictures.MOD AddPicture logic)
! --------------------------------------------------------------------------
CompareTime PROCEDURE(SHORT y1, BYTE m1, BYTE d1, BYTE h1, BYTE mn1, |
                       SHORT y2, BYTE m2, BYTE d2, BYTE h2, BYTE mn2)
  CODE
  IF y1 < y2 THEN RETURN -1.
  IF y1 > y2 THEN RETURN 1.
  IF m1 < m2 THEN RETURN -1.
  IF m1 > m2 THEN RETURN 1.
  IF d1 < d2 THEN RETURN -1.
  IF d1 > d2 THEN RETURN 1.
  IF h1 < h2 THEN RETURN -1.
  IF h1 > h2 THEN RETURN 1.
  IF mn1 < mn2 THEN RETURN -1.
  IF mn1 > mn2 THEN RETURN 1.
  RETURN 0

! --------------------------------------------------------------------------
! BuildFileName -- encode radar params into filename
! Original Modula-2 (Pictures.MOD):
!   PROCEDURE FileName(Picture: PictureRec; VAR NameofFile: ARRAY OF CHAR);
!   Encodes: HHMM + CHR(65+Tilt) + CHR(65+Range) + CHR(64+Gain) + '.WX'
! --------------------------------------------------------------------------
BuildFileName PROCEDURE(BYTE hour, BYTE minute, BYTE tilt, BYTE range, BYTE gain, *STRING result)
HourStr   STRING(2)
MinStr    STRING(2)
TiltChar  STRING(1)
RangeChar STRING(1)
GainChar  STRING(1)
  CODE
  ! Format hour as 2-digit string with leading zero
  IF hour < 10
    HourStr = '0' & SUB(hour, 1, 1)
  ELSE
    HourStr = SUB(hour, 1, 2)
  END
  ! Format minute as 2-digit string with leading zero
  IF minute < 10
    MinStr = '0' & SUB(minute, 1, 1)
  ELSE
    MinStr = SUB(minute, 1, 2)
  END
  ! Tilt char: CHR(65+Tilt) -- 0='A', 1='B', ... 11='L'
  TiltChar = CHR(65 + tilt)
  ! Range char: CHR(65+Range) -- 0='A', 1='B', ... 4='E'
  RangeChar = CHR(65 + range)
  ! Gain char: CHR(64+Gain) -- 1='A', 2='B', ... 17='Q'
  GainChar = CHR(64 + gain)
  result = HourStr & MinStr & TiltChar & RangeChar & GainChar & '.WX'

! --------------------------------------------------------------------------
! PDOpen -- open or create picture database
! --------------------------------------------------------------------------
pdOpen PROCEDURE()
  CODE
  IF FileOpen = 1 THEN RETURN 0.
  OPEN(PicFile)
  IF ERRORCODE()
    CREATE(PicFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(PicFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  RecSize = SIZE(PF:Record)
  FileOpen = 1
  RETURN 0

! --------------------------------------------------------------------------
! PDClose -- close picture database
! --------------------------------------------------------------------------
pdClose PROCEDURE()
  CODE
  IF FileOpen = 0 THEN RETURN 0.
  CLOSE(PicFile)
  FileOpen = 0
  RETURN 0

! --------------------------------------------------------------------------
! PDAddPicture -- add picture in chronological order (sorted insertion)
!
! Original Modula-2 (Pictures.MOD):
!   PROCEDURE AddPicture(VAR PicList; VAR MaxPic; ForPicture; VAR Number);
!   {Insert in chronological order by timestamp}
!
! Strategy: scan for insertion point, then use TempFile to rebuild
! with new record inserted at correct position.
! Validates: tilt 0-11, range 0-4, gain 1-17
! --------------------------------------------------------------------------
pdAddPicture PROCEDURE(LONG yr, LONG mo, LONG dy, LONG hr, LONG mn, |
                        LONG tilt, LONG rng, LONG gain, LONG dataSize)
InsertPos  LONG(0)
CurPos     LONG(0)
TotalRecs  LONG(0)
CmpResult  LONG(0)
BytePos    LONG(0)
Inserted   LONG(0)
FName      STRING(12)
  CODE
  ! Validate parameters
  IF tilt < 0 OR tilt > 11 THEN RETURN -1.
  IF rng < 0 OR rng > 4 THEN RETURN -1.
  IF gain < 1 OR gain > 17 THEN RETURN -1.
  IF FileOpen = 0 THEN RETURN -1.

  TotalRecs = CountRecords()

  ! Build the filename for this picture
  BuildFileName(hr, mn, tilt, rng, gain, FName)

  ! Find insertion point: scan records, find first with timestamp > new
  InsertPos = TotalRecs + 1  ! default: append at end
  CurPos = 1
  LOOP WHILE CurPos <= TotalRecs
    BytePos = ((CurPos - 1) * RecSize) + 1
    GET(PicFile, BytePos)
    IF ERRORCODE() THEN BREAK.
    CmpResult = CompareTime(yr, mo, dy, hr, mn, |
                            PF:Year, PF:Month, PF:Day, PF:Hour, PF:Minute)
    IF CmpResult < 0
      InsertPos = CurPos
      BREAK
    END
    CurPos += 1
  END

  ! If appending at end and no records need shifting, just ADD
  IF InsertPos > TotalRecs
    CLEAR(PF:Record)
    PF:Year = yr
    PF:Month = mo
    PF:Day = dy
    PF:Hour = hr
    PF:Minute = mn
    PF:Tilt = tilt
    PF:Range = rng
    PF:Gain = gain
    PF:DataSize = dataSize
    PF:FileName = FName
    ADD(PicFile)
    IF ERRORCODE() THEN RETURN -1.
    RETURN InsertPos
  END

  ! Need to insert in middle: use TempFile for copy-insert
  CREATE(TempFile)
  IF ERRORCODE() THEN RETURN -1.
  OPEN(TempFile)
  IF ERRORCODE() THEN RETURN -1.

  Inserted = 0
  CurPos = 1
  LOOP WHILE CurPos <= TotalRecs
    ! Insert new record at InsertPos
    IF CurPos = InsertPos AND Inserted = 0
      CLEAR(TF:Record)
      TF:Year = yr
      TF:Month = mo
      TF:Day = dy
      TF:Hour = hr
      TF:Minute = mn
      TF:Tilt = tilt
      TF:Range = rng
      TF:Gain = gain
      TF:DataSize = dataSize
      TF:FileName = FName
      ADD(TempFile)
      IF ERRORCODE()
        CLOSE(TempFile)
        REMOVE(TempFile)
        RETURN -1
      END
      Inserted = 1
    END
    ! Copy existing record
    BytePos = ((CurPos - 1) * RecSize) + 1
    GET(PicFile, BytePos)
    IF ERRORCODE() THEN BREAK.
    CLEAR(TF:Record)
    TF:Year = PF:Year
    TF:Month = PF:Month
    TF:Day = PF:Day
    TF:Hour = PF:Hour
    TF:Minute = PF:Minute
    TF:Tilt = PF:Tilt
    TF:Range = PF:Range
    TF:Gain = PF:Gain
    TF:DataSize = PF:DataSize
    TF:FileName = PF:FileName
    ADD(TempFile)
    IF ERRORCODE()
      CLOSE(TempFile)
      REMOVE(TempFile)
      RETURN -1
    END
    CurPos += 1
  END

  ! Close both, remove original, rename temp
  CLOSE(PicFile)
  CLOSE(TempFile)
  REMOVE(PicFile)
  RENAME(TempFile, 'PicDB.dat')
  OPEN(PicFile)
  IF ERRORCODE() THEN RETURN -1.
  RETURN InsertPos

! --------------------------------------------------------------------------
! PDGetPicture -- get picture metadata by 1-based index
! Copies record fields into caller buffer via MemCopy
! --------------------------------------------------------------------------
pdGetPicture PROCEDURE(LONG idx, LONG bufPtr)
BytePos LONG(0)
  CODE
  IF FileOpen = 0 THEN RETURN -1.
  IF idx < 1 THEN RETURN -1.
  BytePos = ((idx - 1) * RecSize) + 1
  GET(PicFile, BytePos)
  IF ERRORCODE() THEN RETURN -1.
  PB:Year = PF:Year
  PB:Month = PF:Month
  PB:Day = PF:Day
  PB:Hour = PF:Hour
  PB:Minute = PF:Minute
  PB:Tilt = PF:Tilt
  PB:Range = PF:Range
  PB:Gain = PF:Gain
  PB:DataSize = PF:DataSize
  PB:FileName = PF:FileName
  MemCopy(bufPtr, ADDRESS(PicBuf), SIZE(PicBuf))
  RETURN 0

! --------------------------------------------------------------------------
! PDGetPictureCount -- return number of records in database
! --------------------------------------------------------------------------
pdGetPictureCount PROCEDURE()
  CODE
  IF FileOpen = 0 THEN RETURN -1.
  RETURN CountRecords()

! --------------------------------------------------------------------------
! PDDeletePicture -- delete record by 1-based index
!
! Original Modula-2 (Pictures.MOD):
!   PROCEDURE DeletePicture(VAR PicList; VAR MaxPic; PictureNum);
!   {Delete by index, shift remaining down}
!
! DOS driver does not support DELETE, so we use copy-skip-rename pattern:
!   1. Create TempFile
!   2. Copy all records except the one at idx
!   3. Remove original, rename temp
! --------------------------------------------------------------------------
pdDeletePicture PROCEDURE(LONG idx)
TotalRecs LONG(0)
CurPos    LONG(0)
bytePos   LONG(0)
  CODE
  IF FileOpen = 0 THEN RETURN -1.
  TotalRecs = CountRecords()
  IF idx < 1 OR idx > TotalRecs THEN RETURN -1.

  CREATE(TempFile)
  IF ERRORCODE() THEN RETURN -1.
  OPEN(TempFile)
  IF ERRORCODE() THEN RETURN -1.

  CurPos = 1
  LOOP WHILE CurPos <= TotalRecs
    IF CurPos <> idx
      bytePos = ((CurPos - 1) * RecSize) + 1
      GET(PicFile, bytePos)
      IF ERRORCODE()
        CLOSE(TempFile)
        REMOVE(TempFile)
        RETURN -1
      END
      CLEAR(TF:Record)
      TF:Year = PF:Year
      TF:Month = PF:Month
      TF:Day = PF:Day
      TF:Hour = PF:Hour
      TF:Minute = PF:Minute
      TF:Tilt = PF:Tilt
      TF:Range = PF:Range
      TF:Gain = PF:Gain
      TF:DataSize = PF:DataSize
      TF:FileName = PF:FileName
      ADD(TempFile)
      IF ERRORCODE()
        CLOSE(TempFile)
        REMOVE(TempFile)
        RETURN -1
      END
    END
    CurPos += 1
  END

  CLOSE(PicFile)
  CLOSE(TempFile)
  REMOVE(PicFile)
  RENAME(TempFile, 'PicDB.dat')
  OPEN(PicFile)
  IF ERRORCODE() THEN RETURN -1.
  RETURN 0

! --------------------------------------------------------------------------
! PDEncodeFileName -- encode radar params to filename string
!
! Original Modula-2 (Pictures.MOD):
!   PROCEDURE FileName(Picture: PictureRec; VAR NameofFile: ARRAY OF CHAR);
!   Encodes: HHMM + CHR(65+Tilt) + CHR(65+Range) + CHR(64+Gain) + '.WX'
!
! Example: hour=14, min=30, tilt=3, range=1, gain=5 -> "1430DBE.WX "
! Returns string length (always 10 for "HHMMDBE.WX")
! --------------------------------------------------------------------------
pdEncodeFileName PROCEDURE(LONG hr, LONG mn, LONG tilt, LONG rng, LONG gain, LONG bufPtr)
FName STRING(12)
FLen  LONG(0)
  CODE
  IF tilt < 0 OR tilt > 11 THEN RETURN -1.
  IF rng < 0 OR rng > 4 THEN RETURN -1.
  IF gain < 1 OR gain > 17 THEN RETURN -1.
  BuildFileName(hr, mn, tilt, rng, gain, FName)
  FLen = LEN(CLIP(FName))
  MemCopy(bufPtr, ADDRESS(FName), 12)
  RETURN FLen

! --------------------------------------------------------------------------
! PDDecodeFileName -- decode filename back to picture params
!
! Original Modula-2 (Pictures.MOD):
!   PROCEDURE FileParam(VAR Picture: PictureRec; NameofFile: ARRAY OF CHAR;
!                        VAR OK: BOOLEAN);
!   {Decodes filename back into picture params}
!
! Input: filename string like "1430DBE.WX"
! Output buffer: year(0), month(0), day(0), hour, minute, tilt, range, gain
! Returns 0 on success, -1 on error
! --------------------------------------------------------------------------
pdDecodeFileName PROCEDURE(LONG namePtr, LONG nameLen, LONG bufPtr)
NameStr  STRING(12)
HrStr    STRING(2)
MnStr    STRING(2)
  CODE
  IF nameLen < 7 THEN RETURN -1.
  MemCopy(ADDRESS(NameStr), namePtr, nameLen)

  ! Extract hour from positions 1-2
  HrStr = SUB(NameStr, 1, 2)
  ! Extract minute from positions 3-4
  MnStr = SUB(NameStr, 3, 2)

  CLEAR(DecodeBuf)
  DC:Year = 0
  DC:Month = 0
  DC:Day = 0
  DC:Hour = HrStr
  DC:Minute = MnStr
  ! Tilt = VAL(char at pos 5) - 65
  DC:Tilt = VAL(SUB(NameStr, 5, 1)) - 65
  ! Range = VAL(char at pos 6) - 65
  DC:Range = VAL(SUB(NameStr, 6, 1)) - 65
  ! Gain = VAL(char at pos 7) - 64
  DC:Gain = VAL(SUB(NameStr, 7, 1)) - 64

  ! Validate decoded values
  IF DC:Tilt < 0 OR DC:Tilt > 11 THEN RETURN -1.
  IF DC:Range < 0 OR DC:Range > 4 THEN RETURN -1.
  IF DC:Gain < 1 OR DC:Gain > 17 THEN RETURN -1.

  MemCopy(bufPtr, ADDRESS(DecodeBuf), SIZE(DecodeBuf))
  RETURN 0

! --------------------------------------------------------------------------
! PDFindByParams -- find first picture matching tilt+range
! Returns 1-based index or -1 if not found
! --------------------------------------------------------------------------
pdFindByParams PROCEDURE(LONG tilt, LONG rng)
CurPos  LONG(0)
TotalRecs LONG(0)
bytePos LONG(0)
  CODE
  IF FileOpen = 0 THEN RETURN -1.
  TotalRecs = CountRecords()
  CurPos = 1
  LOOP WHILE CurPos <= TotalRecs
    bytePos = ((CurPos - 1) * RecSize) + 1
    GET(PicFile, bytePos)
    IF ERRORCODE() THEN BREAK.
    IF PF:Tilt = tilt AND PF:Range = rng
      RETURN CurPos
    END
    CurPos += 1
  END
  RETURN -1
