  MEMBER()

DiagFile  FILE,DRIVER('DOS'),NAME('Diagnosis.dat'),CREATE,PRE(DX)
Record      RECORD
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
Description   CSTRING(256)
TStage        CSTRING(8)
NStage        CSTRING(8)
MStage        CSTRING(8)
OverallStage  CSTRING(8)
DiagDate      LONG
Status        LONG
ApprovedBy    CSTRING(64)
ApprovedDate  LONG
            END
          END

DiagBuf   GROUP,PRE(DB)
RecordID      LONG
PatientID     LONG
ICDCode       CSTRING(12)
Description   CSTRING(256)
TStage        CSTRING(8)
NStage        CSTRING(8)
MStage        CSTRING(8)
OverallStage  CSTRING(8)
DiagDate      LONG
Status        LONG
ApprovedBy    CSTRING(64)
ApprovedDate  LONG
          END

NextID    LONG(0)
FilePos   LONG(0)
TmpStr    CSTRING(256)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FindRecord(LONG id),LONG,PRIVATE
    CopyStr(LONG destPtr, LONG srcPtr, LONG maxLen),PRIVATE
    DSOpenStore(),LONG,C,NAME('DSOpenStore'),EXPORT
    DSCloseStore(),LONG,C,NAME('DSCloseStore'),EXPORT
    DSCreateDiagnosis(LONG,LONG,LONG,LONG,LONG,LONG,LONG,LONG),LONG,C,NAME('DSCreateDiagnosis'),EXPORT
    DSGetDiagnosis(LONG,LONG),LONG,C,NAME('DSGetDiagnosis'),EXPORT
    DSUpdateDiagnosis(LONG,LONG),LONG,C,NAME('DSUpdateDiagnosis'),EXPORT
    DSApproveDiagnosis(LONG,LONG),LONG,C,NAME('DSApproveDiagnosis'),EXPORT
    DSDeleteDiagnosis(LONG),LONG,C,NAME('DSDeleteDiagnosis'),EXPORT
    DSListByPatient(LONG,LONG,LONG,LONG),LONG,C,NAME('DSListByPatient'),EXPORT
  END

CopyStr PROCEDURE(LONG destPtr, LONG srcPtr, LONG maxLen)
  CODE
  MemCopy(destPtr, srcPtr, maxLen)

FindRecord PROCEDURE(LONG id)
  CODE
  SET(DiagFile)
  LOOP
    NEXT(DiagFile)
    IF ERRORCODE() THEN RETURN 0.
    IF DX:RecordID = id
      RETURN POINTER(DiagFile)
    END
  END
  RETURN 0

DSOpenStore PROCEDURE()
  CODE
  OPEN(DiagFile)
  IF ERRORCODE()
    CREATE(DiagFile)
    IF ERRORCODE() THEN RETURN -2.
    OPEN(DiagFile)
    IF ERRORCODE() THEN RETURN -2.
  END
  NextID = 0
  SET(DiagFile)
  LOOP
    NEXT(DiagFile)
    IF ERRORCODE() THEN BREAK.
    IF DX:RecordID >= NextID
      NextID = DX:RecordID
    END
  END
  NextID += 1
  RETURN 0

DSCloseStore PROCEDURE()
  CODE
  CLOSE(DiagFile)
  RETURN 0

DSCreateDiagnosis PROCEDURE(LONG patientID, LONG icdPtr, LONG descPtr, LONG tPtr, LONG nPtr, LONG mPtr, LONG oPtr, LONG diagDate)
  CODE
  CLEAR(DX:Record)
  DX:RecordID = NextID
  NextID += 1
  DX:PatientID = patientID
  CopyStr(ADDRESS(DX:ICDCode), icdPtr, 11)
  CopyStr(ADDRESS(DX:Description), descPtr, 255)
  CopyStr(ADDRESS(DX:TStage), tPtr, 7)
  CopyStr(ADDRESS(DX:NStage), nPtr, 7)
  CopyStr(ADDRESS(DX:MStage), mPtr, 7)
  CopyStr(ADDRESS(DX:OverallStage), oPtr, 7)
  IF diagDate = 0
    DX:DiagDate = TODAY()
  ELSE
    DX:DiagDate = diagDate
  END
  DX:Status = 0
  ADD(DiagFile)
  IF ERRORCODE() THEN RETURN -2.
  RETURN DX:RecordID

