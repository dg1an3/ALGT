  MEMBER()

! ============================================================================
! MtlLib - Matrix/Template Library for Clarion
! Port of dH/MTL (VectorN, VectorD, MatrixD)
!
! Provides dynamic vectors, fixed-size 2D/3D vectors, and 4x4 matrices.
! All exported functions use C calling convention for Python ctypes interop.
!
! Storage uses flat arrays with manual index computation to avoid
! Clarion's GROUP,DIM multi-subscript limitations.
! ============================================================================

! --- Configuration ---
MAX_VECTORS   EQUATE(16)
MAX_ELEMENTS  EQUATE(4096)
MAX_MATRICES  EQUATE(16)

! --- Vector storage (flat) ---
! VecElements: MAX_VECTORS * MAX_ELEMENTS = 65536 REALs
! Index = (handle-1) * MAX_ELEMENTS + idx
VecInUse    LONG,DIM(MAX_VECTORS)
VecNDim     LONG,DIM(MAX_VECTORS)
VecElements REAL,DIM(MAX_VECTORS * MAX_ELEMENTS)

! --- Matrix storage (flat) ---
! MatElements: MAX_MATRICES * 16 = 256 REALs
! Index = (handle-1) * 16 + col*4 + row + 1
MatInUse    LONG,DIM(MAX_MATRICES)
MatCols     REAL,DIM(MAX_MATRICES * 16)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    ! --- VectorN operations ---
    VNCreate(LONG ndim),LONG,C,NAME('VNCreate'),EXPORT
    VNFree(LONG handle),LONG,C,NAME('VNFree'),EXPORT
    VNGetDim(LONG handle),LONG,C,NAME('VNGetDim'),EXPORT
    VNSetElement(LONG handle, LONG idx, REAL val),LONG,C,NAME('VNSetElement'),EXPORT
    VNGetElement(LONG handle, LONG idx),REAL,C,NAME('VNGetElement'),EXPORT
    VNSetZero(LONG handle),LONG,C,NAME('VNSetZero'),EXPORT
    VNGetLength(LONG handle),REAL,C,NAME('VNGetLength'),EXPORT
    VNDotProduct(LONG h1, LONG h2),REAL,C,NAME('VNDotProduct'),EXPORT
    VNScale(LONG handle, REAL scalar),LONG,C,NAME('VNScale'),EXPORT
    VNAddInPlace(LONG hDest, LONG hSrc),LONG,C,NAME('VNAddInPlace'),EXPORT
    VNCopy(LONG hSrc),LONG,C,NAME('VNCopy'),EXPORT

    ! --- 4x4 Matrix operations ---
    M4Create(),LONG,C,NAME('M4Create'),EXPORT
    M4Free(LONG handle),LONG,C,NAME('M4Free'),EXPORT
    M4SetIdentity(LONG handle),LONG,C,NAME('M4SetIdentity'),EXPORT
    M4SetElement(LONG handle, LONG row, LONG col, REAL val),LONG,C,NAME('M4SetElement'),EXPORT
    M4GetElement(LONG handle, LONG row, LONG col),REAL,C,NAME('M4GetElement'),EXPORT
    M4Multiply(LONG hA, LONG hB),LONG,C,NAME('M4Multiply'),EXPORT
    M4Transpose(LONG handle),LONG,C,NAME('M4Transpose'),EXPORT

    ! --- Utility ---
    MtlSqrt(REAL val),REAL,C,NAME('MtlSqrt'),EXPORT
    MtlExp(REAL val),REAL,C,NAME('MtlExp'),EXPORT
    MtlPi(),REAL,C,NAME('MtlPi'),EXPORT
  END

! ============================================================================
! VectorN Implementation
! VecElements index: (handle-1) * MAX_ELEMENTS + idx  (1-based idx)
! ============================================================================

VNCreate PROCEDURE(LONG ndim)
I    LONG
J    LONG
Base LONG
  CODE
  IF ndim < 1 OR ndim > MAX_ELEMENTS THEN RETURN -1.
  LOOP I = 1 TO MAX_VECTORS
    IF VecInUse[I] = 0
      VecInUse[I] = 1
      VecNDim[I] = ndim
      Base = (I - 1) * MAX_ELEMENTS
      LOOP J = 1 TO ndim
        VecElements[Base + J] = 0
      END
      RETURN I
    END
  END
  RETURN -1

