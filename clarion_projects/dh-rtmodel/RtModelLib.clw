  MEMBER()

! ============================================================================
! RtModelLib - RT Treatment Planning Model Library for Clarion
! Port of dH/RT_MODEL (Plan, Series, Beam, Structure, Histogram)
!
! Self-contained model: density, beams, dose, structures, DVH histogram.
! Uses flat arrays with computed indexing.
! ============================================================================

MAX_BEAMS       EQUATE(100)
MAX_STRUCTURES  EQUATE(8)
MAX_HIST_BINS   EQUATE(256)
MAX_VOX         EQUATE(4096)    ! Supports up to 64x64x1 grids

! --- Plan state ---
PlActive      LONG(0)
PlGridW       LONG(0)
PlGridH       LONG(0)
PlGridD       LONG(1)
PlNumBeams    LONG(0)
PlNumStructs  LONG(0)

! --- Density volume ---
DensVoxels    REAL,DIM(MAX_VOX)

! --- Total dose volume ---
DoseVoxels    REAL,DIM(MAX_VOX)

! --- Beam metadata (flat arrays) ---
BmInUse       LONG,DIM(MAX_BEAMS)
BmWeight      REAL,DIM(MAX_BEAMS)
BmGantry      REAL,DIM(MAX_BEAMS)
BmCollim      REAL,DIM(MAX_BEAMS)
BmCouch       REAL,DIM(MAX_BEAMS)
BmDoseValid   LONG,DIM(MAX_BEAMS)

! --- Beam dose volumes (flat: (beamIdx-1)*MAX_VOX + voxelIdx) ---
! Note: 100 * 65536 = 6.5M REALs = ~52MB - large but feasible
BeamDoseVox   REAL,DIM(MAX_BEAMS * MAX_VOX)

! --- Structure metadata ---
StInUse       LONG,DIM(MAX_STRUCTURES)
StType        LONG,DIM(MAX_STRUCTURES)
StVisible     LONG,DIM(MAX_STRUCTURES)
StColorR      LONG,DIM(MAX_STRUCTURES)
StColorG      LONG,DIM(MAX_STRUCTURES)
StColorB      LONG,DIM(MAX_STRUCTURES)

! --- Structure region masks (flat: (structIdx-1)*MAX_VOX + voxelIdx) ---
RegionVox     REAL,DIM(MAX_STRUCTURES * MAX_VOX)

