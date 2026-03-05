  MEMBER()

StatsGroup GROUP,PRE(ST)
Mean         LONG
Median       LONG
Classification LONG
           END

DataArray LONG,DIM(10)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    CalculateStats(LONG count),LONG,C,NAME('CalculateStats'),EXPORT
    GetStats(LONG bufPtr),LONG,C,NAME('GetStats'),EXPORT
    Classify(LONG mean),LONG,PRIVATE
  END

CalculateStats PROCEDURE(LONG count)
i LONG
Sum LONG(0)
  CODE
  IF count = 0 THEN RETURN -1.
  ! Mock data for testing
  DataArray[1] = 10
  DataArray[2] = 20
  DataArray[3] = 30
  
  LOOP i = 1 TO count
    Sum += DataArray[i]
  END
  ST:Mean = Sum / count
  ST:Classification = Classify(ST:Mean)
  RETURN 0

GetStats PROCEDURE(LONG bufPtr)
  CODE
  MemCopy(bufPtr, ADDRESS(StatsGroup), SIZE(StatsGroup))
  RETURN 0

Classify PROCEDURE(LONG mean)
  CODE
  CASE mean
  OF 0 TO 10
    RETURN 1 ! Low
  OF 11 TO 50
    RETURN 2 ! Medium
  ELSE
    RETURN 3 ! High
  END
