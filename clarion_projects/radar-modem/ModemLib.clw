  MEMBER()

! =================================================================
! ModemLib.clw — Hayes modem state machine simulator
!
! Translated from Modem.DEF/Modem.MOD (Derek Lane, 1986, E300DB)
! Original Modula-2:
!   TYPE ResultCode = (Ok, Connect300, Ring, NoCarrier, ModemError,
!                      Connect1200, NoDialtone, Busy, NoAnswer,
!                      Connect2400, NoResponse);
!   PROCEDURE Call(Number: ARRAY OF CHAR; VAR Result: ResultCode);
!   PROCEDURE HangUp(VAR Result: ResultCode);
!   PROCEDURE ModemCommand(Command: ARRAY OF CHAR; VAR Result: ResultCode);
!
! Hayes numeric result codes:
!   0=Ok, 1=Connect300, 2=Ring, 3=NoCarrier, 4=ModemError,
!   5=Connect1200, 6=NoDialtone, 7=Busy, 8=NoAnswer,
!   10=Connect2400, 99=NoResponse
!
! This Clarion DLL simulates the modem state machine with
! predefined responses — no actual serial I/O.
! Variant casing demonstrates Clarion's case-insensitivity.
! =================================================================

! --- Module-level state variables ---
Connected    byte(0)       ! 0=idle, 1=connected
lastResult   LONG(0)       ! last result code
BaudRate     long(0)       ! current baud rate (0, 300, 1200, 2400)
NextResponse LONG(0)       ! pre-set response for next Call/Command
resultBuf    STRING(20)    ! buffer for ResultToText

  MAP
    MODULE('kernel32')
      memcopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    ! Original Modula-2: no direct Init — hardware reset implied
    MLInit(),long,C,name('MLInit'),EXPORT
    ! Set what the next Call/Command will return (for testing)
    mlSetResponse(LONG resultCode),LONG,C,NAME('MLSetResponse'),EXPORT
    ! Original: PROCEDURE Call(Number: ARRAY OF CHAR; VAR Result: ResultCode);
    MlCall(LONG phonePtr, LONG phoneLen),long,c,NAME('MLCall'),EXPORT
    ! Original: PROCEDURE HangUp(VAR Result: ResultCode);
    MLHangUp(),LONG,C,NAME('MLHangUp'),export
    ! Original: PROCEDURE ModemCommand(Command: ARRAY OF CHAR; VAR Result: ResultCode);
    mlCommand(LONG cmdPtr, LONG cmdLen),LONG,C,name('MLCommand'),EXPORT
    MLGetState(),long,C,NAME('MLGetState'),EXPORT
    mlGetBaud(),LONG,c,NAME('MLGetBaud'),EXPORT
    MLGetLastResult(),LONG,C,NAME('MLGetLastResult'),export
    ! Convert numeric result code to Hayes text response
    MlResultToText(LONG resultCode, LONG bufPtr),LONG,C,NAME('MLResultToText'),EXPORT
  END


! -----------------------------------------------------------------
! MLInit — reset modem state to idle
! Original Modula-2: hardware initialization via OUT to COM port
! -----------------------------------------------------------------
MLInit            PROCEDURE()
  CODE
  connected = 0
  LastResult = 0
  baudRate = 0
  nextResponse = 0
  RETURN 0


! -----------------------------------------------------------------
! MLSetResponse — pre-load the result code for next operation
! Valid codes: 0,1,2,3,4,5,6,7,8,10,99
! Returns 0 on success, -1 if invalid code
! -----------------------------------------------------------------
mlSetResponse     procedure(LONG resultCode)
  CODE
  ! Validate against known Hayes result codes
  CASE resultCode
  OF 0 OROF 1 OROF 2 OROF 3 OROF 4 OROF 5 OROF 6 OROF 7 OROF 8 OROF 10 OROF 99
    NextResponse = resultCode
    RETURN 0
  ELSE
    RETURN -1
  END