VNFree PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN -1.
  VecInUse[handle] = 0
  VecNDim[handle] = 0
  RETURN 0

VNGetDim PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN 0.
  IF VecInUse[handle] = 0 THEN RETURN 0.
  RETURN VecNDim[handle]

VNSetElement PROCEDURE(LONG handle, LONG idx, REAL val)
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN -1.
  IF VecInUse[handle] = 0 THEN RETURN -1.
  IF idx < 1 OR idx > VecNDim[handle] THEN RETURN -2.
  VecElements[(handle - 1) * MAX_ELEMENTS + idx] = val
  RETURN 0

VNGetElement PROCEDURE(LONG handle, LONG idx)
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN 0.
  IF VecInUse[handle] = 0 THEN RETURN 0.
  IF idx < 1 OR idx > VecNDim[handle] THEN RETURN 0.
  RETURN VecElements[(handle - 1) * MAX_ELEMENTS + idx]

VNSetZero PROCEDURE(LONG handle)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN -1.
  IF VecInUse[handle] = 0 THEN RETURN -1.
  Base = (handle - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[handle]
    VecElements[Base + I] = 0
  END
  RETURN 0

VNGetLength PROCEDURE(LONG handle)
Sum  REAL(0)
I    LONG
Base LONG
V    REAL
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN 0.
  IF VecInUse[handle] = 0 THEN RETURN 0.
  Base = (handle - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[handle]
    V = VecElements[Base + I]
    Sum += V * V
  END
  RETURN SQRT(Sum)

VNDotProduct PROCEDURE(LONG h1, LONG h2)
Sum   REAL(0)
I     LONG
Base1 LONG
Base2 LONG
  CODE
  IF h1 < 1 OR h1 > MAX_VECTORS THEN RETURN 0.
  IF h2 < 1 OR h2 > MAX_VECTORS THEN RETURN 0.
  IF VecInUse[h1] = 0 OR VecInUse[h2] = 0 THEN RETURN 0.
  IF VecNDim[h1] <> VecNDim[h2] THEN RETURN 0.
  Base1 = (h1 - 1) * MAX_ELEMENTS
  Base2 = (h2 - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[h1]
    Sum += VecElements[Base1 + I] * VecElements[Base2 + I]
  END
  RETURN Sum

VNScale PROCEDURE(LONG handle, REAL scalar)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_VECTORS THEN RETURN -1.
  IF VecInUse[handle] = 0 THEN RETURN -1.
  Base = (handle - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[handle]
    VecElements[Base + I] *= scalar
  END
  RETURN 0

VNAddInPlace PROCEDURE(LONG hDest, LONG hSrc)
I     LONG
BaseD LONG
BaseS LONG
  CODE
  IF hDest < 1 OR hDest > MAX_VECTORS THEN RETURN -1.
  IF hSrc < 1 OR hSrc > MAX_VECTORS THEN RETURN -1.
  IF VecInUse[hDest] = 0 OR VecInUse[hSrc] = 0 THEN RETURN -1.
  IF VecNDim[hDest] <> VecNDim[hSrc] THEN RETURN -2.
  BaseD = (hDest - 1) * MAX_ELEMENTS
  BaseS = (hSrc - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[hDest]
    VecElements[BaseD + I] += VecElements[BaseS + I]
  END
  RETURN 0

VNCopy PROCEDURE(LONG hSrc)
hNew  LONG
I     LONG
BaseS LONG
BaseN LONG
  CODE
  IF hSrc < 1 OR hSrc > MAX_VECTORS THEN RETURN -1.
  IF VecInUse[hSrc] = 0 THEN RETURN -1.
  hNew = VNCreate(VecNDim[hSrc])
  IF hNew < 1 THEN RETURN -1.
  BaseS = (hSrc - 1) * MAX_ELEMENTS
  BaseN = (hNew - 1) * MAX_ELEMENTS
  LOOP I = 1 TO VecNDim[hSrc]
    VecElements[BaseN + I] = VecElements[BaseS + I]
  END
  RETURN hNew

! ============================================================================
! 4x4 Matrix Implementation (column-major)
! MatCols index: (handle-1)*16 + col*4 + row + 1  (0-based row/col)
! ============================================================================

M4Create PROCEDURE()
I LONG
  CODE
  LOOP I = 1 TO MAX_MATRICES
    IF MatInUse[I] = 0
      MatInUse[I] = 1
      M4SetIdentity(I)
      RETURN I
    END
  END
  RETURN -1

M4Free PROCEDURE(LONG handle)
  CODE
  IF handle < 1 OR handle > MAX_MATRICES THEN RETURN -1.
  MatInUse[handle] = 0
  RETURN 0

M4SetIdentity PROCEDURE(LONG handle)
I    LONG
Base LONG
  CODE
  IF handle < 1 OR handle > MAX_MATRICES THEN RETURN -1.
  Base = (handle - 1) * 16
  LOOP I = 1 TO 16
    MatCols[Base + I] = 0
  END
  MatCols[Base + 1] = 1    ! [0,0]
  MatCols[Base + 6] = 1    ! [1,1]
  MatCols[Base + 11] = 1   ! [2,2]
  MatCols[Base + 16] = 1   ! [3,3]
  RETURN 0

M4SetElement PROCEDURE(LONG handle, LONG row, LONG col, REAL val)
Idx LONG
  CODE
  IF handle < 1 OR handle > MAX_MATRICES THEN RETURN -1.
  IF MatInUse[handle] = 0 THEN RETURN -1.
  IF row < 0 OR row > 3 OR col < 0 OR col > 3 THEN RETURN -2.
  Idx = (handle - 1) * 16 + col * 4 + row + 1
  MatCols[Idx] = val
  RETURN 0

M4GetElement PROCEDURE(LONG handle, LONG row, LONG col)
Idx LONG
  CODE
  IF handle < 1 OR handle > MAX_MATRICES THEN RETURN 0.
  IF MatInUse[handle] = 0 THEN RETURN 0.
  IF row < 0 OR row > 3 OR col < 0 OR col > 3 THEN RETURN 0.
  Idx = (handle - 1) * 16 + col * 4 + row + 1
  RETURN MatCols[Idx]

M4Multiply PROCEDURE(LONG hA, LONG hB)
hResult LONG
R       LONG
C       LONG
K       LONG
Sum     REAL
BaseA   LONG
BaseB   LONG
BaseR   LONG
  CODE
  IF hA < 1 OR hA > MAX_MATRICES THEN RETURN -1.
  IF hB < 1 OR hB > MAX_MATRICES THEN RETURN -1.
  IF MatInUse[hA] = 0 OR MatInUse[hB] = 0 THEN RETURN -1.
  hResult = M4Create()
  IF hResult < 1 THEN RETURN -1.
  BaseA = (hA - 1) * 16
  BaseB = (hB - 1) * 16
  BaseR = (hResult - 1) * 16
  LOOP C = 0 TO 3
    LOOP R = 0 TO 3
      Sum = 0
      LOOP K = 0 TO 3
        Sum += MatCols[BaseA + K * 4 + R + 1] * MatCols[BaseB + C * 4 + K + 1]
      END
      MatCols[BaseR + C * 4 + R + 1] = Sum
    END
  END
  RETURN hResult

M4Transpose PROCEDURE(LONG handle)
Tmp  REAL
R    LONG
C    LONG
Base LONG
IdxA LONG
IdxB LONG
  CODE
  IF handle < 1 OR handle > MAX_MATRICES THEN RETURN -1.
  IF MatInUse[handle] = 0 THEN RETURN -1.
  Base = (handle - 1) * 16
  LOOP R = 0 TO 3
    LOOP C = R + 1 TO 3
      IdxA = Base + C * 4 + R + 1
      IdxB = Base + R * 4 + C + 1
      Tmp = MatCols[IdxA]
      MatCols[IdxA] = MatCols[IdxB]
      MatCols[IdxB] = Tmp
    END
  END
  RETURN 0

! ============================================================================
! Utility functions
! ============================================================================

MtlSqrt PROCEDURE(REAL val)
  CODE
  IF val < 0 THEN RETURN 0.
  RETURN SQRT(val)

MtlExp PROCEDURE(REAL val)
Result REAL
Term   REAL
I      LONG
  CODE
  Result = 1
  Term = 1
  LOOP I = 1 TO 30
    Term *= val / I
    Result += Term
    IF ABS(Term) < 1.0e-15 THEN BREAK.
  END
  RETURN Result

MtlPi PROCEDURE()
  CODE
  RETURN 3.14159265358979323846
