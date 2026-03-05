  PROGRAM

  MAP
  END

SensorID   LONG(0)
Reading    LONG(0)
Weight     LONG(0)
Result     LONG(0)
SensorType LONG(1)

MainWindow WINDOW('Sensor Entry'),AT(,,280,180),CENTER
             PROMPT('Sensor ID:'),AT(10,10)
             ENTRY(@n9),AT(100,10,80,12),USE(SensorID)
             PROMPT('Reading:'),AT(10,30)
             ENTRY(@n9),AT(100,30,80,12),USE(Reading)
             PROMPT('Weight:'),AT(10,50)
             ENTRY(@n9),AT(100,50,80,12),USE(Weight)
             PROMPT('Type:'),AT(10,70)
             LIST,AT(100,70,80,12),USE(?TypeList),DROP(3),FROM('Standard|High|Critical')
             BUTTON('Calculate'),AT(10,100,80,14),USE(?CalcBtn)
             BUTTON('Clear'),AT(100,100,80,14),USE(?ClearBtn)
             BUTTON('Close'),AT(190,100,80,14),USE(?CloseBtn)
             PROMPT('Processed:'),AT(10,130)
             STRING(@n9),AT(100,130,80,14),USE(Result)
           END

  CODE
  OPEN(MainWindow)
  SELECT(?TypeList, 1)
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      SensorType = CHOICE(?TypeList)
      Result = ((Reading * Weight) / 100) * SensorType
      DISPLAY
    OF ?ClearBtn
      SensorID = 0
      Reading = 0
      Weight = 0
      Result = 0
      SELECT(?TypeList, 1)
      DISPLAY
    OF ?CloseBtn
      BREAK
    END
  END
  CLOSE(MainWindow)
  RETURN
