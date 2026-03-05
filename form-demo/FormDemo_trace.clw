  PROGRAM

TraceLine   CSTRING(256)
TraceHandle LONG(0)
TraceBW     LONG(0)
TraceCrLf   CSTRING(3)
TraceFileName CSTRING(32)

  MAP
    MODULE('kernel32')
      CreateFileA(LONG lpFileName, LONG dwAccess, LONG dwShare, LONG lpSec, LONG dwDisp, LONG dwFlags, LONG hTemplate),LONG,RAW,PASCAL,NAME('CreateFileA')
      WriteFile(LONG hFile, LONG lpBuf, LONG nBytes, LONG lpWritten, LONG lpOverlap),LONG,RAW,PASCAL,NAME('WriteFile')
      CloseHandle(LONG hHandle),LONG,RAW,PASCAL,NAME('CloseHandle')
      lstrlenA(LONG lpString),LONG,RAW,PASCAL,NAME('lstrlenA')
    END
    TraceOpen()
    TraceWrite()
    TraceClose()
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
  TraceOpen()
  TraceLine = '_main: open MainWindow'
  TraceWrite()
  OPEN(MainWindow)
  TraceLine = '_main: accept enter'
  TraceWrite()
  ACCEPT
    CASE ACCEPTED()
    OF ?CalcBtn
      TraceLine = '_main: accepted CalcBtn'
      TraceWrite()
      Result = (Reading * Weight) / 100
      TraceLine = '_main: assign Result=' & Result
      TraceWrite()
      TraceLine = '_main: display'
      TraceWrite()
      DISPLAY
    OF ?ClearBtn
      TraceLine = '_main: accepted ClearBtn'
      TraceWrite()
      SensorID = 0
      TraceLine = '_main: assign SensorID=0'
      TraceWrite()
      Reading = 0
      TraceLine = '_main: assign Reading=0'
      TraceWrite()
      Weight = 0
      TraceLine = '_main: assign Weight=0'
      TraceWrite()
      Result = 0
      TraceLine = '_main: assign Result=0'
      TraceWrite()
      TraceLine = '_main: display'
      TraceWrite()
      DISPLAY
    OF ?CloseBtn
      TraceLine = '_main: accepted CloseBtn'
      TraceWrite()
      TraceLine = '_main: break'
      TraceWrite()
      BREAK
    END
  END
  TraceLine = '_main: accept exit'
  TraceWrite()
  TraceLine = '_main: close MainWindow'
  TraceWrite()
  CLOSE(MainWindow)
  TraceClose()
  RETURN

TraceOpen PROCEDURE()
  CODE
  TraceFileName = 'form_trace.log'
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
