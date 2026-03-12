  MEMBER()

! ============================================================================
! GraphLib - 2D Graph/DVH Plotting Library for Clarion
! Port of dH/Graph (CGraph, CDataSeries)
!
! Manages data series and provides coordinate transformation for plotting.
! Uses flat arrays to avoid nested DIM limitations.
! ============================================================================

MAX_SERIES      EQUATE(8)
MAX_POINTS      EQUATE(1024)

! --- Series metadata (flat arrays) ---
DsInUse       LONG,DIM(MAX_SERIES)
DsNumPoints   LONG,DIM(MAX_SERIES)
DsColorR      LONG,DIM(MAX_SERIES)
DsColorG      LONG,DIM(MAX_SERIES)
DsColorB      LONG,DIM(MAX_SERIES)

! --- Point data (flat: (seriesIdx-1)*MAX_POINTS + ptIdx) ---
DsPointX      REAL,DIM(MAX_SERIES * MAX_POINTS)
DsPointY      REAL,DIM(MAX_SERIES * MAX_POINTS)

! --- Graph state (single GROUP, no DIM) ---
GrNumSeries   LONG(0)
GrMinX        REAL(0)
GrMaxX        REAL(100)
GrMinY        REAL(0)
GrMaxY        REAL(100)
GrMajorX      REAL(20)
GrMajorY      REAL(20)
GrMinorX      REAL(10)
GrMinorY      REAL(10)
GrMarginL     LONG(40)
GrMarginT     LONG(10)
GrMarginR     LONG(10)
GrMarginB     LONG(30)

  MAP
    GraphInit(),LONG,C,NAME('GraphInit'),EXPORT
    GraphClear(),LONG,C,NAME('GraphClear'),EXPORT
    GraphSetAxes(REAL minX, REAL maxX, REAL minY, REAL maxY),LONG,C,NAME('GraphSetAxes'),EXPORT
    GraphSetTicks(REAL majorX, REAL majorY, REAL minorX, REAL minorY),LONG,C,NAME('GraphSetTicks'),EXPORT
    GraphSetMargins(LONG left, LONG top, LONG right, LONG bottom),LONG,C,NAME('GraphSetMargins'),EXPORT
    GraphAutoScale(),LONG,C,NAME('GraphAutoScale'),EXPORT
    GraphAddSeries(LONG colorR, LONG colorG, LONG colorB),LONG,C,NAME('GraphAddSeries'),EXPORT
    GraphRemoveSeries(LONG seriesIdx),LONG,C,NAME('GraphRemoveSeries'),EXPORT
    GraphRemoveAllSeries(),LONG,C,NAME('GraphRemoveAllSeries'),EXPORT
    GraphGetSeriesCount(),LONG,C,NAME('GraphGetSeriesCount'),EXPORT
    GraphAddPoint(LONG seriesIdx, REAL x, REAL y),LONG,C,NAME('GraphAddPoint'),EXPORT
    GraphGetPointCount(LONG seriesIdx),LONG,C,NAME('GraphGetPointCount'),EXPORT
    GraphGetPointX(LONG seriesIdx, LONG ptIdx),REAL,C,NAME('GraphGetPointX'),EXPORT
    GraphGetPointY(LONG seriesIdx, LONG ptIdx),REAL,C,NAME('GraphGetPointY'),EXPORT
    GraphClearPoints(LONG seriesIdx),LONG,C,NAME('GraphClearPoints'),EXPORT
    GraphToPixelX(REAL dataX, LONG plotWidth),LONG,C,NAME('GraphToPixelX'),EXPORT
    GraphToPixelY(REAL dataY, LONG plotHeight),LONG,C,NAME('GraphToPixelY'),EXPORT
    GraphFromPixelX(LONG pixelX, LONG plotWidth),REAL,C,NAME('GraphFromPixelX'),EXPORT
    GraphFromPixelY(LONG pixelY, LONG plotHeight),REAL,C,NAME('GraphFromPixelY'),EXPORT
    GraphGetMinX(),REAL,C,NAME('GraphGetMinX'),EXPORT
    GraphGetMaxX(),REAL,C,NAME('GraphGetMaxX'),EXPORT
    GraphGetMinY(),REAL,C,NAME('GraphGetMinY'),EXPORT
    GraphGetMaxY(),REAL,C,NAME('GraphGetMaxY'),EXPORT
    GraphGetMajorX(),REAL,C,NAME('GraphGetMajorX'),EXPORT
    GraphGetMajorY(),REAL,C,NAME('GraphGetMajorY'),EXPORT
  END

