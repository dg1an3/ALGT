  PROGRAM

  MAP
  END

SensorID LONG(0)
Reading  LONG(0)
Weight   LONG(0)
Result   LONG(0)

MainWindow WINDOW('Sensor Entry'),AT(,,280,160),CENTER
             PROMPT('Sensor ID:'),AT(10,10)
             ENTRY(@n9),AT(100,10,80,12),USE(SensorID)
             PROMPT('Reading:'),AT(10,30)
             ENTRY(@n9),AT(100,30,80,12),USE(Reading)
             PROMPT('Weight:'),AT(10,50)
             ENTRY(@n9),AT(100,50,80,12),USE(Weight)
             BUTTON('Calculate'),AT(10,80,80,14),USE(?CalcBtn)
             BUTTON('Clear'),AT(100,80,80,14),USE(?ClearBtn)
             BUTTON('Close'),AT(190,80,80,14),USE(?CloseBtn)
             PROMPT('Processed:'),AT(10,110)
             STRING(@n9),AT(100,110,80,14),USE(Result)
           END

  CODE
  OPEN(MainWindow)
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      Result = (Reading * Weight) / 100
      DISPLAY
    OF ?ClearBtn
      SensorID = 0
      Reading = 0
      Weight = 0
      Result = 0
      DISPLAY
    OF ?CloseBtn
      BREAK
    END
  END
  CLOSE(MainWindow)
  RETURN
