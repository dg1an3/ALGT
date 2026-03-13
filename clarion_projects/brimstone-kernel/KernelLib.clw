  MEMBER()

! ============================================================================
! KernelLib - Energy Deposition Kernel Reader
! Port of dH/RtModel CEnergyDepKernel kernel loading and interpolation
!
! Reads Fortran-generated dose spread arrays (e.g. 6MV_kernel.dat).
! After loading, incremental energy is cumulated per angle and
! interpolated to 1mm radial resolution (0-600 mm = 0-60 cm).
!
! Attenuation coefficients (mu, cm^-1):
!   2 MV:  0.04942
!   6 MV:  0.02770
!  15 MV:  0.01941
! ============================================================================

! --- Configuration ---
MAX_PHI         EQUATE(48)          ! max zenith angle bins
MAX_RAD         EQUATE(64)          ! max radial bins in file
MAX_INTERP      EQUATE(600)         ! interpolated table rows (1mm each, 60cm)

! --- Kernel state ---
KnLoaded        LONG(0)
KnNumPhi        LONG(0)
KnNumRad        LONG(0)
KnMu            REAL(0)
KnEnergy        LONG(0)

! Mean zenith angles (radians)
KnAngles        REAL,DIM(MAX_PHI)

! Radial boundaries (cm), index 0 = 0.0 stored at [1]
KnRadBounds     REAL,DIM(MAX_RAD + 1)

! Incremental energy from file
KnIncEnergy     REAL,DIM(MAX_PHI * MAX_RAD)

! Cumulative energy (per phi row)
KnCumEnergy     REAL,DIM(MAX_PHI * MAX_RAD)

! Interpolated cumulative energy at 1mm resolution
KnInterp        REAL,DIM(MAX_PHI * MAX_INTERP)

! Temporary buffer for collecting all numeric values
MAX_ALLVALS     EQUATE(4096)
KnAllVals       REAL,DIM(MAX_ALLVALS)

! File buffer: entire file loaded into memory
MAX_FILEBUF     EQUATE(100000)
KnFileBuf       BYTE,DIM(MAX_FILEBUF)

  MAP
    KernLoad(LONG energy),LONG,C,NAME('KernLoad'),EXPORT
    KernFree(),LONG,C,NAME('KernFree'),EXPORT
    KernGetNumPhi(),LONG,C,NAME('KernGetNumPhi'),EXPORT
    KernGetNumRad(),LONG,C,NAME('KernGetNumRad'),EXPORT
    KernGetMu(),REAL,C,NAME('KernGetMu'),EXPORT
    KernGetAngle(LONG idx),REAL,C,NAME('KernGetAngle'),EXPORT
    KernGetRadBound(LONG idx),REAL,C,NAME('KernGetRadBound'),EXPORT
    KernGetIncEnergy(LONG phi, LONG rad),REAL,C,NAME('KernGetIncEnergy'),EXPORT
    KernGetCumEnergy(LONG phi, LONG rad),REAL,C,NAME('KernGetCumEnergy'),EXPORT
    KernGetInterpEnergy(LONG phi, LONG radMM),REAL,C,NAME('KernGetInterpEnergy'),EXPORT
    KernGetInterpRows(),LONG,C,NAME('KernGetInterpRows'),EXPORT

    ! Internal helpers
    KnIdx(LONG phi, LONG rad),LONG
    KnInterpIdx(LONG phi, LONG radMM),LONG
    KnInterpCumEnergy(),LONG
    KnParseNextReal(*LONG pos, LONG bufLen),REAL
    KnSkipToNextLine(*LONG pos, LONG bufLen),LONG
    KnIsLetter(BYTE b),LONG

    MODULE('Win32')
      CreateFileA(*CSTRING, LONG, LONG, LONG, LONG, LONG, LONG),LONG,PASCAL,RAW,NAME('CreateFileA')
      ReadFile(LONG, LONG, LONG, *LONG, LONG),LONG,PASCAL,RAW,NAME('ReadFile')
      CloseHandle(LONG),LONG,PASCAL,NAME('CloseHandle')
      GetModuleFileNameA(LONG, *CSTRING, LONG),LONG,PASCAL,RAW,NAME('GetModuleFileNameA')
      GetModuleHandleA(*CSTRING),LONG,PASCAL,RAW,NAME('GetModuleHandleA')
    END
  END