! ============================================================================
! Implementation
! ============================================================================

GraphInit PROCEDURE()
I LONG
  CODE
  GrNumSeries = 0
  LOOP I = 1 TO MAX_SERIES
    DsInUse[I] = 0
    DsNumPoints[I] = 0
  END
  GrMinX = 0
  GrMaxX = 100
  GrMinY = 0
  GrMaxY = 100
  GrMajorX = 20
  GrMajorY = 20
  RETURN 0

GraphClear PROCEDURE()
  CODE
  RETURN GraphInit()

GraphSetAxes PROCEDURE(REAL minX, REAL maxX, REAL minY, REAL maxY)
  CODE
  GrMinX = minX
  GrMaxX = maxX
  GrMinY = minY
  GrMaxY = maxY
  RETURN 0

GraphSetTicks PROCEDURE(REAL majorX, REAL majorY, REAL minorX, REAL minorY)
  CODE
  GrMajorX = majorX
  GrMajorY = majorY
  GrMinorX = minorX
  GrMinorY = minorY
  RETURN 0

GraphSetMargins PROCEDURE(LONG left, LONG top, LONG right, LONG bottom)
  CODE
  GrMarginL = left
  GrMarginT = top
  GrMarginR = right
  GrMarginB = bottom
  RETURN 0

GraphAutoScale PROCEDURE()
I     LONG
J     LONG
Base  LONG
First LONG(1)
PX    REAL
PY    REAL
  CODE
  LOOP I = 1 TO MAX_SERIES
    IF DsInUse[I] = 1 AND DsNumPoints[I] > 0
      Base = (I - 1) * MAX_POINTS
      LOOP J = 1 TO DsNumPoints[I]
        PX = DsPointX[Base + J]
        PY = DsPointY[Base + J]
        IF First = 1
          GrMinX = PX
          GrMaxX = PX
          GrMinY = PY
          GrMaxY = PY
          First = 0
        ELSE
          IF PX < GrMinX THEN GrMinX = PX.
          IF PX > GrMaxX THEN GrMaxX = PX.
          IF PY < GrMinY THEN GrMinY = PY.
          IF PY > GrMaxY THEN GrMaxY = PY.
        END
      END
    END
  END
  IF GrMaxX > GrMinX
    GrMaxX += (GrMaxX - GrMinX) * 0.1
  END
  IF GrMaxY > GrMinY
    GrMaxY += (GrMaxY - GrMinY) * 0.1
  END
  RETURN 0

GraphAddSeries PROCEDURE(LONG colorR, LONG colorG, LONG colorB)
I LONG
  CODE
  LOOP I = 1 TO MAX_SERIES
    IF DsInUse[I] = 0
      DsInUse[I] = 1
      DsNumPoints[I] = 0
      DsColorR[I] = colorR
      DsColorG[I] = colorG
      DsColorB[I] = colorB
      GrNumSeries += 1
      RETURN I
    END
  END
  RETURN -1

GraphRemoveSeries PROCEDURE(LONG seriesIdx)
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN -1.
  IF DsInUse[seriesIdx] = 0 THEN RETURN -1.
  DsInUse[seriesIdx] = 0
  DsNumPoints[seriesIdx] = 0
  GrNumSeries -= 1
  RETURN 0

