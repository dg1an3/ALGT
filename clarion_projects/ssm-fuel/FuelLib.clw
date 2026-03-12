  MEMBER()

TransFile FILE,DRIVER('DOS'),NAME('FuelTrans.dat'),CREATE,PRE(TR)
Record      RECORD
Month         BYTE
Day           BYTE
Year          SHORT
Hour          BYTE
Minute        BYTE
Description   STRING(40)
Amount        LONG
Balance       LONG
            END
          END

TempFile  FILE,DRIVER('DOS'),NAME('FuelTemp.dat'),CREATE,PRE(TF)
Record      RECORD
Month         BYTE
Day           BYTE
Year          SHORT
Hour          BYTE
Minute        BYTE
Description   STRING(40)
Amount        LONG
Balance       LONG
            END
          END

PriceFile FILE,DRIVER('DOS'),NAME('FuelPrice.dat'),CREATE,PRE(PR)
Record      RECORD
FuelType      BYTE
PricePerGal   LONG
            END
          END

TransBuf  GROUP,PRE(TB)
Month         BYTE
Day           BYTE
Year          SHORT
Hour          BYTE
Minute        BYTE
Description   STRING(40)
Amount        LONG
Balance       LONG
          END

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FLOpen(),LONG,C,NAME('FLOpen'),EXPORT
    FLClose(),LONG,C,NAME('FLClose'),EXPORT
    FLSetPrice(LONG fuelType, LONG priceInCents),LONG,C,NAME('FLSetPrice'),EXPORT
    FLGetPrice(LONG fuelType),LONG,C,NAME('FLGetPrice'),EXPORT
    FLAddTransaction(LONG month, LONG day, LONG year, LONG hour, LONG minute, LONG descPtr, LONG descLen, LONG amountCents),LONG,C,NAME('FLAddTransaction'),EXPORT
    FLGetTransaction(LONG index, LONG bufPtr),LONG,C,NAME('FLGetTransaction'),EXPORT
    FLGetTransactionCount(),LONG,C,NAME('FLGetTransactionCount'),EXPORT
    FLGetBalance(),LONG,C,NAME('FLGetBalance'),EXPORT
    FLDeleteTransaction(LONG index),LONG,C,NAME('FLDeleteTransaction'),EXPORT
    FLRecalcBalances(),LONG,C,NAME('FLRecalcBalances'),EXPORT
  END

