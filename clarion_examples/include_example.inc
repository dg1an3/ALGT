!============================================================
! include_example.inc - Include File (Header)
! Demonstrates: INCLUDE file structure, EQUATES, prototypes
!============================================================

! Prevent multiple inclusion
  OMIT('_INCLUDE_EXAMPLE_INC_')
_INCLUDE_EXAMPLE_INC_  EQUATE(1)

!------------------------------------------------------------
! Application Constants
!------------------------------------------------------------
APP_NAME            EQUATE('My Application')
APP_VERSION         EQUATE('1.0.0')
MAX_RECORDS         EQUATE(10000)
MAX_STRING_LENGTH   EQUATE(255)
DEBUG_MODE          EQUATE(TRUE)

!------------------------------------------------------------
! Status Code Equates
!------------------------------------------------------------
STATUS_OK           EQUATE(0)
STATUS_ERROR        EQUATE(-1)
STATUS_NOT_FOUND    EQUATE(-2)
STATUS_DUPLICATE    EQUATE(-3)
STATUS_OVERFLOW     EQUATE(-4)

!------------------------------------------------------------
! Color Constants
!------------------------------------------------------------
COLOR_HIGHLIGHT     EQUATE(0FFFF00H)    ! Yellow
COLOR_ERROR         EQUATE(0FF0000H)    ! Red
COLOR_SUCCESS       EQUATE(000FF00H)    ! Green
COLOR_WARNING       EQUATE(0FFA500H)    ! Orange

!------------------------------------------------------------
! Group Type Definitions
!------------------------------------------------------------
AddressType         GROUP,TYPE
Street                STRING(50)
City                  STRING(30)
State                 STRING(2)
ZipCode               STRING(10)
Country               STRING(30)
                    END

PersonType          GROUP,TYPE
FirstName             STRING(30)
LastName              STRING(30)
Email                 STRING(50)
Phone                 STRING(15)
Address               LIKE(AddressType)
                    END

!------------------------------------------------------------
! Queue Type Definitions
!------------------------------------------------------------
ErrorLogQueue       QUEUE,TYPE
ErrorCode             LONG
ErrorMessage          STRING(200)
ErrorTime             TIME
ErrorDate             DATE
ModuleName            STRING(50)
                    END

!------------------------------------------------------------
! Interface Class Definition
!------------------------------------------------------------
ILogger             INTERFACE
Log                   PROCEDURE(STRING pMessage)
LogError              PROCEDURE(LONG pCode, STRING pMessage)
LogWarning            PROCEDURE(STRING pMessage)
GetLogCount           PROCEDURE,LONG
Clear                 PROCEDURE
                    END

!------------------------------------------------------------
! Utility Class Declaration
!------------------------------------------------------------
UtilityClass        CLASS,TYPE
! Properties
DebugEnabled          BYTE
LogQueue              &ErrorLogQueue
! Methods
Construct             PROCEDURE
Destruct              PROCEDURE
Init                  PROCEDURE(BYTE pDebugMode)
IsEmpty               PROCEDURE(STRING pValue),BYTE
IsNumeric             PROCEDURE(STRING pValue),BYTE
FormatPhone           PROCEDURE(STRING pPhone),STRING
FormatZipCode         PROCEDURE(STRING pZip),STRING
ParseDelimited        PROCEDURE(STRING pSource, STRING pDelim, LONG pIndex),STRING
                    END

!------------------------------------------------------------
! Procedure Prototypes
!------------------------------------------------------------
  MAP
    MODULE('utility_funcs')
      ValidateEmail     PROCEDURE(STRING pEmail),BYTE
      ValidatePhone     PROCEDURE(STRING pPhone),BYTE
      GenerateGUID      PROCEDURE,STRING
      EncodeBase64      PROCEDURE(STRING pInput),STRING
      DecodeBase64      PROCEDURE(STRING pInput),STRING
      HashMD5           PROCEDURE(STRING pInput),STRING
      GetEnvironment    PROCEDURE(STRING pVarName),STRING
      WriteLog          PROCEDURE(STRING pMessage, STRING pFileName)
      ShowError         PROCEDURE(STRING pMessage, <STRING pTitle>)
      ShowInfo          PROCEDURE(STRING pMessage, <STRING pTitle>)
      AskYesNo          PROCEDURE(STRING pQuestion, <STRING pTitle>),BYTE
    END
  END

!------------------------------------------------------------
! Macro Definitions (compile-time text substitution)
!------------------------------------------------------------
TRACE(msg)          EQUATE(IF DEBUG_MODE THEN WriteLog(msg,'debug.log') END)
ASSERT(cond,msg)    EQUATE(IF NOT (cond) THEN ShowError(msg,'Assertion Failed') END)

! End of include guard
  !_INCLUDE_EXAMPLE_INC_
