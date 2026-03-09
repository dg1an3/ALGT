  PROGRAM

  MAP
    ISqrt(LONG),LONG
  END

! Shift values in mm (e.g. 15 = 1.5 cm)
Anterior   LONG(0)
Superior   LONG(0)
Lateral    LONG(0)
Magnitude  LONG(0)
OffsetDate LONG(0)
OffsetTime LONG(0)
DataSource LONG(1)

MainWindow WINDOW('Treatment Offset Entry'),AT(,,320,200),CENTER
             PROMPT('Anterior (mm):'),AT(10,10)
             ENTRY(@n6),AT(140,10,80,12),USE(Anterior)
             PROMPT('Superior (mm):'),AT(10,30)
             ENTRY(@n6),AT(140,30,80,12),USE(Superior)
             PROMPT('Lateral (mm):'),AT(10,50)
             ENTRY(@n6),AT(140,50,80,12),USE(Lateral)
             PROMPT('Date:'),AT(10,75)
             ENTRY(@d2),AT(140,75,80,12),USE(OffsetDate)
             PROMPT('Time:'),AT(10,95)
             ENTRY(@t1),AT(140,95,80,12),USE(OffsetTime)
             PROMPT('Data Source:'),AT(10,115)
             LIST,AT(140,115,100,12),USE(?SourceList),DROP(4),FROM('CBCT|kV Imaging|Portal|Manual')
             BUTTON('Calculate'),AT(10,145,80,14),USE(?CalcBtn)
             BUTTON('Clear'),AT(100,145,80,14),USE(?ClearBtn)
             BUTTON('Close'),AT(230,145,80,14),USE(?CloseBtn)
             PROMPT('Magnitude (mm):'),AT(10,170)
             STRING(@n6),AT(140,170,80,14),USE(Magnitude)
           END

  CODE
  OPEN(MainWindow)
  OffsetDate = TODAY()
  OffsetTime = CLOCK()
  SELECT(?SourceList, 1)
  DISPLAY
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      DataSource = CHOICE(?SourceList)
      Magnitude = ISqrt(Anterior * Anterior + Superior * Superior + Lateral * Lateral)
      DISPLAY
    OF ?ClearBtn
      Anterior = 0
      Superior = 0
      Lateral = 0
      Magnitude = 0
      OffsetDate = TODAY()
      OffsetTime = CLOCK()
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
