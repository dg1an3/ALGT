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

TraceLine   CSTRING(256)
TempCond    LONG(0)
TempResult  LONG(0)
TraceHandle LONG(0)
TraceBW     LONG(0)
TraceCrLf   CSTRING(3)
TraceFileName CSTRING(16)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
      CreateFileA(LONG lpFileName, LONG dwAccess, LONG dwShare, LONG lpSec, LONG dwDisp, LONG dwFlags, LONG hTemplate),LONG,RAW,PASCAL,NAME('CreateFileA')
      WriteFile(LONG hFile, LONG lpBuf, LONG nBytes, LONG lpWritten, LONG lpOverlap),LONG,RAW,PASCAL,NAME('WriteFile')
      CloseHandle(LONG hHandle),LONG,RAW,PASCAL,NAME('CloseHandle')
      lstrlenA(LONG lpString),LONG,RAW,PASCAL,NAME('lstrlenA')
    END
    TraceOpen()
    TraceWrite()
    TraceClose()
    SSOpen(),LONG,C,NAME('SSOpen'),EXPORT
    SSClose(),LONG,C,NAME('SSClose'),EXPORT
    SSAddReading(LONG id, LONG val, LONG w),LONG,C,NAME('SSAddReading'),EXPORT
    SSGetReading(LONG id, LONG bufPtr),LONG,C,NAME('SSGetReading'),EXPORT
    SSCalculateWeightedAverage(),LONG,C,NAME('SSCalculateWeightedAverage'),EXPORT
    SSCleanupLowReadings(LONG threshold),LONG,C,NAME('SSCleanupLowReadings'),EXPORT
  END

TraceOpen PROCEDURE()
  CODE
  TraceFileName = 'trace.log'
  TraceCrLf = '<13,10>'
  TraceHandle = CreateFileA(ADDRESS(TraceFileName), 40000000h, 1, 0, 2, 80h, 0)

TraceWrite PROCEDURE()
  CODE
  IF TraceHandle > 0
    WriteFile(TraceHandle, ADDRESS(TraceLine), lstrlenA(ADDRESS(TraceLine)), ADDRESS(TraceBW), 0)
    WriteFile(TraceHandle, ADDRESS(TraceCrLf), 2, ADDRESS(TraceBW), 0)
  END

TraceClose PROCEDURE()
  CODE
  IF TraceHandle > 0
    CloseHandle(TraceHandle)
    TraceHandle = 0
  END

SSOpen PROCEDURE()
  CODE
  TraceOpen()
  TraceLine = 'CALL SSOpen()'
  TraceWrite()
  TraceLine = '  SSOpen: call OPEN'
  TraceWrite()
  OPEN(SensorFile)
  TempCond = ERRORCODE()
  TraceLine = '  SSOpen: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
  TraceWrite()
  IF TempCond
    TraceLine = '  SSOpen: call CREATE'
    TraceWrite()
    CREATE(SensorFile)
    TempCond = ERRORCODE()
    TraceLine = '  SSOpen: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF TempCond
      TraceLine = '  SSOpen: return -1'
      TraceWrite()
      TraceLine = '  -> -1'
      TraceWrite()
      TraceClose()
      RETURN -1
    END
    TraceLine = '  SSOpen: call OPEN'
    TraceWrite()
    OPEN(SensorFile)
    TempCond = ERRORCODE()
    TraceLine = '  SSOpen: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF TempCond
      TraceLine = '  SSOpen: return -1'
      TraceWrite()
      TraceLine = '  -> -1'
      TraceWrite()
      TraceClose()
      RETURN -1
    END
  END
  TraceLine = '  SSOpen: return 0'
  TraceWrite()
  TraceLine = '  -> 0'
  TraceWrite()
  RETURN 0

SSClose PROCEDURE()
  CODE
  TraceLine = 'CALL SSClose()'
  TraceWrite()
  TraceLine = '  SSClose: call CLOSE'
  TraceWrite()
  CLOSE(SensorFile)
  TraceLine = '  SSClose: return 0'
  TraceWrite()
  TraceLine = '  -> 0'
  TraceWrite()
  TraceClose()
  RETURN 0

