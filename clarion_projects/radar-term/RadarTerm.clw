  PROGRAM

  MAP
    MODULE('RadarLib')
      RLOpen(),LONG,C,NAME('RLOpen')
      RLClose(),LONG,C,NAME('RLClose')
      RLAddStation(LONG, LONG, LONG, LONG, LONG, LONG, LONG, LONG),LONG,C,NAME('RLAddStation')
      RLGetStation(LONG, LONG),LONG,C,NAME('RLGetStation')
      RLGetStationCount(),LONG,C,NAME('RLGetStationCount')
      RLSelectStation(LONG),LONG,C,NAME('RLSelectStation')
      RLSetParams(LONG, LONG, LONG),LONG,C,NAME('RLSetParams')
      RLGetParams(LONG),LONG,C,NAME('RLGetParams')
      RLSetMode(LONG),LONG,C,NAME('RLSetMode')
      RLGetMode(),LONG,C,NAME('RLGetMode')
      RLAddPicture(LONG, LONG, LONG, LONG, LONG, LONG, LONG, LONG, LONG, LONG),LONG,C,NAME('RLAddPicture')
      RLGetPicture(LONG, LONG),LONG,C,NAME('RLGetPicture')
      RLGetPictureCount(),LONG,C,NAME('RLGetPictureCount')
      RLDeletePicture(LONG),LONG,C,NAME('RLDeletePicture')
      RLRangeToKm(LONG),LONG,C,NAME('RLRangeToKm')
    END
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    RefreshStationList()
    RefreshPictureList()
    RefreshParamDisplay()
  END

StationQ QUEUE
Number     LONG
Name       STRING(30)
Phone      STRING(20)
         END

PictureQ QUEUE
FileName   STRING(12)
Year       SHORT
Month      BYTE
Day        BYTE
Hour       BYTE
Minute     BYTE
Tilt       BYTE
Range      BYTE
Gain       BYTE
         END

StBuf GROUP,PRE(SB)
Number     LONG
Name       STRING(30)
Phone      STRING(20)
CommPort   BYTE
BaudRate   LONG
AutoInt    LONG
      END

PicBuf GROUP,PRE(PB)
FileName   STRING(12)
Year       SHORT
Month      BYTE
Day        BYTE
Hour       BYTE
Minute     BYTE
Tilt       BYTE
Range      BYTE
Gain       BYTE
       END

ParamBuf GROUP,PRE(PM)
Tilt       LONG
Range      LONG
Gain       LONG
         END

! Entry fields
EntTilt    LONG(0)
EntRange   LONG(0)
EntGain    LONG(1)
ModeText   STRING(20)
RangeKm    LONG(0)
PicName    STRING(12)

MainWindow WINDOW('Radar Terminal'),AT(,,400,320),CENTER,SYSTEM,GRAY
             ! Station list
             PROMPT('Stations:'),AT(10,5)
             LIST,AT(10,18,180,80),USE(?StationList),FROM(StationQ),|
               FORMAT('30L(2)|80L(2)|60L(2)'),HVSCROLL
             BUTTON('Select Station'),AT(10,102,85,14),USE(?SelectStationBtn)

             ! Parameter controls
             PROMPT('Tilt (0-11):'),AT(210,5)
             ENTRY(@n3),AT(290,5,40,12),USE(EntTilt)
             PROMPT('Range (0-4):'),AT(210,22)
             ENTRY(@n3),AT(290,22,40,12),USE(EntRange)
             PROMPT('Gain (1-17):'),AT(210,39)
             ENTRY(@n3),AT(290,39,40,12),USE(EntGain)
             BUTTON('Set Params'),AT(340,5,50,14),USE(?SetParamsBtn)
             PROMPT('Range km:'),AT(210,58)
             STRING(@n5),AT(290,58,40,14),USE(RangeKm)
             PROMPT('Mode:'),AT(210,78)
             STRING(@s20),AT(260,78,80,14),USE(ModeText)

             ! Picture list
             PROMPT('Pictures:'),AT(10,122)
             LIST,AT(10,135,380,100),USE(?PictureList),FROM(PictureQ),|
               FORMAT('80L(2)|30R(2)|20R(2)|20R(2)|20R(2)|20R(2)|20R(2)|20R(2)|20R(2)'),HVSCROLL

             ! Picture entry
             PROMPT('Pic Name:'),AT(10,240)
             ENTRY(@s12),AT(70,240,80,12),USE(PicName)
             BUTTON('Add Picture'),AT(10,258,70,14),USE(?AddPicBtn)
             BUTTON('Delete Picture'),AT(90,258,80,14),USE(?DeletePicBtn)
             BUTTON('Close'),AT(340,290,50,14),USE(?CloseBtn)
           END

