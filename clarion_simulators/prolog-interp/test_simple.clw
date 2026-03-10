  MEMBER()

  MAP
    SSCleanupLowReadings(LONG threshold),LONG,C,NAME('SSCleanupLowReadings'),EXPORT
  END

SSCleanupLowReadings PROCEDURE(LONG threshold)
RemovedCount LONG(0)
  CODE
  LOOP
    IF SF:Status = 1 AND SF:Reading < threshold
      SF:Status = 0
      IF ERRORCODE() = 0 THEN RemovedCount += 1.
    END
  END
  RETURN RemovedCount