SSAddReading PROCEDURE(LONG id, LONG val, LONG w)
  CODE
  TraceLine = 'CALL SSAddReading(' & id & ', ' & val & ', ' & w & ')'
  TraceWrite()
  TraceLine = '  SSAddReading: call CLEAR'
  TraceWrite()
  CLEAR(SF:Record)
  SF:ID = id
  TraceLine = '  SSAddReading: assign SF:ID=' & SF:ID
  TraceWrite()
  SF:Reading = val
  TraceLine = '  SSAddReading: assign SF:Reading=' & SF:Reading
  TraceWrite()
  SF:Weight = w
  TraceLine = '  SSAddReading: assign SF:Weight=' & SF:Weight
  TraceWrite()
  SF:Processed = (val * w) / 100
  TraceLine = '  SSAddReading: assign SF:Processed=' & SF:Processed
  TraceWrite()
  SF:Status = 1
  TraceLine = '  SSAddReading: assign SF:Status=1'
  TraceWrite()
  TraceLine = '  SSAddReading: call ADD'
  TraceWrite()
  ADD(SensorFile)
  TempCond = ERRORCODE()
  TraceLine = '  SSAddReading: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
  TraceWrite()
  IF TempCond
    TraceLine = '  SSAddReading: return -2'
    TraceWrite()
    TraceLine = '  -> -2'
    TraceWrite()
    RETURN -2
  END
  TraceLine = '  SSAddReading: return 0'
  TraceWrite()
  TraceLine = '  -> 0'
  TraceWrite()
  RETURN 0

SSGetReading PROCEDURE(LONG id, LONG bufPtr)
Found LONG(0)
  CODE
  TraceLine = 'CALL SSGetReading(' & id & ', ' & bufPtr & ')'
  TraceWrite()
  TraceLine = '  SSGetReading: call SET'
  TraceWrite()
  SET(SensorFile)
  TraceLine = '  SSGetReading: loop enter'
  TraceWrite()
  LOOP
    TraceLine = '  SSGetReading: call NEXT'
    TraceWrite()
    NEXT(SensorFile)
    TempCond = ERRORCODE()
    TraceLine = '  SSGetReading: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF TempCond
      TraceLine = '  SSGetReading: break '
      TraceWrite()
      BREAK
    END
    TempCond = CHOOSE(SF:ID = id, 1, 0)
    TraceLine = '  SSGetReading: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF SF:ID = id
      GB:ID = SF:ID
      TraceLine = '  SSGetReading: assign GB:ID=' & GB:ID
      TraceWrite()
      GB:Reading = SF:Reading
      TraceLine = '  SSGetReading: assign GB:Reading=' & GB:Reading
      TraceWrite()
      GB:Weight = SF:Weight
      TraceLine = '  SSGetReading: assign GB:Weight=' & GB:Weight
      TraceWrite()
      GB:Processed = SF:Processed
      TraceLine = '  SSGetReading: assign GB:Processed=' & GB:Processed
      TraceWrite()
      GB:Status = SF:Status
      TraceLine = '  SSGetReading: assign GB:Status=' & GB:Status
      TraceWrite()
      TraceLine = '  SSGetReading: call MemCopy'
      TraceWrite()
      MemCopy(bufPtr, ADDRESS(GlobalBuf), SIZE(GlobalBuf))
      Found = 1
      TraceLine = '  SSGetReading: assign Found=1'
      TraceWrite()
      TraceLine = '  SSGetReading: break '
      TraceWrite()
      BREAK
    END
  END
  TraceLine = '  SSGetReading: loop exit'
  TraceWrite()
  TempCond = CHOOSE(Found = 0, 1, 0)
  TraceLine = '  SSGetReading: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
  TraceWrite()
  IF Found = 0
    TraceLine = '  SSGetReading: return -1'
    TraceWrite()
    TraceLine = '  -> -1'
    TraceWrite()
    RETURN -1
  END
  TraceLine = '  SSGetReading: return 0'
  TraceWrite()
  TraceLine = '  -> 0'
  TraceWrite()
  RETURN 0

