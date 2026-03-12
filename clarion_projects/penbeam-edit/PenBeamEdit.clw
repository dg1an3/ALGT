  PROGRAM

! ============================================================================
! PenBeamEdit Complete - Pencil Beam Dose Viewer with DVH
! Port of dH/PenBeamEdit to Clarion
!
! Left half: density + dose color overlay
! Right half: DVH (cumulative dose-volume histogram) graph
! Uses RtModelLib for plan data and GraphLib for DVH plotting.
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
      PlanGetMaxDose(),REAL,C,NAME('PlanGetMaxDose')
      PlanNormalizeDose(),LONG,C,NAME('PlanNormalizeDose')
      PlanAddStructure(LONG structType, LONG r, LONG g, LONG b),LONG,C,NAME('PlanAddStructure')
      PlanSetRegionVoxel(LONG structIdx, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetRegionVoxel')
      HistCompute(LONG structIdx),LONG,C,NAME('HistCompute')
      HistGetBinCount(),LONG,C,NAME('HistGetBinCount')
      HistGetCumBinValue(LONG binIdx),REAL,C,NAME('HistGetCumBinValue')
    END
    MODULE('GraphLib')
      GraphInit(),LONG,C,NAME('GraphInit')
      GraphSetAxes(REAL minX, REAL maxX, REAL minY, REAL maxY),LONG,C,NAME('GraphSetAxes')
      GraphSetTicks(REAL majorX, REAL majorY, REAL minorX, REAL minorY),LONG,C,NAME('GraphSetTicks')
      GraphAddSeries(LONG colorR, LONG colorG, LONG colorB),LONG,C,NAME('GraphAddSeries')
      GraphRemoveAllSeries(),LONG,C,NAME('GraphRemoveAllSeries')
      GraphAddPoint(LONG seriesIdx, REAL x, REAL y),LONG,C,NAME('GraphAddPoint')
      GraphGetSeriesCount(),LONG,C,NAME('GraphGetSeriesCount')
      GraphGetPointCount(LONG seriesIdx),LONG,C,NAME('GraphGetPointCount')
      GraphGetPointX(LONG seriesIdx, LONG ptIdx),REAL,C,NAME('GraphGetPointX')
      GraphGetPointY(LONG seriesIdx, LONG ptIdx),REAL,C,NAME('GraphGetPointY')
      GraphToPixelX(REAL dataX, LONG plotWidth),LONG,C,NAME('GraphToPixelX')
      GraphToPixelY(REAL dataY, LONG plotHeight),LONG,C,NAME('GraphToPixelY')
      GraphGetMinX(),REAL,C,NAME('GraphGetMinX')
      GraphGetMaxX(),REAL,C,NAME('GraphGetMaxX')
      GraphGetMajorX(),REAL,C,NAME('GraphGetMajorX')
      GraphGetMajorY(),REAL,C,NAME('GraphGetMajorY')
    END
    GenerateTestData()
    DrawDoseOverlay()
    DrawDVH()
    UpdateDisplay()
    EXP(REAL),REAL
  END

! --- Rainbow colormap ---
ColormapR  LONG,DIM(256)
ColormapG  LONG,DIM(256)
ColormapB  LONG,DIM(256)

! --- Display state ---
GridSize     LONG(0)
DataLoaded   LONG(0)
DVHSeriesIdx LONG(0)

! --- Main window with split layout ---
MainWin WINDOW('PenBeam Edit'),AT(,,800,500),SYSTEM,MAX,RESIZE
         MENUBAR
           MENU('&File')
             ITEM('Generate &Test Data'),USE(?MenuTestData)
             ITEM,SEPARATOR
             ITEM('E&xit'),USE(?MenuExit)
           END
         END
         IMAGE,AT(0,25,400,475),USE(?DoseImage)
         IMAGE,AT(400,25,400,475),USE(?DVHImage)
         STRING('Dose (cGy)'),AT(550,478),USE(?LabelX)
         STRING('Volume %'),AT(405,28),USE(?LabelY)
       END

  CODE
  ! Initialize rainbow colormap
  LOOP I# = 0 TO 255
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

  GraphInit()
  OPEN(MainWin)

  ACCEPT
    CASE ACCEPTED()
    OF ?MenuExit
      BREAK
    OF ?MenuTestData
      GenerateTestData()
      UpdateDisplay()
    END
  END
  IF DataLoaded = 1
    PlanClose()
  END

! ============================================================================
! EXP function (Taylor series)
! ============================================================================

EXP PROCEDURE(REAL val)
Result REAL(1)
Term   REAL(1)
I      LONG
  CODE
  LOOP I = 1 TO 30
    Term *= val / I
    Result += Term
    IF ABS(Term) < 1.0e-15 THEN BREAK.
  END
  RETURN Result

! ============================================================================
! Generate synthetic test data
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
  PlanInit(GridW, GridW, 1)
  GridSize = GridW
  DataLoaded = 1

  ! Circular phantom density
  LOOP Y = 0 TO GridW - 1
    LOOP X = 0 TO GridW - 1
      Dist = SQRT((X - 32) * (X - 32) + (Y - 32) * (Y - 32))
      IF Dist < 28
        PlanSetDensity(X, Y, 0, 1000)
      ELSE
        PlanSetDensity(X, Y, 0, 0)
      END
    END
  END

  ! Target structure (column x=45..55)
  PlanAddStructure(1, 255, 0, 0)
  LOOP Y = 0 TO GridW - 1
    LOOP X = 0 TO GridW - 1
      IF X > 45 AND X < 55
        PlanSetRegionVoxel(1, X, Y, 0, 1)
      END
    END
  END

  ! 99 pencil beams with Gaussian weights
  LOOP I = 1 TO 99
    Weight = 1.0 / SQRT(2 * PI * SIGMA) * EXP(-1.0 * (50 - I) * (50 - I) / (SIGMA * SIGMA))
    BeamIdx = PlanAddBeam(Weight, 0, 0, 0)
    LOOP Y = 0 TO GridW - 1
      LOOP X = 0 TO GridW - 1
        Dist = ABS(X - I * GridW / 100.0)
        DoseVal = EXP(-Dist * Dist / 8.0) * EXP(-Y * 0.03)
        PlanSetBeamDose(BeamIdx, X, Y, 0, DoseVal)
      END
    END
  END

  PlanAccumulateDose()
  PlanNormalizeDose()

  ! Compute DVH for structure 1
  HistCompute(1)

  RETURN

! ============================================================================
! Update both displays
! ============================================================================

UpdateDisplay PROCEDURE()
  CODE
  DrawDoseOverlay()
  DrawDVH()
  RETURN

! ============================================================================
! Draw dose/density overlay on left IMAGE
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
  CODE
  IF DataLoaded = 0 THEN RETURN.
  IF GridSize = 0 THEN RETURN.

  ImgW = ?DoseImage{PROP:Width}
  ImgH = ?DoseImage{PROP:Height}
  PxSz = ImgW / GridSize
  IF ImgH / GridSize < PxSz THEN PxSz = ImgH / GridSize.
  IF PxSz < 1 THEN PxSz = 1.

  LOOP Y = 0 TO GridSize - 1
    LOOP X = 0 TO GridSize - 1
      Dose = PlanGetDose(X, Y, 0)
      Density = PlanGetDensity(X, Y, 0)

      ColorIdx = INT(Dose * 255) + 1
      IF ColorIdx > 256 THEN ColorIdx = 256.
      IF ColorIdx < 1 THEN ColorIdx = 1.

      R = ColormapR[ColorIdx]
      G = ColormapG[ColorIdx]
      B = ColormapB[ColorIdx]

      R = INT(R * Density / 1000)
      G = INT(G * Density / 1000)
      B = INT(B * Density / 1000)

      PixColor = BOR(R, BSHIFT(G, 8))
      PixColor = BOR(PixColor, BSHIFT(B, 16))

      DrawX = X * PxSz
      DrawY = Y * PxSz
      LOOP DY = 0 TO PxSz - 1
        LOOP DX = 0 TO PxSz - 1
          ?DoseImage{PROP:Pixel, DrawX + DX, DrawY + DY} = PixColor
        END
      END
    END
  END
  RETURN

! ============================================================================
! Draw DVH graph on right IMAGE
! ============================================================================

DrawDVH PROCEDURE()
I          LONG
BinCount   LONG
CumVal     REAL
DoseVal    REAL
SeriesIdx  LONG
NumPts     LONG
PtX1       LONG
PtY1       LONG
PtX2       LONG
PtY2       LONG
ImgW       LONG
ImgH       LONG
PixColor   LONG
TickX      REAL
TickY      REAL
TX         LONG
TY         LONG
  CODE
  IF DataLoaded = 0 THEN RETURN.

  ImgW = ?DVHImage{PROP:Width}
  ImgH = ?DVHImage{PROP:Height}

  ! Clear DVH image to white
  PixColor = 0FFFFFFh   ! White
  LOOP TY = 0 TO ImgH - 1
    LOOP TX = 0 TO ImgW - 1
      ?DVHImage{PROP:Pixel, TX, TY} = PixColor
    END
  END

  ! Setup graph axes: X = 0..1000 cGy, Y = 0..100%
  GraphRemoveAllSeries()
  GraphSetAxes(0, 1000, 0, 100)
  GraphSetTicks(200, 20, 100, 10)

  ! Add DVH data series (red line)
  SeriesIdx = GraphAddSeries(255, 0, 0)
  BinCount = HistGetBinCount()
  LOOP I = 1 TO BinCount
    CumVal = HistGetCumBinValue(I)
    DoseVal = 1000.0 * I / 256.0     ! Scale to cGy (matching C++ code)
    GraphAddPoint(SeriesIdx, DoseVal, CumVal * 100.0)
  END

  ! Draw grid lines (gray)
  PixColor = 0C0C0C0h   ! Light gray
  TickX = 0
  LOOP WHILE TickX <= 1000
    TX = GraphToPixelX(TickX, ImgW)
    IF TX >= 0 AND TX < ImgW
      LOOP TY = 0 TO ImgH - 1
        ?DVHImage{PROP:Pixel, TX, TY} = PixColor
      END
    END
    TickX += 200
  END
  TickY = 0
  LOOP WHILE TickY <= 100
    TY = GraphToPixelY(TickY, ImgH)
    IF TY >= 0 AND TY < ImgH
      LOOP TX = 0 TO ImgW - 1
        ?DVHImage{PROP:Pixel, TX, TY} = PixColor
      END
    END
    TickY += 20
  END

  ! Draw DVH curve (red, connect consecutive points with line)
  PixColor = 0000FFh   ! Red (BGR)
  NumPts = GraphGetPointCount(SeriesIdx)
  IF NumPts > 1
    LOOP I = 1 TO NumPts - 1
      PtX1 = GraphToPixelX(GraphGetPointX(SeriesIdx, I), ImgW)
      PtY1 = GraphToPixelY(GraphGetPointY(SeriesIdx, I), ImgH)
      PtX2 = GraphToPixelX(GraphGetPointX(SeriesIdx, I+1), ImgW)
      PtY2 = GraphToPixelY(GraphGetPointY(SeriesIdx, I+1), ImgH)
      ! Draw line segment using Bresenham-like stepping
      IF PtX1 >= 0 AND PtX1 < ImgW AND PtY1 >= 0 AND PtY1 < ImgH
        ?DVHImage{PROP:Pixel, PtX1, PtY1} = PixColor
      END
      ! Simple horizontal stepping (DVH X is monotonically increasing)
      IF PtX2 > PtX1 AND PtX2 - PtX1 > 0
        LOOP TX = PtX1 TO PtX2
          IF PtX2 <> PtX1
            TY = PtY1 + (PtY2 - PtY1) * (TX - PtX1) / (PtX2 - PtX1)
          ELSE
            TY = PtY1
          END
          IF TX >= 0 AND TX < ImgW AND TY >= 0 AND TY < ImgH
            ?DVHImage{PROP:Pixel, TX, TY} = PixColor
            ! Make line 2px thick
            IF TY + 1 < ImgH
              ?DVHImage{PROP:Pixel, TX, TY + 1} = PixColor
            END
          END
        END
      END
    END
  END

  RETURN
