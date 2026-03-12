  MEMBER()

! ============================================================================
! VolumeLib - 3D Voxel Volume Library for Clarion
! Port of dH/GEOM_MODEL/Volumep.h (CVolume template)
!
! Provides 3D voxel grids with linear storage and computed indexing.
! Up to 8 volumes, max 65536 voxels each (e.g. 256x256x1).
! ============================================================================

MAX_VOLUMES   EQUATE(8)
MAX_VOXELS    EQUATE(65536)

! --- Volume metadata (flat arrays) ---
VolInUse      LONG,DIM(MAX_VOLUMES)
VolWidth      LONG,DIM(MAX_VOLUMES)
VolHeight     LONG,DIM(MAX_VOLUMES)
VolDepth      LONG,DIM(MAX_VOLUMES)
VolCount      LONG,DIM(MAX_VOLUMES)

! --- Voxel data (flat: index = (handle-1)*MAX_VOXELS + linearIdx) ---
VolVoxels     REAL,DIM(MAX_VOLUMES * MAX_VOXELS)

  MAP
    VolCreate(LONG w, LONG h, LONG d),LONG,C,NAME('VolCreate'),EXPORT
    VolFree(LONG handle),LONG,C,NAME('VolFree'),EXPORT
    VolGetWidth(LONG handle),LONG,C,NAME('VolGetWidth'),EXPORT
    VolGetHeight(LONG handle),LONG,C,NAME('VolGetHeight'),EXPORT
    VolGetDepth(LONG handle),LONG,C,NAME('VolGetDepth'),EXPORT
    VolSetVoxel(LONG handle, LONG x, LONG y, LONG z, REAL val),LONG,C,NAME('VolSetVoxel'),EXPORT
    VolGetVoxel(LONG handle, LONG x, LONG y, LONG z),REAL,C,NAME('VolGetVoxel'),EXPORT
    VolClear(LONG handle),LONG,C,NAME('VolClear'),EXPORT
    VolAccumulate(LONG hDest, LONG hSrc, REAL weight),LONG,C,NAME('VolAccumulate'),EXPORT
    VolGetMax(LONG handle),REAL,C,NAME('VolGetMax'),EXPORT
    VolGetMin(LONG handle),REAL,C,NAME('VolGetMin'),EXPORT
    VolGetSum(LONG handle),REAL,C,NAME('VolGetSum'),EXPORT
    VolScale(LONG handle, REAL scalar),LONG,C,NAME('VolScale'),EXPORT
    VolNormalize(LONG handle),LONG,C,NAME('VolNormalize'),EXPORT
  END

! ============================================================================
! Implementation
! ============================================================================

