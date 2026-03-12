  MEMBER()
! ============================================================================
! FuelLib.clw — Fuel Inventory Manager (FIM) DLL
!
! Clarion 11.1 translation of the SSM Fuel Inventory Manager module.
! Original Turbo Pascal 3.0 source by Derek G. Lane, 1985-1996.
!
! This file uses variant casing to demonstrate Clarion's case-insensitivity:
!   - Uppercase: MEMBER, FILE, DRIVER, RECORD, MAP, MODULE, EXPORT
!   - Mixed: Procedure, Code, Return, If...Then, Loop, Set, Next
!   - Some lowercase variables alongside PascalCase
!
! Original Pascal (SSM FIM, D.G.Lane 1985):
!   type TransRec = record
!     date        : DateRec;
!     description : string[40];
!     amount      : real;
!     balance     : real;
!   end;
!
!   TransList = array [0..650] of TransRec;
!
! The Pascal version stored transactions in a typed array with sorted
! insertion by date. Our Clarion version uses sequential DOS flat files
! with BYTE/SHORT date fields and LONG integer cents for amounts.
! ============================================================================

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

! ============================================================================
! FLOpen — Open transaction and price files, creating if needed
! ============================================================================
FLOpen Procedure()
  Code
  OPEN(TransFile)
  If ERRORCODE()
    CREATE(TransFile)
    If ERRORCODE() Then Return -1.
    OPEN(TransFile)
    If ERRORCODE() Then Return -1.
  END
  OPEN(PriceFile)
  If ERRORCODE()
    CREATE(PriceFile)
    If ERRORCODE() Then Return -1.
    OPEN(PriceFile)
    If ERRORCODE() Then Return -1.
  END
  Return 0

! ============================================================================
! FLClose — Close all open files
! ============================================================================
FLClose Procedure()
  Code
  CLOSE(TransFile)
  CLOSE(PriceFile)
  Return 0

! ============================================================================
! FLSetPrice — Set or update fuel price by type (1=Regular..4=Diesel)
! ============================================================================
FLSetPrice Procedure(LONG fuelType, LONG priceInCents)
found LONG(0)
  Code
  If fuelType < 1 OR fuelType > 4 Then Return -1.
  Set(PriceFile)
  Loop
    Next(PriceFile)
    If ERRORCODE() Then BREAK.
    If PR:FuelType = fuelType
      PR:PricePerGal = priceInCents
      PUT(PriceFile)
      If ERRORCODE() Then Return -1.
      found = 1
      BREAK
    END
  END
  If found = 0
    CLEAR(PR:Record)
    PR:FuelType = fuelType
    PR:PricePerGal = priceInCents
    ADD(PriceFile)
    If ERRORCODE() Then Return -1.
  END
  Return 0

! ============================================================================
! FLGetPrice — Retrieve fuel price by type
! ============================================================================
FLGetPrice Procedure(LONG fuelType)
  Code
  If fuelType < 1 OR fuelType > 4 Then Return -1.
  Set(PriceFile)
  Loop
    Next(PriceFile)
    If ERRORCODE() Then BREAK.
    If PR:FuelType = fuelType
      Return PR:PricePerGal
    END
  END
  Return -1

! ============================================================================
! FLAddTransaction — Append a new transaction, compute running balance
!
! Original Pascal: procedure AddTrans;
!   { Inserts transaction in date-sorted order, maintains chronological sequence }
!   { Our Clarion version appends sequentially instead of sorted insertion }
! ============================================================================
FLAddTransaction Procedure(LONG month, LONG day, LONG year, LONG hour, LONG minute, LONG descPtr, LONG descLen, LONG amountCents)
lastBalance LONG(0)
copyLen     LONG(0)
  Code
  ! Get the last balance
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    lastBalance = TR:Balance
  END
  CLEAR(TR:Record)
  TR:Month = month
  TR:Day = day
  TR:Year = year
  TR:Hour = hour
  TR:Minute = minute
  ! Copy description from pointer
  copyLen = descLen
  If copyLen > 40 Then copyLen = 40.
  If descPtr <> 0 AND copyLen > 0
    MemCopy(ADDRESS(TR:Description), descPtr, copyLen)
  END
  TR:Amount = amountCents
  TR:Balance = lastBalance + amountCents
  ADD(TransFile)
  If ERRORCODE() Then Return -1.
  Return TR:Balance

