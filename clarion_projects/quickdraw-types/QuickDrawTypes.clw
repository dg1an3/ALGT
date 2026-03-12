  MEMBER()

QDPoint GROUP,PRE(QDP)
v         LONG
h         LONG
          END

QDRect  GROUP,PRE(QDR)
top       LONG
left      LONG
bottom    LONG
right     LONG
          END

Pt1     GROUP,PRE(P1)
v         LONG
h         LONG
          END

Pt2     GROUP,PRE(P2)
v         LONG
h         LONG
          END

Rc1     GROUP,PRE(R1)
top       LONG
left      LONG
bottom    LONG
right     LONG
          END

Rc2     GROUP,PRE(R2)
top       LONG
left      LONG
bottom    LONG
right     LONG
          END

Rc3     GROUP,PRE(R3)
top       LONG
left      LONG
bottom    LONG
right     LONG
          END

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    QDSetPt(LONG ptPtr, LONG h, LONG v),LONG,C,NAME('QDSetPt'),EXPORT
    QDEqualPt(LONG pt1Ptr, LONG pt2Ptr),LONG,C,NAME('QDEqualPt'),EXPORT
    QDAddPt(LONG srcPtr, LONG dstPtr),LONG,C,NAME('QDAddPt'),EXPORT
    QDSubPt(LONG srcPtr, LONG dstPtr),LONG,C,NAME('QDSubPt'),EXPORT
    QDSetRect(LONG rPtr, LONG left, LONG top, LONG right, LONG bottom),LONG,C,NAME('QDSetRect'),EXPORT
    QDEqualRect(LONG r1Ptr, LONG r2Ptr),LONG,C,NAME('QDEqualRect'),EXPORT
    QDEmptyRect(LONG rPtr),LONG,C,NAME('QDEmptyRect'),EXPORT
    QDOffsetRect(LONG rPtr, LONG dh, LONG dv),LONG,C,NAME('QDOffsetRect'),EXPORT
    QDInsetRect(LONG rPtr, LONG dh, LONG dv),LONG,C,NAME('QDInsetRect'),EXPORT
    QDSectRect(LONG src1Ptr, LONG src2Ptr, LONG dstPtr),LONG,C,NAME('QDSectRect'),EXPORT
    QDUnionRect(LONG src1Ptr, LONG src2Ptr, LONG dstPtr),LONG,C,NAME('QDUnionRect'),EXPORT
    QDPtInRect(LONG ptPtr, LONG rPtr),LONG,C,NAME('QDPtInRect'),EXPORT
  END

QDSetPt PROCEDURE(LONG ptPtr, LONG h, LONG v)
  CODE
  QDP:h = h
  QDP:v = v
  MemCopy(ptPtr, ADDRESS(QDPoint), SIZE(QDPoint))
  RETURN 0

QDEqualPt PROCEDURE(LONG pt1Ptr, LONG pt2Ptr)
  CODE
  MemCopy(ADDRESS(Pt1), pt1Ptr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), pt2Ptr, SIZE(Pt2))
  IF P1:v = P2:v AND P1:h = P2:h
    RETURN 1
  END
  RETURN 0

QDAddPt PROCEDURE(LONG srcPtr, LONG dstPtr)
  CODE
  MemCopy(ADDRESS(Pt1), srcPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), dstPtr, SIZE(Pt2))
  P2:h += P1:h
  P2:v += P1:v
  MemCopy(dstPtr, ADDRESS(Pt2), SIZE(Pt2))
  RETURN 0

QDSubPt PROCEDURE(LONG srcPtr, LONG dstPtr)
  CODE
  MemCopy(ADDRESS(Pt1), srcPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), dstPtr, SIZE(Pt2))
  P2:h -= P1:h
  P2:v -= P1:v
  MemCopy(dstPtr, ADDRESS(Pt2), SIZE(Pt2))
  RETURN 0

QDSetRect PROCEDURE(LONG rPtr, LONG left, LONG top, LONG right, LONG bottom)
  CODE
  QDR:top = top
  QDR:left = left
  QDR:bottom = bottom
  QDR:right = right
  MemCopy(rPtr, ADDRESS(QDRect), SIZE(QDRect))
  RETURN 0

QDEqualRect PROCEDURE(LONG r1Ptr, LONG r2Ptr)
  CODE
  MemCopy(ADDRESS(Rc1), r1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), r2Ptr, SIZE(Rc2))
  IF R1:top = R2:top AND R1:left = R2:left AND R1:bottom = R2:bottom AND R1:right = R2:right
    RETURN 1
  END
  RETURN 0

QDEmptyRect PROCEDURE(LONG rPtr)
  CODE
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  IF R1:bottom <= R1:top OR R1:right <= R1:left
    RETURN 1
  END
  RETURN 0

QDOffsetRect PROCEDURE(LONG rPtr, LONG dh, LONG dv)
  CODE
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  R1:left += dh
  R1:right += dh
  R1:top += dv
  R1:bottom += dv
  MemCopy(rPtr, ADDRESS(Rc1), SIZE(Rc1))
  RETURN 0

QDInsetRect PROCEDURE(LONG rPtr, LONG dh, LONG dv)
  CODE
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  R1:left += dh
  R1:right -= dh
  R1:top += dv
  R1:bottom -= dv
  MemCopy(rPtr, ADDRESS(Rc1), SIZE(Rc1))
  RETURN 0

QDSectRect PROCEDURE(LONG src1Ptr, LONG src2Ptr, LONG dstPtr)
  CODE
  MemCopy(ADDRESS(Rc1), src1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), src2Ptr, SIZE(Rc2))
  ! Intersection: max of tops/lefts, min of bottoms/rights
  IF R1:top > R2:top
    R3:top = R1:top
  ELSE
    R3:top = R2:top
  END
  IF R1:left > R2:left
    R3:left = R1:left
  ELSE
    R3:left = R2:left
  END
  IF R1:bottom < R2:bottom
    R3:bottom = R1:bottom
  ELSE
    R3:bottom = R2:bottom
  END
  IF R1:right < R2:right
    R3:right = R1:right
  ELSE
    R3:right = R2:right
  END
  MemCopy(dstPtr, ADDRESS(Rc3), SIZE(Rc3))
  ! Return 1 if non-empty
  IF R3:bottom > R3:top AND R3:right > R3:left
    RETURN 1
  END
  RETURN 0

QDUnionRect PROCEDURE(LONG src1Ptr, LONG src2Ptr, LONG dstPtr)
  CODE
  MemCopy(ADDRESS(Rc1), src1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), src2Ptr, SIZE(Rc2))
  ! Union: min of tops/lefts, max of bottoms/rights
  IF R1:top < R2:top
    R3:top = R1:top
  ELSE
    R3:top = R2:top
  END
  IF R1:left < R2:left
    R3:left = R1:left
  ELSE
    R3:left = R2:left
  END
  IF R1:bottom > R2:bottom
    R3:bottom = R1:bottom
  ELSE
    R3:bottom = R2:bottom
  END
  IF R1:right > R2:right
    R3:right = R1:right
  ELSE
    R3:right = R2:right
  END
  MemCopy(dstPtr, ADDRESS(Rc3), SIZE(Rc3))
  RETURN 0

QDPtInRect PROCEDURE(LONG ptPtr, LONG rPtr)
  CODE
  MemCopy(ADDRESS(Pt1), ptPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  IF P1:v >= R1:top AND P1:v < R1:bottom AND P1:h >= R1:left AND P1:h < R1:right
    RETURN 1
  END
  RETURN 0