VolCreate PROCEDURE(LONG w, LONG h, LONG d)
I     LONG
Total LONG
Base  LONG
  CODE
  Total = w * h * d
  IF Total < 1 OR Total > MAX_VOXELS THEN RETURN -1.
  LOOP I = 1 TO MAX_VOLUMES
    IF VolInUse[I] = 0
      VolInUse[I] = 1
      VolWidth[I] = w
      VolHeight[I] = h
      VolDepth[I] = d
      VolCount[I] = Total
      Base = (I - 1) * MAX_VOXELS
      LOOP J# = 1 TO Total
        VolVoxels[Base + J#] = 0
      END
      RETURN I
    END
  END
  RETURN -1

VolFree PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN -1.
  VolInUse[handle] = 0
  RETURN 0

VolGetWidth PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  RETURN VolWidth[handle]

VolGetHeight PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  RETURN VolHeight[handle]

VolGetDepth PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  RETURN VolDepth[handle]

VolSetVoxel PROCEDURE(LONG handle, LONG x, LONG y, LONG z, REAL val)
Idx LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN -1.
  IF VolInUse[handle] = 0 THEN RETURN -1.
  IF x < 0 OR x >= VolWidth[handle] THEN RETURN -2.
  IF y < 0 OR y >= VolHeight[handle] THEN RETURN -2.
  IF z < 0 OR z >= VolDepth[handle] THEN RETURN -2.
  Idx = (handle - 1) * MAX_VOXELS + z * (VolWidth[handle] * VolHeight[handle]) + y * VolWidth[handle] + x + 1
  VolVoxels[Idx] = val
  RETURN 0

VolGetVoxel PROCEDURE(LONG handle, LONG x, LONG y, LONG z)
Idx LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  IF VolInUse[handle] = 0 THEN RETURN 0.
  IF x < 0 OR x >= VolWidth[handle] THEN RETURN 0.
  IF y < 0 OR y >= VolHeight[handle] THEN RETURN 0.
  IF z < 0 OR z >= VolDepth[handle] THEN RETURN 0.
  Idx = (handle - 1) * MAX_VOXELS + z * (VolWidth[handle] * VolHeight[handle]) + y * VolWidth[handle] + x + 1
  RETURN VolVoxels[Idx]

VolClear PROCEDURE(LONG handle)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN -1.
  IF VolInUse[handle] = 0 THEN RETURN -1.
  Base = (handle - 1) * MAX_VOXELS
  LOOP I = 1 TO VolCount[handle]
    VolVoxels[Base + I] = 0
  END
  RETURN 0

VolAccumulate PROCEDURE(LONG hDest, LONG hSrc, REAL weight)
I     LONG
BaseD LONG
BaseS LONG
  CODE
  IF hDest < 1 OR hDest > MAX_VOLUMES THEN RETURN -1.
  IF hSrc < 1 OR hSrc > MAX_VOLUMES THEN RETURN -1.
  IF VolInUse[hDest] = 0 OR VolInUse[hSrc] = 0 THEN RETURN -1.
  IF VolCount[hDest] <> VolCount[hSrc] THEN RETURN -2.
  BaseD = (hDest - 1) * MAX_VOXELS
  BaseS = (hSrc - 1) * MAX_VOXELS
  LOOP I = 1 TO VolCount[hDest]
    VolVoxels[BaseD + I] += weight * VolVoxels[BaseS + I]
  END
  RETURN 0

VolGetMax PROCEDURE(LONG handle)
MaxVal REAL
I      LONG
Base   LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  IF VolInUse[handle] = 0 THEN RETURN 0.
  Base = (handle - 1) * MAX_VOXELS
  MaxVal = VolVoxels[Base + 1]
  LOOP I = 2 TO VolCount[handle]
    IF VolVoxels[Base + I] > MaxVal
      MaxVal = VolVoxels[Base + I]
    END
  END
  RETURN MaxVal

VolGetMin PROCEDURE(LONG handle)
MinVal REAL
I      LONG
Base   LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  IF VolInUse[handle] = 0 THEN RETURN 0.
  Base = (handle - 1) * MAX_VOXELS
  MinVal = VolVoxels[Base + 1]
  LOOP I = 2 TO VolCount[handle]
    IF VolVoxels[Base + I] < MinVal
      MinVal = VolVoxels[Base + I]
    END
  END
  RETURN MinVal

VolGetSum PROCEDURE(LONG handle)
Sum  REAL(0)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN 0.
  IF VolInUse[handle] = 0 THEN RETURN 0.
  Base = (handle - 1) * MAX_VOXELS
  LOOP I = 1 TO VolCount[handle]
    Sum += VolVoxels[Base + I]
  END
  RETURN Sum

VolScale PROCEDURE(LONG handle, REAL scalar)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN -1.
  IF VolInUse[handle] = 0 THEN RETURN -1.
  Base = (handle - 1) * MAX_VOXELS
  LOOP I = 1 TO VolCount[handle]
    VolVoxels[Base + I] *= scalar
  END
  RETURN 0

VolNormalize PROCEDURE(LONG handle)
MaxVal REAL
  CODE
  IF handle < 1 OR handle > MAX_VOLUMES THEN RETURN -1.
  IF VolInUse[handle] = 0 THEN RETURN -1.
  MaxVal = VolGetMax(handle)
  IF MaxVal = 0 THEN RETURN -2.
  RETURN VolScale(handle, 1.0 / MaxVal)
