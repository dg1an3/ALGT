  PROGRAM

! ============================================================================
! PenBeamEdit Simple - Pencil Beam Dose Viewer (simplified)
! Port of dH/PenBeamEdit to Clarion
!
! Displays density + dose overlay in a Clarion WINDOW.
! Uses RtModelLib for data management.
! No DVH graph - just the density/dose color visualization.
! ============================================================================

  INCLUDE('EQUATES.CLW')

  MAP
    MODULE('RtModelLib')
      PlanInit(LONG gridW, LONG gridH, LONG gridD),LONG,C,NAME('PlanInit')
      PlanClose(),LONG,C,NAME('PlanClose')
      PlanGetGridW(),LONG,C,NAME('PlanGetGridW')
      PlanGetGridH(),LONG,C,NAME('PlanGetGridH')
      PlanSetDensity(LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetDensity')
      PlanGetDensity(LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetDensity')
      PlanAddBeam(REAL weight, REAL gantry, REAL collim, REAL couch),LONG,C,NAME('PlanAddBeam')
      PlanGetBeamCount(),LONG,C,NAME('PlanGetBeamCount')
      PlanSetBeamDose(LONG beamIdx, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetBeamDose')
      PlanSetBeamWeight(LONG beamIdx, REAL weight),LONG,C,NAME('PlanSetBeamWeight')
      PlanAccumulateDose(),LONG,C,NAME('PlanAccumulateDose')
      PlanGetDose(LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetDose')
      PlanNormalizeDose(),LONG,C,NAME('PlanNormalizeDose')
      PlanAddStructure(LONG structType, LONG r, LONG g, LONG b),LONG,C,NAME('PlanAddStructure')
      PlanSetRegionVoxel(LONG structIdx, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetRegionVoxel')
    END
    MODULE('GDI32')
      GdiSetPixel(LONG hdc, LONG x, LONG y, LONG color),LONG,PASCAL,NAME('SetPixel')
    END
    MODULE('USER32')
      GetDC(LONG hwnd),LONG,PASCAL,NAME('GetDC')
      ReleaseDC(LONG hwnd, LONG hdc),LONG,PASCAL,NAME('ReleaseDC')
    END
    GenerateTestData()
    LoadImportData(STRING dirPath)
    DrawDoseOverlay()
    LocalExp(REAL val),REAL
  END

! --- Rainbow colormap (256 entries, RGB packed as LONG) ---
ColormapR  LONG,DIM(256)
ColormapG  LONG,DIM(256)
ColormapB  LONG,DIM(256)

! --- Display state ---
GridSize     LONG(0)
PixelSize    LONG(4)
DataLoaded   LONG(0)
ImportDir    STRING(260)

! --- Main window ---
MainWin WINDOW('PenBeam Edit - Simple'),AT(,,640,480),SYSTEM,MAX,RESIZE
         MENUBAR
           MENU('&File')
             ITEM('&Import Data...'),USE(?MenuImport)
             ITEM('Generate &Test Data'),USE(?MenuTestData)
             ITEM,SEPARATOR
             ITEM('E&xit'),USE(?MenuExit)
           END
         END
         IMAGE,AT(0,25,640,455),USE(?DoseImage)
       END

  CODE
  ! Initialize rainbow colormap
  LOOP I# = 0 TO 255
    ! Blue -> Cyan -> Green -> Yellow -> Red
    IF I# < 64
      ColormapR[I#+1] = 0
      ColormapG[I#+1] = I# * 4
      ColormapB[I#+1] = 255
    ELSIF I# < 128
      ColormapR[I#+1] = 0
      ColormapG[I#+1] = 255
      ColormapB[I#+1] = 255 - (I# - 64) * 4
    ELSIF I# < 192
      ColormapR[I#+1] = (I# - 128) * 4
      ColormapG[I#+1] = 255
      ColormapB[I#+1] = 0
    ELSE
      ColormapR[I#+1] = 255
      ColormapG[I#+1] = 255 - (I# - 192) * 4
      ColormapB[I#+1] = 0
    END
  END

  OPEN(MainWin)
  ACCEPT
    CASE ACCEPTED()
    OF ?MenuExit
      BREAK
    OF ?MenuTestData
      GenerateTestData()
      DrawDoseOverlay()
    OF ?MenuImport
      ! File dialog for import directory
      ImportDir = ''
      ! TODO: Use FILEDIALOG for directory selection
      ! For now, generate test data
      MESSAGE('Import not yet implemented.|Use Generate Test Data instead.','Info')
    END
  END
  IF DataLoaded = 1
    PlanClose()
  END

! ============================================================================
! LocalExp - Taylor series exp(val) since Clarion has no built-in EXP
! ============================================================================

LocalExp PROCEDURE(REAL val)
Result REAL(1)
Term   REAL(1)
Idx    LONG
  CODE
  LOOP Idx = 1 TO 30
    Term *= val / Idx
    Result += Term
    IF ABS(Term) < 1.0e-15 THEN BREAK.
  END
  RETURN Result

! ============================================================================
! Generate synthetic test data (like the C++ Gaussian pencil beams)
! ============================================================================

GenerateTestData PROCEDURE()
I        LONG
X        LONG
Y        LONG
GridW    LONG(64)
BeamIdx  LONG
Weight   REAL
PI       REAL(3.14159265358979)
SIGMA    REAL(7.0)
Dist     REAL
DoseVal  REAL
  CODE
  ! Initialize plan with 64x64 grid
  PlanInit(GridW, GridW, 1)
  GridSize = GridW
  DataLoaded = 1

  ! Create density field (circular phantom)
  LOOP Y = 0 TO GridW - 1
    LOOP X = 0 TO GridW - 1
      Dist = SQRT((X - 32) * (X - 32) + (Y - 32) * (Y - 32))
      IF Dist < 28
        PlanSetDensity(X, Y, 0, 1000)    ! Water-equivalent density
      ELSE
        PlanSetDensity(X, Y, 0, 0)        ! Air
      END
    END
  END

  ! Create structure (target region, column at x=45..55)
  PlanAddStructure(1, 255, 0, 0)   ! Target, red
  LOOP Y = 0 TO GridW - 1
    LOOP X = 0 TO GridW - 1
      IF X > 45 AND X < 55
        PlanSetRegionVoxel(1, X, Y, 0, 1)
      END
    END
  END

  ! Create 99 pencil beams with Gaussian weights
  LOOP I = 1 TO 99
    Weight = 1.0 / SQRT(2 * PI * SIGMA) * LocalExp(-1.0 * (50 - I) * (50 - I) / (SIGMA * SIGMA))
    BeamIdx = PlanAddBeam(Weight, 0, 0, 0)
    ! Each pencil beam: dose deposited in column I with exponential falloff
    LOOP Y = 0 TO GridW - 1
      LOOP X = 0 TO GridW - 1
        ! Simple pencil beam: Gaussian lateral spread centered at beam position
        Dist = ABS(X - I * GridW / 100.0)
        DoseVal = LocalExp(-Dist * Dist / 8.0)
        ! Depth attenuation
        DoseVal *= LocalExp(-Y * 0.03)
        PlanSetBeamDose(BeamIdx, X, Y, 0, DoseVal)
      END
    END
  END

  ! Accumulate and normalize
  PlanAccumulateDose()
  PlanNormalizeDose()

  RETURN

! ============================================================================
! Load imported ASCII data (placeholder for future file import)
! ============================================================================

LoadImportData PROCEDURE(STRING dirPath)
  CODE
  ! Future: read density.dat and dose*.dat files from dirPath
  RETURN

! ============================================================================
! Draw dose overlay on the IMAGE control
! Uses Windows GDI SetPixel via GetDC on the IMAGE control handle
! ============================================================================

DrawDoseOverlay PROCEDURE()
X         LONG
Y         LONG
Dose      REAL
Density   REAL
ColorIdx  LONG
R         LONG
G         LONG
B         LONG
PixColor  LONG
ImgW      LONG
ImgH      LONG
PxSz      LONG
DrawX     LONG
DrawY     LONG
DX        LONG
DY        LONG
hWnd      LONG
hDC       LONG
  CODE
  IF DataLoaded = 0 THEN RETURN.
  IF GridSize = 0 THEN RETURN.

  ! Get the IMAGE control's window handle and device context
  hWnd = ?DoseImage{PROP:Handle}
  hDC = GetDC(hWnd)
  IF hDC = 0 THEN RETURN.

  ! Calculate pixel size based on image control size
  ImgW = ?DoseImage{PROP:Width}
  ImgH = ?DoseImage{PROP:Height}
  PxSz = ImgW / GridSize
  IF ImgH / GridSize < PxSz THEN PxSz = ImgH / GridSize.
  IF PxSz < 1 THEN PxSz = 1.

  LOOP Y = 0 TO GridSize - 1
    LOOP X = 0 TO GridSize - 1
      ! Get dose (0..1 normalized) and density (0..1000)
      Dose = PlanGetDose(X, Y, 0)
      Density = PlanGetDensity(X, Y, 0)

      ! Map dose to colormap index
      ColorIdx = INT(Dose * 255) + 1
      IF ColorIdx > 256 THEN ColorIdx = 256.
      IF ColorIdx < 1 THEN ColorIdx = 1.

      ! Get color from rainbow colormap
      R = ColormapR[ColorIdx]
      G = ColormapG[ColorIdx]
      B = ColormapB[ColorIdx]

      ! Modulate by density (density/1000)
      R = INT(R * Density / 1000)
      G = INT(G * Density / 1000)
      B = INT(B * Density / 1000)

      ! Pack as RGB LONG for SetPixel (0x00BBGGRR)
      PixColor = BOR(R, BSHIFT(G, 8))
      PixColor = BOR(PixColor, BSHIFT(B, 16))

      ! Draw pixel block
      DrawX = X * PxSz
      DrawY = Y * PxSz
      LOOP DY = 0 TO PxSz - 1
        LOOP DX = 0 TO PxSz - 1
          GdiSetPixel(hDC, DrawX + DX, DrawY + DY, PixColor)
        END
      END
    END
  END

  ReleaseDC(hWnd, hDC)

  RETURN
