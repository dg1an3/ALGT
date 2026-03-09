  PROGRAM

  MAP
    ISqrt(LONG),LONG
  END

! Shift values in mm (always positive after normalization)
APValue    LONG(0)
APDir      LONG(1)
SIValue    LONG(0)
SIDir      LONG(1)
LRValue    LONG(0)
LRDir      LONG(1)
Magnitude  LONG(0)
OffsetDate LONG(0)
OffsetTime LONG(0)
DataSource LONG(1)

MainWindow WINDOW('Treatment Offset Entry'),AT(,,340,220),CENTER
             PROMPT('A/P (mm):'),AT(10,10)
             ENTRY(@n6),AT(100,10,60,12),USE(APValue)
             LIST,AT(170,10,80,12),USE(?APDirList),DROP(2),FROM('Anterior|Posterior')
             PROMPT('S/I (mm):'),AT(10,30)
             ENTRY(@n6),AT(100,30,60,12),USE(SIValue)
             LIST,AT(170,30,80,12),USE(?SIDirList),DROP(2),FROM('Superior|Inferior')
             PROMPT('L/R (mm):'),AT(10,50)
             ENTRY(@n6),AT(100,50,60,12),USE(LRValue)
             LIST,AT(170,50,80,12),USE(?LRDirList),DROP(2),FROM('Left|Right')
             PROMPT('Date:'),AT(10,80)
             ENTRY(@d2),AT(100,80,80,12),USE(OffsetDate)
             PROMPT('Time:'),AT(10,100)
             ENTRY(@t1),AT(100,100,80,12),USE(OffsetTime)
             PROMPT('Data Source:'),AT(10,120)
             LIST,AT(100,120,100,12),USE(?SourceList),DROP(4),FROM('CBCT|kV Imaging|Portal|Manual')
             BUTTON('Calculate'),AT(10,150,80,14),USE(?CalcBtn)
             BUTTON('Clear'),AT(100,150,80,14),USE(?ClearBtn)
             BUTTON('Close'),AT(250,150,80,14),USE(?CloseBtn)
             PROMPT('Magnitude (mm):'),AT(10,180)
             STRING(@n6),AT(100,180,80,14),USE(Magnitude)
           END

  CODE
  OPEN(MainWindow)
  OffsetDate = TODAY()
  OffsetTime = CLOCK()
  SELECT(?APDirList, 1)
  SELECT(?SIDirList, 1)
  SELECT(?LRDirList, 1)
  SELECT(?SourceList, 1)
  DISPLAY
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      ! Normalize negative values: negate and flip direction
      IF APValue < 0
        APValue = 0 - APValue
        IF CHOICE(?APDirList) = 1
          SELECT(?APDirList, 2)
        ELSE
          SELECT(?APDirList, 1)
        END
      END
      IF SIValue < 0
        SIValue = 0 - SIValue
        IF CHOICE(?SIDirList) = 1
          SELECT(?SIDirList, 2)
        ELSE
          SELECT(?SIDirList, 1)
        END
      END
      IF LRValue < 0
        LRValue = 0 - LRValue
        IF CHOICE(?LRDirList) = 1
          SELECT(?LRDirList, 2)
        ELSE
          SELECT(?LRDirList, 1)
        END
      END
      APDir = CHOICE(?APDirList)
      SIDir = CHOICE(?SIDirList)
      LRDir = CHOICE(?LRDirList)
      DataSource = CHOICE(?SourceList)
      Magnitude = ISqrt(APValue * APValue + SIValue * SIValue + LRValue * LRValue)
      DISPLAY
    OF ?ClearBtn
      APValue = 0
      SIValue = 0
      LRValue = 0
      Magnitude = 0
      APDir = 1
      SIDir = 1
      LRDir = 1
      OffsetDate = TODAY()
      OffsetTime = CLOCK()
      SELECT(?APDirList, 1)
      SELECT(?SIDirList, 1)
      SELECT(?LRDirList, 1)
      SELECT(?SourceList, 1)
      DataSource = 1
      DISPLAY
    OF ?CloseBtn
      BREAK
    END
  END
  CLOSE(MainWindow)
  RETURN

! Integer square root via Newton's method
ISqrt PROCEDURE(LONG n)
x  LONG
x1 LONG
  CODE
  IF n <= 0 THEN RETURN 0.
  x = n
  x1 = (x + 1) / 2
  LOOP WHILE x1 < x
    x = x1
    x1 = (x + n / x) / 2
  END
  RETURN x
