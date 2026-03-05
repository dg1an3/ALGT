  PROGRAM

  MAP
    INCLUDE('EventReader.clw', 'MapEntries')
  END

SensorID   LONG(0)
Reading    LONG(0)
Weight     LONG(0)
Result     LONG(0)
SensorType LONG(1)

  INCLUDE('EventReader.clw', 'Declarations')
!            PROMPT('Sensor ID:')
!            ENTRY(@n9),USE(SensorID)         -> set SensorID <val>
!            PROMPT('Reading:')
!            ENTRY(@n9),USE(Reading)           -> set Reading <val>
!            PROMPT('Weight:')
!            ENTRY(@n9),USE(Weight)            -> set Weight <val>
!            PROMPT('Type:')
!            LIST,USE(?TypeList)               -> set SensorType <n>
!            BUTTON('Calculate'),USE(?CalcBtn) -> accepted CalcBtn
!            BUTTON('Clear'),USE(?ClearBtn)    -> accepted ClearBtn
!            BUTTON('Close'),USE(?CloseBtn)    -> accepted CloseBtn
!            PROMPT('Processed:')
!            STRING(@n9),USE(Result)           -> logged via LogLine


  CODE
  OpenEventFile()                                               ! OPEN(MainWindow)
  SensorType = 1                                                ! SELECT(?TypeList, 1)
  LOOP                                                          ! ACCEPT
    IF NextEvent() = 0 THEN BREAK.                              !   (next Windows message)
    CASE EvtType                                                !   CASE ACCEPTED()
    OF 'CALCBTN'                                                !   OF ?CalcBtn
      ! SensorType already set via SetField                     !     SensorType = CHOICE(?TypeList)
      Result = ((Reading * Weight) / 100) * SensorType
      LogLine('[CalcBtn] Result=' & Result)                     !     DISPLAY
    OF 'CLEARBTN'                                               !   OF ?ClearBtn
      SensorID = 0
      Reading = 0
      Weight = 0
      Result = 0
      SensorType = 1                                            !     SELECT(?TypeList, 1)
      LogLine('[ClearBtn] cleared')                             !     DISPLAY
    OF 'CLOSEBTN'                                               !   OF ?CloseBtn
      BREAK
    END                                                         !   END
  END                                                           ! END
  CloseEventFile()                                              ! CLOSE(MainWindow)
  RETURN

! SetField — called by NextEvent for 'set' events (mirrors USE() binding)
SetField PROCEDURE(pName, pValue)
  CODE
  CASE UPPER(pName)
  OF 'SENSORID'
    SensorID = pValue
  OF 'READING'
    Reading = pValue
  OF 'WEIGHT'
    Weight = pValue
  OF 'SENSORTYPE'
    SensorType = pValue
  OF 'RESULT'
    Result = pValue
  END

  INCLUDE('EventReader.clw', 'Procedures')