I LONG
Ret LONG

  CODE
  Ret = RLOpen()
  IF Ret <> 0
    MESSAGE('Failed to open radar library')
    RETURN
  END
  OPEN(MainWindow)
  ModeText = 'Idle'
  RangeKm = RLRangeToKm(EntRange)
  RefreshStationList()
  RefreshPictureList()
  RefreshParamDisplay()
  DISPLAY
  ACCEPT
    CASE ACCEPTED()
    OF ?SelectStationBtn
      I = CHOICE(?StationList)
      IF I > 0
        Ret = RLSelectStation(I)
        IF Ret = 0
          MESSAGE('Station ' & I & ' selected')
        ELSE
          MESSAGE('Invalid station selection')
        END
      END
    OF ?SetParamsBtn
      Ret = RLSetParams(EntTilt, EntRange, EntGain)
      IF Ret = 0
        RefreshParamDisplay()
        DISPLAY
      ELSE
        MESSAGE('Invalid parameters.|Tilt: 0-11, Range: 0-4, Gain: 1-17')
      END
    OF ?AddPicBtn
      IF PicName <> ''
        Ret = RLAddPicture(ADDRESS(PicName), LEN(CLIP(PicName)), 2026, 3, 11, 12, 0, EntTilt, EntRange, EntGain)
        IF Ret > 0
          RefreshPictureList()
          DISPLAY
        ELSE
          MESSAGE('Failed to add picture')
        END
      ELSE
        MESSAGE('Enter a picture name')
      END
    OF ?DeletePicBtn
      I = CHOICE(?PictureList)
      IF I > 0
        Ret = RLDeletePicture(I)
        IF Ret = 0
          RefreshPictureList()
          DISPLAY
        ELSE
          MESSAGE('Failed to delete picture')
        END
      ELSE
        MESSAGE('Select a picture first')
      END
    OF ?CloseBtn
      BREAK
    END
  END
  RLClose()
  CLOSE(MainWindow)
  RETURN

RefreshStationList PROCEDURE()
Cnt LONG
I   LONG
  CODE
  FREE(StationQ)
  Cnt = RLGetStationCount()
  LOOP I = 1 TO Cnt
    IF RLGetStation(I, ADDRESS(StBuf)) = 0
      StationQ.Number = SB:Number
      StationQ.Name = SB:Name
      StationQ.Phone = SB:Phone
      ADD(StationQ)
    END
  END

RefreshPictureList PROCEDURE()
Cnt LONG
I   LONG
  CODE
  FREE(PictureQ)
  Cnt = RLGetPictureCount()
  LOOP I = 1 TO Cnt
    IF RLGetPicture(I, ADDRESS(PicBuf)) = 0
      PictureQ.FileName = PB:FileName
      PictureQ.Year = PB:Year
      PictureQ.Month = PB:Month
      PictureQ.Day = PB:Day
      PictureQ.Hour = PB:Hour
      PictureQ.Minute = PB:Minute
      PictureQ.Tilt = PB:Tilt
      PictureQ.Range = PB:Range
      PictureQ.Gain = PB:Gain
      ADD(PictureQ)
    END
  END

RefreshParamDisplay PROCEDURE()
  CODE
  RLGetParams(ADDRESS(ParamBuf))
  EntTilt = PM:Tilt
  EntRange = PM:Range
  EntGain = PM:Gain
  RangeKm = RLRangeToKm(EntRange)