SSCalculateWeightedAverage PROCEDURE()
TotalValue  LONG(0)
TotalWeight LONG(0)
  CODE
  TraceLine = 'CALL SSCalculateWeightedAverage()'
  TraceWrite()
  TraceLine = '  SSCalculateWeightedAverage: call SET'
  TraceWrite()
  SET(SensorFile)
  TraceLine = '  SSCalculateWeightedAverage: loop enter'
  TraceWrite()
  LOOP
    TraceLine = '  SSCalculateWeightedAverage: call NEXT'
    TraceWrite()
    NEXT(SensorFile)
    TempCond = ERRORCODE()
    TraceLine = '  SSCalculateWeightedAverage: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF TempCond
      TraceLine = '  SSCalculateWeightedAverage: break '
      TraceWrite()
      BREAK
    END
    TempCond = CHOOSE(SF:Status = 1, 1, 0)
    TraceLine = '  SSCalculateWeightedAverage: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF SF:Status = 1
      TotalValue += SF:Processed
      TraceLine = '  SSCalculateWeightedAverage: assign TotalValue=' & TotalValue
      TraceWrite()
      TotalWeight += SF:Weight
      TraceLine = '  SSCalculateWeightedAverage: assign TotalWeight=' & TotalWeight
      TraceWrite()
    END
  END
  TraceLine = '  SSCalculateWeightedAverage: loop exit'
  TraceWrite()
  TempCond = CHOOSE(TotalWeight = 0, 1, 0)
  TraceLine = '  SSCalculateWeightedAverage: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
  TraceWrite()
  IF TotalWeight = 0
    TraceLine = '  SSCalculateWeightedAverage: return 0'
    TraceWrite()
    TraceLine = '  -> 0'
    TraceWrite()
    RETURN 0
  END
  TempResult = (TotalValue * 100) / TotalWeight
  TraceLine = '  SSCalculateWeightedAverage: return ' & TempResult
  TraceWrite()
  TraceLine = '  -> ' & TempResult
  TraceWrite()
  RETURN TempResult

SSCleanupLowReadings PROCEDURE(LONG threshold)
RemovedCount LONG(0)
  CODE
  TraceLine = 'CALL SSCleanupLowReadings(' & threshold & ')'
  TraceWrite()
  TraceLine = '  SSCleanupLowReadings: call SET'
  TraceWrite()
  SET(SensorFile)
  TraceLine = '  SSCleanupLowReadings: loop enter'
  TraceWrite()
  LOOP
    TraceLine = '  SSCleanupLowReadings: call NEXT'
    TraceWrite()
    NEXT(SensorFile)
    TempCond = ERRORCODE()
    TraceLine = '  SSCleanupLowReadings: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF TempCond
      TraceLine = '  SSCleanupLowReadings: break '
      TraceWrite()
      BREAK
    END
    TempCond = CHOOSE(SF:Status = 1 AND SF:Reading < threshold, 1, 0)
    TraceLine = '  SSCleanupLowReadings: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
    TraceWrite()
    IF SF:Status = 1 AND SF:Reading < threshold
      SF:Status = 0
      TraceLine = '  SSCleanupLowReadings: assign SF:Status=0'
      TraceWrite()
      TraceLine = '  SSCleanupLowReadings: call PUT'
      TraceWrite()
      PUT(SensorFile)
      TempCond = CHOOSE(ERRORCODE() = 0, 1, 0)
      TraceLine = '  SSCleanupLowReadings: if cond=' & TempCond & CHOOSE(TempCond<>0, '/true', '/false')
      TraceWrite()
      IF TempCond
        RemovedCount += 1
        TraceLine = '  SSCleanupLowReadings: assign RemovedCount=' & RemovedCount
        TraceWrite()
      END
    END
  END
  TraceLine = '  SSCleanupLowReadings: loop exit'
  TraceWrite()
  TraceLine = '  SSCleanupLowReadings: return ' & RemovedCount
  TraceWrite()
  TraceLine = '  -> ' & RemovedCount
  TraceWrite()
  RETURN RemovedCount