! --- Histogram state ---
HistBins      REAL,DIM(MAX_HIST_BINS)
HistCumBins   REAL,DIM(MAX_HIST_BINS)
HistBinCount  LONG(MAX_HIST_BINS)

  MAP
    PlanInit(LONG gridW, LONG gridH, LONG gridD),LONG,C,NAME('PlanInit'),EXPORT
    PlanClose(),LONG,C,NAME('PlanClose'),EXPORT
    PlanGetGridW(),LONG,C,NAME('PlanGetGridW'),EXPORT
    PlanGetGridH(),LONG,C,NAME('PlanGetGridH'),EXPORT
    PlanGetGridD(),LONG,C,NAME('PlanGetGridD'),EXPORT
    PlanSetDensity(LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetDensity'),EXPORT
    PlanGetDensity(LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetDensity'),EXPORT
    PlanAddBeam(REAL weight, REAL gantry, REAL collim, REAL couch),LONG,C,NAME('PlanAddBeam'),EXPORT
    PlanGetBeamCount(),LONG,C,NAME('PlanGetBeamCount'),EXPORT
    PlanGetBeamWeight(LONG beamIdx),REAL,C,NAME('PlanGetBeamWeight'),EXPORT
    PlanSetBeamWeight(LONG beamIdx, REAL weight),LONG,C,NAME('PlanSetBeamWeight'),EXPORT
    PlanSetBeamDose(LONG beamIdx, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetBeamDose'),EXPORT
    PlanGetBeamDose(LONG beamIdx, LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetBeamDose'),EXPORT
    PlanAccumulateDose(),LONG,C,NAME('PlanAccumulateDose'),EXPORT
    PlanGetDose(LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetDose'),EXPORT
    PlanGetMaxDose(),REAL,C,NAME('PlanGetMaxDose'),EXPORT
    PlanNormalizeDose(),LONG,C,NAME('PlanNormalizeDose'),EXPORT
    PlanAddStructure(LONG sType, LONG r, LONG g, LONG b),LONG,C,NAME('PlanAddStructure'),EXPORT
    PlanGetStructureCount(),LONG,C,NAME('PlanGetStructureCount'),EXPORT
    PlanSetRegionVoxel(LONG sIdx, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('PlanSetRegionVoxel'),EXPORT
    PlanGetRegionVoxel(LONG sIdx, LONG x, LONG y, LONG z),REAL,C,NAME('PlanGetRegionVoxel'),EXPORT
    HistCompute(LONG sIdx),LONG,C,NAME('HistCompute'),EXPORT
    HistGetBinCount(),LONG,C,NAME('HistGetBinCount'),EXPORT
    HistGetBinValue(LONG binIdx),REAL,C,NAME('HistGetBinValue'),EXPORT
    HistGetCumBinValue(LONG binIdx),REAL,C,NAME('HistGetCumBinValue'),EXPORT
  END

! --- Helper: linear voxel index (1-based) ---

! ============================================================================
! Plan Implementation
! ============================================================================

PlanInit PROCEDURE(LONG gridW, LONG gridH, LONG gridD)
Total LONG
I     LONG
  CODE
  Total = gridW * gridH * gridD
  IF Total < 1 OR Total > MAX_VOX THEN RETURN -1.
  PlActive = 1
  PlGridW = gridW
  PlGridH = gridH
  PlGridD = gridD
  PlNumBeams = 0
  PlNumStructs = 0
  LOOP I = 1 TO Total
    DensVoxels[I] = 0
    DoseVoxels[I] = 0
  END
  LOOP I = 1 TO MAX_BEAMS
    BmInUse[I] = 0
  END
  LOOP I = 1 TO MAX_STRUCTURES
    StInUse[I] = 0
  END
  RETURN 0

PlanClose PROCEDURE()
  CODE
  PlActive = 0
  RETURN 0

PlanGetGridW PROCEDURE()
  CODE
  RETURN PlGridW

PlanGetGridH PROCEDURE()
  CODE
  RETURN PlGridH

PlanGetGridD PROCEDURE()
  CODE
  RETURN PlGridD

! --- Density ---

PlanSetDensity PROCEDURE(LONG x, LONG y, LONG z, REAL val)
Idx LONG
  CODE
  IF PlActive = 0 THEN RETURN -1.
  IF x < 0 OR x >= PlGridW THEN RETURN -2.
  IF y < 0 OR y >= PlGridH THEN RETURN -2.
  IF z < 0 OR z >= PlGridD THEN RETURN -2.
  Idx = z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  DensVoxels[Idx] = val
  RETURN 0

PlanGetDensity PROCEDURE(LONG x, LONG y, LONG z)
Idx LONG
  CODE
  IF PlActive = 0 THEN RETURN 0.
  IF x < 0 OR x >= PlGridW THEN RETURN 0.
  IF y < 0 OR y >= PlGridH THEN RETURN 0.
  IF z < 0 OR z >= PlGridD THEN RETURN 0.
  Idx = z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  RETURN DensVoxels[Idx]

! --- Beams ---

PlanAddBeam PROCEDURE(REAL weight, REAL gantry, REAL collim, REAL couch)
I     LONG
Total LONG
Base  LONG
  CODE
  IF PlActive = 0 THEN RETURN -1.
  IF PlNumBeams >= MAX_BEAMS THEN RETURN -2.
  PlNumBeams += 1
  I = PlNumBeams
  BmInUse[I] = 1
  BmWeight[I] = weight
  BmGantry[I] = gantry
  BmCollim[I] = collim
  BmCouch[I] = couch
  BmDoseValid[I] = 0
  Total = PlGridW * PlGridH * PlGridD
  Base = (I - 1) * MAX_VOX
  LOOP J# = 1 TO Total
    BeamDoseVox[Base + J#] = 0
  END
  RETURN I

PlanGetBeamCount PROCEDURE()
  CODE
  RETURN PlNumBeams

PlanGetBeamWeight PROCEDURE(LONG beamIdx)
  CODE
  IF beamIdx < 1 OR beamIdx > PlNumBeams THEN RETURN 0.
  RETURN BmWeight[beamIdx]

PlanSetBeamWeight PROCEDURE(LONG beamIdx, REAL weight)
  CODE
  IF beamIdx < 1 OR beamIdx > PlNumBeams THEN RETURN -1.
  BmWeight[beamIdx] = weight
  RETURN 0

PlanSetBeamDose PROCEDURE(LONG beamIdx, LONG x, LONG y, LONG z, REAL val)
Idx LONG
  CODE
  IF beamIdx < 1 OR beamIdx > PlNumBeams THEN RETURN -1.
  IF x < 0 OR x >= PlGridW THEN RETURN -2.
  IF y < 0 OR y >= PlGridH THEN RETURN -2.
  IF z < 0 OR z >= PlGridD THEN RETURN -2.
  Idx = (beamIdx - 1) * MAX_VOX + z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  BeamDoseVox[Idx] = val
  BmDoseValid[beamIdx] = 1
  RETURN 0

PlanGetBeamDose PROCEDURE(LONG beamIdx, LONG x, LONG y, LONG z)
Idx LONG
  CODE
  IF beamIdx < 1 OR beamIdx > PlNumBeams THEN RETURN 0.
  IF x < 0 OR x >= PlGridW THEN RETURN 0.
  IF y < 0 OR y >= PlGridH THEN RETURN 0.
  IF z < 0 OR z >= PlGridD THEN RETURN 0.
  Idx = (beamIdx - 1) * MAX_VOX + z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  RETURN BeamDoseVox[Idx]

! --- Dose accumulation ---

PlanAccumulateDose PROCEDURE()
I     LONG
J     LONG
Total LONG
Base  LONG
  CODE
  IF PlActive = 0 THEN RETURN -1.
  Total = PlGridW * PlGridH * PlGridD
  LOOP J = 1 TO Total
    DoseVoxels[J] = 0
  END
  LOOP I = 1 TO PlNumBeams
    IF BmInUse[I] = 1 AND BmDoseValid[I] = 1
      Base = (I - 1) * MAX_VOX
      LOOP J = 1 TO Total
        DoseVoxels[J] += BmWeight[I] * BeamDoseVox[Base + J]
      END
    END
  END
  RETURN 0

PlanGetDose PROCEDURE(LONG x, LONG y, LONG z)
Idx LONG
  CODE
  IF PlActive = 0 THEN RETURN 0.
  IF x < 0 OR x >= PlGridW THEN RETURN 0.
  IF y < 0 OR y >= PlGridH THEN RETURN 0.
  IF z < 0 OR z >= PlGridD THEN RETURN 0.
  Idx = z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  RETURN DoseVoxels[Idx]

PlanGetMaxDose PROCEDURE()
MaxVal REAL(0)
I      LONG
Total  LONG
  CODE
  IF PlActive = 0 THEN RETURN 0.
  Total = PlGridW * PlGridH * PlGridD
  MaxVal = DoseVoxels[1]
  LOOP I = 2 TO Total
    IF DoseVoxels[I] > MaxVal
      MaxVal = DoseVoxels[I]
    END
  END
  RETURN MaxVal

PlanNormalizeDose PROCEDURE()
MaxVal REAL
I      LONG
Total  LONG
  CODE
  IF PlActive = 0 THEN RETURN -1.
  MaxVal = PlanGetMaxDose()
  IF MaxVal = 0 THEN RETURN -2.
  Total = PlGridW * PlGridH * PlGridD
  LOOP I = 1 TO Total
    DoseVoxels[I] /= MaxVal
  END
  RETURN 0

! --- Structures ---

PlanAddStructure PROCEDURE(LONG sType, LONG r, LONG g, LONG b)
I     LONG
Total LONG
Base  LONG
  CODE
  IF PlActive = 0 THEN RETURN -1.
  IF PlNumStructs >= MAX_STRUCTURES THEN RETURN -2.
  PlNumStructs += 1
  I = PlNumStructs
  StInUse[I] = 1
  StType[I] = sType
  StVisible[I] = 1
  StColorR[I] = r
  StColorG[I] = g
  StColorB[I] = b
  Total = PlGridW * PlGridH * PlGridD
  Base = (I - 1) * MAX_VOX
  LOOP J# = 1 TO Total
    RegionVox[Base + J#] = 0
  END
  RETURN I

PlanGetStructureCount PROCEDURE()
  CODE
  RETURN PlNumStructs

PlanSetRegionVoxel PROCEDURE(LONG sIdx, LONG x, LONG y, LONG z, REAL val)
Idx LONG
  CODE
  IF sIdx < 1 OR sIdx > PlNumStructs THEN RETURN -1.
  IF x < 0 OR x >= PlGridW THEN RETURN -2.
  IF y < 0 OR y >= PlGridH THEN RETURN -2.
  IF z < 0 OR z >= PlGridD THEN RETURN -2.
  Idx = (sIdx - 1) * MAX_VOX + z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  RegionVox[Idx] = val
  RETURN 0

PlanGetRegionVoxel PROCEDURE(LONG sIdx, LONG x, LONG y, LONG z)
Idx LONG
  CODE
  IF sIdx < 1 OR sIdx > PlNumStructs THEN RETURN 0.
  IF x < 0 OR x >= PlGridW THEN RETURN 0.
  IF y < 0 OR y >= PlGridH THEN RETURN 0.
  IF z < 0 OR z >= PlGridD THEN RETURN 0.
  Idx = (sIdx - 1) * MAX_VOX + z * (PlGridW * PlGridH) + y * PlGridW + x + 1
  RETURN RegionVox[Idx]

! --- Histogram (DVH) ---

HistCompute PROCEDURE(LONG sIdx)
I         LONG
Total     LONG
Base      LONG
BinIdx    LONG
MaxDose   REAL
RegCount  REAL(0)
BinWidth  REAL
  CODE
  IF PlActive = 0 THEN RETURN -1.
  IF sIdx < 1 OR sIdx > PlNumStructs THEN RETURN -2.
  Total = PlGridW * PlGridH * PlGridD
  MaxDose = PlanGetMaxDose()
  IF MaxDose = 0 THEN MaxDose = 1.
  BinWidth = MaxDose / MAX_HIST_BINS
  IF BinWidth = 0 THEN BinWidth = 1.
  LOOP I = 1 TO MAX_HIST_BINS
    HistBins[I] = 0
    HistCumBins[I] = 0
  END
  Base = (sIdx - 1) * MAX_VOX
  LOOP I = 1 TO Total
    IF RegionVox[Base + I] > 0
      RegCount += 1
      BinIdx = INT(DoseVoxels[I] / BinWidth) + 1
      IF BinIdx > MAX_HIST_BINS THEN BinIdx = MAX_HIST_BINS.
      IF BinIdx < 1 THEN BinIdx = 1.
      HistBins[BinIdx] += 1
    END
  END
  IF RegCount > 0
    LOOP I = 1 TO MAX_HIST_BINS
      HistBins[I] /= RegCount
    END
  END
  HistCumBins[MAX_HIST_BINS] = HistBins[MAX_HIST_BINS]
  LOOP I = MAX_HIST_BINS - 1 TO 1 BY -1
    HistCumBins[I] = HistCumBins[I + 1] + HistBins[I]
  END
  RETURN 0

HistGetBinCount PROCEDURE()
  CODE
  RETURN HistBinCount

HistGetBinValue PROCEDURE(LONG binIdx)
  CODE
  IF binIdx < 1 OR binIdx > MAX_HIST_BINS THEN RETURN 0.
  RETURN HistBins[binIdx]

HistGetCumBinValue PROCEDURE(LONG binIdx)
  CODE
  IF binIdx < 1 OR binIdx > MAX_HIST_BINS THEN RETURN 0.
  RETURN HistCumBins[binIdx]