GraphRemoveAllSeries PROCEDURE()
I LONG
  CODE
  LOOP I = 1 TO MAX_SERIES
    DsInUse[I] = 0
    DsNumPoints[I] = 0
  END
  GrNumSeries = 0
  RETURN 0

GraphGetSeriesCount PROCEDURE()
  CODE
  RETURN GrNumSeries

GraphAddPoint PROCEDURE(LONG seriesIdx, REAL x, REAL y)
N    LONG
Base LONG
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN -1.
  IF DsInUse[seriesIdx] = 0 THEN RETURN -1.
  IF DsNumPoints[seriesIdx] >= MAX_POINTS THEN RETURN -2.
  DsNumPoints[seriesIdx] += 1
  N = DsNumPoints[seriesIdx]
  Base = (seriesIdx - 1) * MAX_POINTS
  DsPointX[Base + N] = x
  DsPointY[Base + N] = y
  RETURN 0

GraphGetPointCount PROCEDURE(LONG seriesIdx)
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN 0.
  IF DsInUse[seriesIdx] = 0 THEN RETURN 0.
  RETURN DsNumPoints[seriesIdx]

GraphGetPointX PROCEDURE(LONG seriesIdx, LONG ptIdx)
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN 0.
  IF ptIdx < 1 OR ptIdx > DsNumPoints[seriesIdx] THEN RETURN 0.
  RETURN DsPointX[(seriesIdx - 1) * MAX_POINTS + ptIdx]

GraphGetPointY PROCEDURE(LONG seriesIdx, LONG ptIdx)
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN 0.
  IF ptIdx < 1 OR ptIdx > DsNumPoints[seriesIdx] THEN RETURN 0.
  RETURN DsPointY[(seriesIdx - 1) * MAX_POINTS + ptIdx]

GraphClearPoints PROCEDURE(LONG seriesIdx)
  CODE
  IF seriesIdx < 1 OR seriesIdx > MAX_SERIES THEN RETURN -1.
  DsNumPoints[seriesIdx] = 0
  RETURN 0

GraphToPixelX PROCEDURE(REAL dataX, LONG plotWidth)
Range REAL
  CODE
  Range = GrMaxX - GrMinX
  IF Range = 0 THEN RETURN GrMarginL.
  RETURN GrMarginL + INT((dataX - GrMinX) / Range * (plotWidth - GrMarginL - GrMarginR))

GraphToPixelY PROCEDURE(REAL dataY, LONG plotHeight)
Range REAL
  CODE
  Range = GrMaxY - GrMinY
  IF Range = 0 THEN RETURN plotHeight - GrMarginB.
  RETURN GrMarginT + INT((1.0 - (dataY - GrMinY) / Range) * (plotHeight - GrMarginT - GrMarginB))

GraphFromPixelX PROCEDURE(LONG pixelX, LONG plotWidth)
PlotW LONG
  CODE
  PlotW = plotWidth - GrMarginL - GrMarginR
  IF PlotW <= 0 THEN RETURN GrMinX.
  RETURN GrMinX + (pixelX - GrMarginL) * (GrMaxX - GrMinX) / PlotW

GraphFromPixelY PROCEDURE(LONG pixelY, LONG plotHeight)
PlotH LONG
  CODE
  PlotH = plotHeight - GrMarginT - GrMarginB
  IF PlotH <= 0 THEN RETURN GrMinY.
  RETURN GrMaxY - (pixelY - GrMarginT) * (GrMaxY - GrMinY) / PlotH

GraphGetMinX PROCEDURE()
  CODE
  RETURN GrMinX

GraphGetMaxX PROCEDURE()
  CODE
  RETURN GrMaxX

GraphGetMinY PROCEDURE()
  CODE
  RETURN GrMinY

GraphGetMaxY PROCEDURE()
  CODE
  RETURN GrMaxY

GraphGetMajorX PROCEDURE()
  CODE
  RETURN GrMajorX

GraphGetMajorY PROCEDURE()
  CODE
  RETURN GrMajorY