DSGetDiagnosis PROCEDURE(LONG id, LONG bufPtr)
  CODE
  FilePos = FindRecord(id)
  IF FilePos = 0 THEN RETURN -1.
  GET(DiagFile, FilePos)
  IF ERRORCODE() THEN RETURN -1.
  DB:RecordID = DX:RecordID
  DB:PatientID = DX:PatientID
  DB:ICDCode = DX:ICDCode
  DB:Description = DX:Description
  DB:TStage = DX:TStage
  DB:NStage = DX:NStage
  DB:MStage = DX:MStage
  DB:OverallStage = DX:OverallStage
  DB:DiagDate = DX:DiagDate
  DB:Status = DX:Status
  DB:ApprovedBy = DX:ApprovedBy
  DB:ApprovedDate = DX:ApprovedDate
  MemCopy(bufPtr, ADDRESS(DiagBuf), SIZE(DiagBuf))
  RETURN 0

DSUpdateDiagnosis PROCEDURE(LONG id, LONG bufPtr)
  CODE
  FilePos = FindRecord(id)
  IF FilePos = 0 THEN RETURN -1.
  GET(DiagFile, FilePos)
  IF ERRORCODE() THEN RETURN -1.
  IF DX:Status <> 0 THEN RETURN -3.
  MemCopy(ADDRESS(DiagBuf), bufPtr, SIZE(DiagBuf))
  DX:PatientID = DB:PatientID
  DX:ICDCode = DB:ICDCode
  DX:Description = DB:Description
  DX:TStage = DB:TStage
  DX:NStage = DB:NStage
  DX:MStage = DB:MStage
  DX:OverallStage = DB:OverallStage
  DX:DiagDate = DB:DiagDate
  PUT(DiagFile)
  IF ERRORCODE() THEN RETURN -2.
  RETURN 0

DSApproveDiagnosis PROCEDURE(LONG id, LONG namePtr)
  CODE
  FilePos = FindRecord(id)
  IF FilePos = 0 THEN RETURN -1.
  GET(DiagFile, FilePos)
  IF ERRORCODE() THEN RETURN -1.
  IF DX:Status <> 0 THEN RETURN -3.
  DX:Status = 1
  CopyStr(ADDRESS(DX:ApprovedBy), namePtr, 63)
  DX:ApprovedDate = TODAY()
  PUT(DiagFile)
  IF ERRORCODE() THEN RETURN -2.
  RETURN 0

DSDeleteDiagnosis PROCEDURE(LONG id)
  CODE
  FilePos = FindRecord(id)
  IF FilePos = 0 THEN RETURN -1.
  GET(DiagFile, FilePos)
  IF ERRORCODE() THEN RETURN -1.
  DX:Status = 2
  PUT(DiagFile)
  IF ERRORCODE() THEN RETURN -2.
  RETURN 0

DSListByPatient PROCEDURE(LONG patientID, LONG bufPtr, LONG maxCount, LONG outCountPtr)
Count  LONG(0)
Offset LONG(0)
  CODE
  SET(DiagFile)
  LOOP
    NEXT(DiagFile)
    IF ERRORCODE() THEN BREAK.
    IF Count >= maxCount THEN BREAK.
    IF DX:PatientID = patientID
      DB:RecordID = DX:RecordID
      DB:PatientID = DX:PatientID
      DB:ICDCode = DX:ICDCode
      DB:Description = DX:Description
      DB:TStage = DX:TStage
      DB:NStage = DX:NStage
      DB:MStage = DX:MStage
      DB:OverallStage = DX:OverallStage
      DB:DiagDate = DX:DiagDate
      DB:Status = DX:Status
      DB:ApprovedBy = DX:ApprovedBy
      DB:ApprovedDate = DX:ApprovedDate
      Offset = Count * SIZE(DiagBuf)
      MemCopy(bufPtr + Offset, ADDRESS(DiagBuf), SIZE(DiagBuf))
      Count += 1
    END
  END
  MemCopy(outCountPtr, ADDRESS(Count), SIZE(Count))
  RETURN 0