FLOpen PROCEDURE()
  CODE
  OPEN(TransFile)
  IF ERRORCODE()
    CREATE(TransFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(TransFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  OPEN(PriceFile)
  IF ERRORCODE()
    CREATE(PriceFile)
    IF ERRORCODE() THEN RETURN -1.
    OPEN(PriceFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  RETURN 0

FLClose PROCEDURE()
  CODE
  CLOSE(TransFile)
  CLOSE(PriceFile)
  RETURN 0

FLSetPrice PROCEDURE(LONG fuelType, LONG priceInCents)
Found LONG(0)
  CODE
  IF fuelType < 1 OR fuelType > 4 THEN RETURN -1.
  SET(PriceFile)
  LOOP
    NEXT(PriceFile)
    IF ERRORCODE() THEN BREAK.
    IF PR:FuelType = fuelType
      PR:PricePerGal = priceInCents
      PUT(PriceFile)
      IF ERRORCODE() THEN RETURN -1.
      Found = 1
      BREAK
    END
  END
  IF Found = 0
    CLEAR(PR:Record)
    PR:FuelType = fuelType
    PR:PricePerGal = priceInCents
    ADD(PriceFile)
    IF ERRORCODE() THEN RETURN -1.
  END
  RETURN 0

FLGetPrice PROCEDURE(LONG fuelType)
  CODE
  IF fuelType < 1 OR fuelType > 4 THEN RETURN -1.
  SET(PriceFile)
  LOOP
    NEXT(PriceFile)
    IF ERRORCODE() THEN BREAK.
    IF PR:FuelType = fuelType
      RETURN PR:PricePerGal
    END
  END
  RETURN -1

FLAddTransaction PROCEDURE(LONG month, LONG day, LONG year, LONG hour, LONG minute, LONG descPtr, LONG descLen, LONG amountCents)
LastBalance LONG(0)
CopyLen     LONG(0)
  CODE
  ! Get the last balance
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    LastBalance = TR:Balance
  END
  CLEAR(TR:Record)
  TR:Month = month
  TR:Day = day
  TR:Year = year
  TR:Hour = hour
  TR:Minute = minute
  ! Copy description from pointer
  CopyLen = descLen
  IF CopyLen > 40 THEN CopyLen = 40.
  IF descPtr <> 0 AND CopyLen > 0
    MemCopy(ADDRESS(TR:Description), descPtr, CopyLen)
  END
  TR:Amount = amountCents
  TR:Balance = LastBalance + amountCents
  ADD(TransFile)
  IF ERRORCODE() THEN RETURN -1.
  RETURN TR:Balance

FLGetTransaction PROCEDURE(LONG index, LONG bufPtr)
Pos LONG(0)
  CODE
  IF index < 1 THEN RETURN -1.
  Pos = ((index - 1) * SIZE(TR:Record)) + 1
  GET(TransFile, Pos)
  IF ERRORCODE() THEN RETURN -1.
  TB:Month = TR:Month
  TB:Day = TR:Day
  TB:Year = TR:Year
  TB:Hour = TR:Hour
  TB:Minute = TR:Minute
  TB:Description = TR:Description
  TB:Amount = TR:Amount
  TB:Balance = TR:Balance
  MemCopy(bufPtr, ADDRESS(TransBuf), SIZE(TransBuf))
  RETURN 0

FLGetTransactionCount PROCEDURE()
Count LONG(0)
  CODE
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    Count += 1
  END
  RETURN Count

FLGetBalance PROCEDURE()
LastBalance LONG(0)
Found       LONG(0)
  CODE
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    LastBalance = TR:Balance
    Found = 1
  END
  IF Found = 0 THEN RETURN 0.
  RETURN LastBalance

FLDeleteTransaction PROCEDURE(LONG index)
RecCount LONG(0)
CurRec   LONG(0)
RunBal   LONG(0)
  CODE
  IF index < 1 THEN RETURN -1.
  ! Count records
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    RecCount += 1
  END
  IF index > RecCount THEN RETURN -1.
  ! Copy all records except deleted one to temp file with recalculated balances
  CREATE(TempFile)
  OPEN(TempFile)
  IF ERRORCODE() THEN RETURN -1.
  RunBal = 0
  CurRec = 0
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    CurRec += 1
    IF CurRec <> index
      CLEAR(TF:Record)
      TF:Month = TR:Month
      TF:Day = TR:Day
      TF:Year = TR:Year
      TF:Hour = TR:Hour
      TF:Minute = TR:Minute
      TF:Description = TR:Description
      TF:Amount = TR:Amount
      RunBal += TR:Amount
      TF:Balance = RunBal
      ADD(TempFile)
    END
  END
  CLOSE(TempFile)
  ! Replace original with temp
  CLOSE(TransFile)
  REMOVE('FuelTrans.dat')
  RENAME('FuelTemp.dat','FuelTrans.dat')
  OPEN(TransFile)
  RETURN 0

FLRecalcBalances PROCEDURE()
RunBal   LONG(0)
RecCount LONG(0)
I        LONG(0)
Pos      LONG(0)
  CODE
  ! Count records
  SET(TransFile)
  LOOP
    NEXT(TransFile)
    IF ERRORCODE() THEN BREAK.
    RecCount += 1
  END
  ! Walk by index and recalc
  I = 1
  LOOP WHILE I <= RecCount
    Pos = ((I - 1) * SIZE(TR:Record)) + 1
    GET(TransFile, Pos)
    IF ERRORCODE() THEN BREAK.
    RunBal += TR:Amount
    TR:Balance = RunBal
    PUT(TransFile)
    I += 1
  END
  RETURN RunBal