! ============================================================================
! FLGetTransaction — Retrieve transaction by 1-based index into caller buffer
! ============================================================================
FLGetTransaction Procedure(LONG index, LONG bufPtr)
pos LONG(0)
  Code
  If index < 1 Then Return -1.
  pos = ((index - 1) * SIZE(TR:Record)) + 1
  GET(TransFile, pos)
  If ERRORCODE() Then Return -1.
  TB:Month = TR:Month
  TB:Day = TR:Day
  TB:Year = TR:Year
  TB:Hour = TR:Hour
  TB:Minute = TR:Minute
  TB:Description = TR:Description
  TB:Amount = TR:Amount
  TB:Balance = TR:Balance
  MemCopy(bufPtr, ADDRESS(TransBuf), SIZE(TransBuf))
  Return 0

! ============================================================================
! FLGetTransactionCount — Count records by sequential scan
! ============================================================================
FLGetTransactionCount Procedure()
count LONG(0)
  Code
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    count += 1
  END
  Return count

! ============================================================================
! FLGetBalance — Return the last transaction's running balance
!
! Original Pascal: procedure UpdateAcct;
!   { Runs backward through transaction list }
!   { Accumulates debt by transaction amount }
!   { Marks when debt exceeds 30-day and 60-day thresholds }
!   { Our version walks forward and recalculates running balance }
! ============================================================================
FLGetBalance Procedure()
lastBalance LONG(0)
found       LONG(0)
  Code
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    lastBalance = TR:Balance
    found = 1
  END
  If found = 0 Then Return 0.
  Return lastBalance

! ============================================================================
! FLDeleteTransaction — Delete by index using copy-skip-rename pattern
!
! Note: Clarion DOS driver does not support DELETE on flat files.
! We use a copy-skip-rename pattern: copy all records except the
! target to a temp file, then replace the original.
! Original Pascal used BlockRead/BlockWrite for similar file manipulation.
! ============================================================================
FLDeleteTransaction Procedure(LONG index)
recCount LONG(0)
curRec   LONG(0)
runBal   LONG(0)
  Code
  If index < 1 Then Return -1.
  ! Count records
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    recCount += 1
  END
  If index > recCount Then Return -1.
  ! Copy all records except deleted one to temp file with recalculated balances
  CREATE(TempFile)
  OPEN(TempFile)
  If ERRORCODE() Then Return -1.
  runBal = 0
  curRec = 0
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    curRec += 1
    If curRec <> index
      CLEAR(TF:Record)
      TF:Month = TR:Month
      TF:Day = TR:Day
      TF:Year = TR:Year
      TF:Hour = TR:Hour
      TF:Minute = TR:Minute
      TF:Description = TR:Description
      TF:Amount = TR:Amount
      runBal += TR:Amount
      TF:Balance = runBal
      ADD(TempFile)
    END
  END
  CLOSE(TempFile)
  ! Replace original with temp
  CLOSE(TransFile)
  REMOVE('FuelTrans.dat')
  RENAME('FuelTemp.dat','FuelTrans.dat')
  OPEN(TransFile)
  Return 0

! ============================================================================
! FLRecalcBalances — Walk all records forward, recompute running balance
!
! Original Pascal: procedure UpdateAcct;
!   { Runs backward through transaction list }
!   { Accumulates debt by transaction amount }
!   { Marks when debt exceeds 30-day and 60-day thresholds }
!   { Our version walks forward and recalculates running balance }
! ============================================================================
FLRecalcBalances Procedure()
runBal   LONG(0)
recCount LONG(0)
i        LONG(0)
pos      LONG(0)
  Code
  ! Count records
  Set(TransFile)
  Loop
    Next(TransFile)
    If ERRORCODE() Then BREAK.
    recCount += 1
  END
  ! Walk by index and recalc
  i = 1
  Loop While i <= recCount
    pos = ((i - 1) * SIZE(TR:Record)) + 1
    GET(TransFile, pos)
    If ERRORCODE() Then BREAK.
    runBal += TR:Amount
    TR:Balance = runBal
    PUT(TransFile)
    i += 1
  END
  Return runBal