! Win32 constants
INVALID_HANDLE  EQUATE(-1)
GENERIC_READ    EQUATE(080000000h)
OPEN_EXISTING   EQUATE(3)
FILE_SHARE_READ EQUATE(1)

! ============================================================================
! Flat index helpers
! ============================================================================

KnIdx PROCEDURE(LONG phi, LONG rad)
  CODE
  RETURN (phi - 1) * MAX_RAD + rad

KnInterpIdx PROCEDURE(LONG phi, LONG radMM)
  CODE
  RETURN (phi - 1) * MAX_INTERP + radMM

! ============================================================================
! Check if a byte value is an ASCII letter
! ============================================================================

KnIsLetter PROCEDURE(BYTE b)
  CODE
  IF (b >= 65 AND b <= 90) OR (b >= 97 AND b <= 122)
    RETURN 1
  END
  RETURN 0

! ============================================================================
! Skip to next line in buffer (advance past CR/LF)
! Returns number of bytes on the skipped line
! ============================================================================

KnSkipToNextLine PROCEDURE(*LONG pos, LONG bufLen)
start LONG
  CODE
  start = pos
  ! Scan forward until LF or end of buffer
  LOOP WHILE pos <= bufLen
    IF KnFileBuf[pos] = 10   ! LF
      pos += 1
      RETURN pos - start
    ELSIF KnFileBuf[pos] = 13  ! CR
      pos += 1
      ! Skip following LF if present
      IF pos <= bufLen AND KnFileBuf[pos] = 10
        pos += 1
      END
      RETURN pos - start
    END
    pos += 1
  END
  RETURN pos - start

! ============================================================================
! Parse next floating-point number from file buffer at pos
! Skips whitespace, newlines, and text header lines automatically.
! Handles scientific notation (E and D exponents).
! ============================================================================

