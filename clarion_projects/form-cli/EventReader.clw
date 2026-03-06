! EventReader.clw — reusable event file reader
! Reads .evt files (one event per line, space-separated).
! The including program must implement SetField(STRING, STRING).

  SECTION('MapEntries')
    MODULE('kernel32')
      CreateFileA(LONG, LONG, LONG, LONG, LONG, LONG, LONG),LONG,RAW,PASCAL,NAME('CreateFileA')
      WriteFile(LONG, LONG, LONG, LONG, LONG),LONG,RAW,PASCAL,NAME('WriteFile')
      CloseHandle(LONG),LONG,RAW,PASCAL,NAME('CloseHandle')
      lstrlenA(LONG),LONG,RAW,PASCAL,NAME('lstrlenA')
    END
    OpenEventFile()
    NextEvent(),LONG
    CloseEventFile()
    LogLine(STRING)
    SetField(STRING, STRING)

  SECTION('Declarations')
EventFile  FILE,DRIVER('ASCII'),NAME('events.evt'),PRE(EV)
Record       RECORD
Line           STRING(256)
             END
           END

EvtType    CSTRING(40)
EvtSource  CSTRING(40)
EvtValue   CSTRING(40)
ER_Pos1    LONG
ER_Pos2    LONG
ER_Cmd     CSTRING(20)
ER_FName   CSTRING(256)
ER_LogH    LONG(0)
ER_LogTxt  CSTRING(256)
ER_LogCrLf CSTRING(3)
ER_LogBW   LONG(0)

  SECTION('Procedures')
OpenEventFile PROCEDURE()
  CODE
  ER_LogCrLf = '<13,10>'
  IF COMMAND('') <> ''
    ER_FName = COMMAND('')
  ELSE
    ER_FName = 'events.evt'
  END
  ER_LogTxt = 'results.log'
  ER_LogH = CreateFileA(ADDRESS(ER_LogTxt), 40000000h, 1, 0, 2, 80h, 0)
  EventFile{PROP:Name} = ER_FName
  OPEN(EventFile)
  IF ERRORCODE()
    LogLine('ERROR: Cannot open ' & ER_FName)
    IF ER_LogH > 0 THEN CloseHandle(ER_LogH).
    HALT(1)
  END
  LogLine('Reading ' & ER_FName)
  SET(EventFile)

NextEvent PROCEDURE()
! Returns 1 with EvtType set to the control name (e.g. 'CALCBTN').
! Returns 0 at end of file.
! 'set' events are absorbed here via SetField() — mirrors USE() auto-binding.
  CODE
  LOOP
    NEXT(EventFile)
    IF ERRORCODE() THEN RETURN(0).
    IF CLIP(EV:Line) = '' THEN CYCLE.
    ER_Pos1 = INSTRING(' ', CLIP(EV:Line), 1, 1)
    IF ER_Pos1 = 0 THEN CYCLE.
    ER_Cmd = UPPER(SUB(EV:Line, 1, ER_Pos1 - 1))
    IF ER_Cmd = 'SET'
      ER_Pos2 = INSTRING(' ', CLIP(EV:Line), 1, ER_Pos1 + 1)
      IF ER_Pos2 = 0 THEN CYCLE.
      EvtSource = SUB(EV:Line, ER_Pos1 + 1, ER_Pos2 - ER_Pos1 - 1)
      EvtValue = SUB(EV:Line, ER_Pos2 + 1, LEN(CLIP(EV:Line)) - ER_Pos2)
      SetField(EvtSource, EvtValue)
      CYCLE
    ELSIF ER_Cmd = 'ACCEPTED'
      EvtType = UPPER(CLIP(SUB(EV:Line, ER_Pos1 + 1, LEN(CLIP(EV:Line)) - ER_Pos1)))
      RETURN(1)
    END
  END
  RETURN(0)

CloseEventFile PROCEDURE()
  CODE
  CLOSE(EventFile)
  IF ER_LogH > 0 THEN CloseHandle(ER_LogH).

LogLine PROCEDURE(pText)
  CODE
  IF ER_LogH > 0
    ER_LogTxt = pText
    WriteFile(ER_LogH, ADDRESS(ER_LogTxt), lstrlenA(ADDRESS(ER_LogTxt)), ADDRESS(ER_LogBW), 0)
    WriteFile(ER_LogH, ADDRESS(ER_LogCrLf), 2, ADDRESS(ER_LogBW), 0)
  END