! -----------------------------------------------------------------
! MLCall — simulate dialing a phone number
! Original Modula-2: PROCEDURE Call(Number: ARRAY OF CHAR; VAR Result: ResultCode);
!   Sent "ATDT" + Number + CR to serial port, then parsed response
!   Connect300 -> baud 300, Connect1200 -> baud 1200,
!   Connect2400 -> baud 2400
! -----------------------------------------------------------------
MlCall            PROCEDURE(LONG phonePtr, LONG phoneLen)
result  LONG
  CODE
  result = nextResponse
  lastResult = result
  ! Set connection state based on result code
  CASE result
  OF 1    ! Connect300
    Connected = 1
    BaudRate = 300
  OF 5    ! Connect1200
    connected = 1
    baudrate = 1200
  OF 10   ! Connect2400
    Connected = 1
    baudRate = 2400
  ELSE
    ! NoCarrier, Busy, NoDialtone, etc. — not connected
    Connected = 0
    baudRate = 0
  END
  RETURN result


! -----------------------------------------------------------------
! MLHangUp — disconnect the modem
! Original Modula-2: PROCEDURE HangUp(VAR Result: ResultCode);
!   Sent "+++" pause then "ATH" CR to drop carrier
! -----------------------------------------------------------------
MLHangUp          PROCEDURE()
  CODE
  Connected = 0
  BaudRate = 0
  lastResult = 0    ! Ok
  RETURN 0


! -----------------------------------------------------------------
! MLCommand — simulate sending an AT command string
! Original Modula-2: PROCEDURE ModemCommand(Command: ARRAY OF CHAR; VAR Result: ResultCode);
!   Sent command + CR, parsed numeric response from modem
! Special: if command starts with "ATH", perform hangup
! -----------------------------------------------------------------
mlCommand         procedure(LONG cmdPtr, LONG cmdLen)
CmdBuf  STRING(64)
result  LONG
  CODE
  ! Copy command string from caller's buffer
  IF cmdLen > 64
    cmdLen = 64
  END
  IF cmdLen > 0
    memcopy(ADDRESS(CmdBuf), cmdPtr, cmdLen)
  END
  ! Check for ATH (hangup) command — case insensitive via UPPER
  IF cmdLen >= 3 AND UPPER(CmdBuf[1:3]) = 'ATH'
    Connected = 0
    baudRate = 0
    lastResult = 0
    RETURN 0
  END
  ! For all other commands, return the pre-set response
  result = NextResponse
  LastResult = result
  RETURN result


! -----------------------------------------------------------------
! MLGetState — return current connected state
! -----------------------------------------------------------------
MLGetState        procedure()
  CODE
  RETURN connected


! -----------------------------------------------------------------
! MLGetBaud — return current baud rate
! -----------------------------------------------------------------
mlGetBaud         PROCEDURE()
  CODE
  RETURN baudRate


! -----------------------------------------------------------------
! MLGetLastResult — return last result code
! -----------------------------------------------------------------
MLGetLastResult   PROCEDURE()
  CODE
  RETURN LastResult


! -----------------------------------------------------------------
! MLResultToText — convert numeric result code to Hayes text
! Original Modula-2 parsed these as numeric codes from the modem:
!   0="OK", 1="CONNECT 300", 2="RING", 3="NO CARRIER",
!   4="ERROR", 5="CONNECT 1200", 6="NO DIALTONE", 7="BUSY",
!   8="NO ANSWER", 10="CONNECT 2400", 99="NO RESPONSE"
! Copies result name into caller's buffer, returns string length.
! -----------------------------------------------------------------
MlResultToText    PROCEDURE(LONG resultCode, LONG bufPtr)
TextLen LONG(0)
  CODE
  resultBuf = ''
  CASE resultCode
  OF 0
    ResultBuf = 'OK'
    TextLen = 2
  OF 1
    resultBuf = 'CONNECT 300'
    TextLen = 11
  OF 2
    ResultBuf = 'RING'
    textLen = 4
  OF 3
    resultBuf = 'NO CARRIER'
    TextLen = 10
  OF 4
    ResultBuf = 'ERROR'
    TextLen = 5
  OF 5
    resultBuf = 'CONNECT 1200'
    textLen = 12
  OF 6
    ResultBuf = 'NO DIALTONE'
    TextLen = 11
  OF 7
    resultBuf = 'BUSY'
    textLen = 4
  OF 8
    ResultBuf = 'NO ANSWER'
    TextLen = 9
  OF 10
    resultBuf = 'CONNECT 2400'
    TextLen = 12
  OF 99
    ResultBuf = 'NO RESPONSE'
    textLen = 11
  ELSE
    resultBuf = 'UNKNOWN'
    TextLen = 7
  END
  IF bufPtr > 0
    memcopy(bufPtr, ADDRESS(resultBuf), TextLen)
  END
  RETURN TextLen