KnParseNextReal PROCEDURE(*LONG pos, LONG bufLen)
start     LONG
numLen    LONG
numStr    CSTRING(64)
result    REAL
b         BYTE
lineStart LONG
firstNonSp LONG
  CODE
  LOOP
    ! Skip whitespace (spaces, tabs, CR, LF)
    LOOP WHILE pos <= bufLen
      b = KnFileBuf[pos]
      IF b = 32 OR b = 9 OR b = 13 OR b = 10  ! space, tab, CR, LF
        pos += 1
      ELSE
        BREAK
      END
    END
    IF pos > bufLen THEN RETURN 0.

    b = KnFileBuf[pos]

    ! Check if this is the start of a text line (letter at start-of-line)
    ! We detect this by checking: is the current position at the beginning
    ! of a line (preceded by LF or start of buffer)?
    ! If so and current char is a letter, skip the entire line.
    IF KnIsLetter(b) = 1
      ! Might be a text header — check if we're at start of a line
      ! (previous char was LF or this is the start of the buffer)
      IF pos = 1 OR KnFileBuf[pos - 1] = 10 OR KnFileBuf[pos - 1] = 13
        ! Definitely a text header line — skip it
        KnSkipToNextLine(pos, bufLen)
        CYCLE
      END
      ! Check if preceded only by spaces since last newline
      firstNonSp = pos
      lineStart = pos - 1
      LOOP WHILE lineStart >= 1
        IF KnFileBuf[lineStart] = 10 OR KnFileBuf[lineStart] = 13
          BREAK
        ELSIF KnFileBuf[lineStart] = 32 OR KnFileBuf[lineStart] = 9
          lineStart -= 1
        ELSE
          firstNonSp = lineStart
          BREAK
        END
      END
      IF firstNonSp = pos
        ! First non-space on this line is a letter — text header
        KnSkipToNextLine(pos, bufLen)
        CYCLE
      END
    END

    ! Try to collect number characters
    ! Valid: 0-9, '.', 'E', 'e', '+', '-', 'D', 'd'
    start = pos
    ! First char must be digit, '.', '+', or '-'
    IF (b >= 48 AND b <= 57) OR b = 46 OR b = 43 OR b = 45
      ! digit, '.', '+', '-'
      pos += 1
      LOOP WHILE pos <= bufLen
        b = KnFileBuf[pos]
        IF (b >= 48 AND b <= 57) OR b = 46 |                  ! digit, '.'
           OR b = 69 OR b = 101 |                              ! 'E', 'e'
           OR b = 68 OR b = 100 |                              ! 'D', 'd'
           OR b = 43 OR b = 45                                 ! '+', '-'
          pos += 1
        ELSE
          BREAK
        END
      END
      numLen = pos - start
      IF numLen > 63 THEN numLen = 63.
      ! Copy bytes to numStr
      LOOP I# = 1 TO numLen
        b = KnFileBuf[start + I# - 1]
        ! Replace 'D'/'d' exponent with 'E'
        IF b = 68 OR b = 100 THEN b = 69.  ! D/d -> E
        numStr[I#] = CHR(b)
      END
      numStr[numLen + 1] = '<0>'
      result = numStr
      RETURN result
    ELSE
      ! Unexpected character — skip it
      pos += 1
    END
  END

! ============================================================================
! KernLoad: Load kernel data file for given energy (2, 6, or 15 MV)
! ============================================================================

KernLoad PROCEDURE(LONG energy)
fh          LONG
pathBuf     CSTRING(512)
pathLen     LONG
lastSlash   LONG
fileName    CSTRING(64)
hModule     LONG
dllName     CSTRING(32)
bytesRead   LONG
bufLen      LONG
pos         LONG
nPhi        LONG
nRad        LONG
nTotal      LONG
nCollected  LONG
val         REAL
idx         LONG
prevIdx     LONG
  CODE
  ! Set attenuation coefficient based on energy
  CASE energy
  OF 2
    KnMu = 0.04942
    fileName = '2MV_kernel.dat'
  OF 6
    KnMu = 0.02770
    fileName = '6MV_kernel.dat'
  OF 15
    KnMu = 0.01941
    fileName = '15MV_kernel.dat'
  ELSE
    RETURN -1
  END
  KnEnergy = energy

  ! Build path: same directory as this DLL
  dllName = 'KernelLib.dll'
  hModule = GetModuleHandleA(dllName)
  IF hModule = 0
    hModule = 0
  END
  GetModuleFileNameA(hModule, pathBuf, 512)
  pathLen = LEN(CLIP(pathBuf))
  lastSlash = 0
  LOOP I# = 1 TO pathLen
    IF pathBuf[I#] = '\' OR pathBuf[I#] = '/'
      lastSlash = I#
    END
  END
  IF lastSlash > 0
    pathBuf = SUB(pathBuf, 1, lastSlash) & fileName
  ELSE
    pathBuf = fileName
  END

  ! Open and read entire file into buffer
  fh = CreateFileA(pathBuf, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0)
  IF fh = INVALID_HANDLE
    RETURN -2
  END
  bytesRead = 0
  ReadFile(fh, ADDRESS(KnFileBuf), MAX_FILEBUF, bytesRead, 0)
  CloseHandle(fh)
  bufLen = bytesRead
  IF bufLen = 0 THEN RETURN -2.

  ! Parse the file buffer.
  ! Structure: 3 header lines, then dimensions, then 3 more header lines,
  ! then all numeric values (energy + angles + radii) interspersed with
  ! text headers and blank lines.
  pos = 1

  ! Skip first 3 lines (header + blank + description)
  KnSkipToNextLine(pos, bufLen)
  KnSkipToNextLine(pos, bufLen)
  KnSkipToNextLine(pos, bufLen)

  ! Read NUM_PHI
  KnNumPhi = KnParseNextReal(pos, bufLen)

  ! Read NUM_RADIAL
  KnNumRad = KnParseNextReal(pos, bufLen)

  ! Validate dimensions
  IF KnNumPhi < 1 OR KnNumPhi > MAX_PHI OR KnNumRad < 1 OR KnNumRad > MAX_RAD
    RETURN -3
  END

  ! Read ALL remaining numeric values.
  ! KnParseNextReal automatically skips whitespace, newlines, and text headers.
  ! Expected: energy[NumPhi*NumRad] + angles[NumPhi] + radii[NumRad]
  nTotal = KnNumPhi * KnNumRad + KnNumPhi + KnNumRad
  nCollected = 0

  LOOP WHILE nCollected < nTotal AND pos <= bufLen
    val = KnParseNextReal(pos, bufLen)
    nCollected += 1
    KnAllVals[nCollected] = val
  END

  ! Partition: energy values
  idx = 0
  LOOP nPhi = 1 TO KnNumPhi
    LOOP nRad = 1 TO KnNumRad
      idx += 1
      KnIncEnergy[KnIdx(nPhi, nRad)] = KnAllVals[idx]
    END
  END

  ! Cumulate energy across radial direction
  LOOP nPhi = 1 TO KnNumPhi
    KnCumEnergy[KnIdx(nPhi, 1)] = KnIncEnergy[KnIdx(nPhi, 1)]
    LOOP nRad = 2 TO KnNumRad
      prevIdx = KnIdx(nPhi, nRad - 1)
      KnCumEnergy[KnIdx(nPhi, nRad)] = KnCumEnergy[prevIdx] + KnIncEnergy[KnIdx(nPhi, nRad)]
    END
  END

  ! Partition: angles
  LOOP nPhi = 1 TO KnNumPhi
    idx += 1
    KnAngles[nPhi] = KnAllVals[idx]
  END

  ! Partition: radial boundaries
  KnRadBounds[1] = 0.0
  LOOP nRad = 1 TO KnNumRad
    idx += 1
    KnRadBounds[nRad + 1] = KnAllVals[idx]
  END

  ! Interpolate to 1mm resolution
  KnInterpCumEnergy()

  KnLoaded = 1
  RETURN 0

! ============================================================================
! KnInterpCumEnergy: Interpolate cumulative energy to 1mm resolution
! ============================================================================

KnInterpCumEnergy PROCEDURE()
nPhi      LONG
nI        LONG
nRadial   LONG
radDist   REAL
incE      REAL
incDelta  REAL
loBound   REAL
hiBound   REAL
  CODE
  LOOP nPhi = 1 TO KnNumPhi
    KnInterp[KnInterpIdx(nPhi, 1)] = 0
    nRadial = 1
    LOOP nI = 2 TO MAX_INTERP
      radDist = 0.1 * (nI - 1)
      LOOP WHILE nRadial <= KnNumRad AND KnRadBounds[nRadial + 1] < radDist
        nRadial += 1
      END
      IF nRadial <= KnNumRad
        incE = KnCumEnergy[KnIdx(nPhi, nRadial)]
        IF nRadial < KnNumRad
          incDelta = KnCumEnergy[KnIdx(nPhi, nRadial + 1)] - incE
        ELSE
          incDelta = 0
        END
        loBound = KnRadBounds[nRadial]
        hiBound = KnRadBounds[nRadial + 1]
        IF hiBound > loBound
          incE += incDelta * (radDist - loBound) / (hiBound - loBound)
        END
        KnInterp[KnInterpIdx(nPhi, nI)] = incE
      ELSE
        KnInterp[KnInterpIdx(nPhi, nI)] = KnInterp[KnInterpIdx(nPhi, nI - 1)]
      END
    END
  END
  RETURN 0

! ============================================================================
! KernFree
! ============================================================================

KernFree PROCEDURE()
  CODE
  KnLoaded = 0
  KnNumPhi = 0
  KnNumRad = 0
  RETURN 0

! ============================================================================
! Accessors
! ============================================================================

KernGetNumPhi PROCEDURE()
  CODE
  RETURN KnNumPhi

KernGetNumRad PROCEDURE()
  CODE
  RETURN KnNumRad

KernGetMu PROCEDURE()
  CODE
  RETURN KnMu

KernGetAngle PROCEDURE(LONG idx)
  CODE
  IF idx < 1 OR idx > KnNumPhi THEN RETURN 0.
  RETURN KnAngles[idx]

KernGetRadBound PROCEDURE(LONG idx)
  CODE
  IF idx < 1 OR idx > KnNumRad + 1 THEN RETURN 0.
  RETURN KnRadBounds[idx]

KernGetIncEnergy PROCEDURE(LONG phi, LONG rad)
  CODE
  IF phi < 1 OR phi > KnNumPhi THEN RETURN 0.
  IF rad < 1 OR rad > KnNumRad THEN RETURN 0.
  RETURN KnIncEnergy[KnIdx(phi, rad)]

KernGetCumEnergy PROCEDURE(LONG phi, LONG rad)
  CODE
  IF phi < 1 OR phi > KnNumPhi THEN RETURN 0.
  IF rad < 1 OR rad > KnNumRad THEN RETURN 0.
  RETURN KnCumEnergy[KnIdx(phi, rad)]

KernGetInterpEnergy PROCEDURE(LONG phi, LONG radMM)
  CODE
  IF phi < 1 OR phi > KnNumPhi THEN RETURN 0.
  IF radMM < 1 OR radMM > MAX_INTERP THEN RETURN 0.
  RETURN KnInterp[KnInterpIdx(phi, radMM)]

KernGetInterpRows PROCEDURE()
  CODE
  RETURN MAX_INTERP
