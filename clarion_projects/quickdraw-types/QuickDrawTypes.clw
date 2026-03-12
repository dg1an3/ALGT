  MEMBER()
! QuickDrawTypes.clw — Clarion implementation of Apple QuickDraw primitives
! Based on QuickDraw.p by Bill Atkinson, Apple Computer 1983
!
! This file deliberately uses variant casing to demonstrate that Clarion
! is case-insensitive. Keywords, types, and variable names appear in
! mixed case throughout — UPPER, lower, and PascalCase are all equivalent.

! Original Pascal (QuickDraw.p, Apple Computer 1983):
!   Point = RECORD CASE INTEGER OF
!     0: (v: INTEGER; h: INTEGER);
!     1: (vh: ARRAY[VHSelect] OF INTEGER);
!   END;
QDPoint Group,PRE(QDP)
v         Long
h         Long
          END

! Original Pascal: Rect = RECORD CASE INTEGER OF
!   0: (top: INTEGER; left: INTEGER; bottom: INTEGER; right: INTEGER);
!   1: (topLeft: Point; botRight: Point);
! END;
QDRect  GROUP,PRE(QDR)
top       LONG
left      Long
bottom    LONG
right     Long
          End

Pt1     group,PRE(P1)
v         Long
h         Long
          end

Pt2     Group,PRE(P2)
v         long
h         long
          End

Rc1     GROUP,PRE(R1)
top       long
left      long
bottom    long
right     long
          END

Rc2     group,PRE(R2)
top       Long
left      Long
bottom    Long
right     Long
          end

Rc3     Group,PRE(R3)
top       LONG
left      LONG
bottom    LONG
right     LONG
          End

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    ! Original Pascal: PROCEDURE SetPt(VAR pt: Point; h, v: INTEGER);
    QDSetPt(LONG ptPtr, LONG h, LONG v),LONG,C,NAME('QDSetPt'),EXPORT
    ! Original Pascal: FUNCTION EqualPt(pt1, pt2: Point): BOOLEAN;
    QDEqualPt(LONG pt1Ptr, LONG pt2Ptr),LONG,C,NAME('QDEqualPt'),EXPORT
    ! Original Pascal: PROCEDURE AddPt(src: Point; VAR dst: Point);
    QDAddPt(LONG srcPtr, LONG dstPtr),LONG,C,NAME('QDAddPt'),EXPORT
    ! Original Pascal: PROCEDURE SubPt(src: Point; VAR dst: Point);
    QDSubPt(LONG srcPtr, LONG dstPtr),LONG,C,NAME('QDSubPt'),EXPORT
    ! Original Pascal: PROCEDURE SetRect(VAR r: Rect; left, top, right, bottom: INTEGER);
    QDSetRect(LONG rPtr, LONG left, LONG top, LONG right, LONG bottom),LONG,C,NAME('QDSetRect'),EXPORT
    ! Original Pascal: FUNCTION EqualRect(rect1, rect2: Rect): BOOLEAN;
    QDEqualRect(LONG r1Ptr, LONG r2Ptr),LONG,C,NAME('QDEqualRect'),EXPORT
    ! Original Pascal: FUNCTION EmptyRect(r: Rect): BOOLEAN;
    QDEmptyRect(LONG rPtr),LONG,C,NAME('QDEmptyRect'),EXPORT
    ! Original Pascal: PROCEDURE OffsetRect(VAR r: Rect; dh, dv: INTEGER);
    QDOffsetRect(LONG rPtr, LONG dh, LONG dv),LONG,C,NAME('QDOffsetRect'),EXPORT
    ! Original Pascal: PROCEDURE InsetRect(VAR r: Rect; dh, dv: INTEGER);
    QDInsetRect(LONG rPtr, LONG dh, LONG dv),LONG,C,NAME('QDInsetRect'),EXPORT
    ! Original Pascal: FUNCTION SectRect(src1, src2: Rect; VAR dstRect: Rect): BOOLEAN;
    QDSectRect(LONG src1Ptr, LONG src2Ptr, LONG dstPtr),LONG,C,NAME('QDSectRect'),EXPORT
    ! Original Pascal: PROCEDURE UnionRect(src1, src2: Rect; VAR dstRect: Rect);
    QDUnionRect(LONG src1Ptr, LONG src2Ptr, LONG dstPtr),LONG,C,NAME('QDUnionRect'),EXPORT
    ! Original Pascal: FUNCTION PtInRect(pt: Point; r: Rect): BOOLEAN;
    QDPtInRect(LONG ptPtr, LONG rPtr),LONG,C,NAME('QDPtInRect'),EXPORT
  END

! Original Pascal (QuickDraw.p, Apple Computer 1983):
!   PROCEDURE SetPt(VAR pt: Point; h, v: INTEGER);
QDSetPt Procedure(Long ptPtr, Long h, Long v)
  Code
  QDP:h = h
  QDP:v = v
  MemCopy(ptPtr, ADDRESS(QDPoint), SIZE(QDPoint))
  Return 0

! Original Pascal: FUNCTION EqualPt(pt1, pt2: Point): BOOLEAN;
QDEqualPt PROCEDURE(LONG pt1Ptr, LONG pt2Ptr)
  CODE
  MemCopy(ADDRESS(Pt1), pt1Ptr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), pt2Ptr, SIZE(Pt2))
  If P1:v = P2:v and P1:h = P2:h
    RETURN 1
  End
  RETURN 0

! Original Pascal: PROCEDURE AddPt(src: Point; VAR dst: Point);
QDAddPt procedure(long srcPtr, long dstPtr)
  code
  MemCopy(ADDRESS(Pt1), srcPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), dstPtr, SIZE(Pt2))
  P2:h += P1:h
  P2:v += P1:v
  MemCopy(dstPtr, ADDRESS(Pt2), SIZE(Pt2))
  return 0

! Original Pascal: PROCEDURE SubPt(src: Point; VAR dst: Point);
QDSubPt Procedure(Long srcPtr, Long dstPtr)
  Code
  MemCopy(ADDRESS(Pt1), srcPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Pt2), dstPtr, SIZE(Pt2))
  P2:h -= P1:h
  P2:v -= P1:v
  MemCopy(dstPtr, ADDRESS(Pt2), SIZE(Pt2))
  Return 0

! Original Pascal: PROCEDURE SetRect(VAR r: Rect; left, top, right, bottom: INTEGER);
QDSetRect PROCEDURE(LONG rPtr, Long left, Long top, Long right, Long bottom)
  CODE
  QDR:top = top
  QDR:left = left
  QDR:bottom = bottom
  QDR:right = right
  MemCopy(rPtr, ADDRESS(QDRect), SIZE(QDRect))
  RETURN 0

! Original Pascal: FUNCTION EqualRect(rect1, rect2: Rect): BOOLEAN;
QDEqualRect procedure(long r1Ptr, long r2Ptr)
  code
  MemCopy(ADDRESS(Rc1), r1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), r2Ptr, SIZE(Rc2))
  if R1:top = R2:top AND R1:left = R2:left AND R1:bottom = R2:bottom AND R1:right = R2:right
    return 1
  end
  return 0

! Original Pascal: FUNCTION EmptyRect(r: Rect): BOOLEAN;
QDEmptyRect Procedure(Long rPtr)
  Code
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  If R1:bottom <= R1:top or R1:right <= R1:left
    Return 1
  End
  Return 0

! Original Pascal: PROCEDURE OffsetRect(VAR r: Rect; dh, dv: INTEGER);
QDOffsetRect PROCEDURE(LONG rPtr, LONG dh, LONG dv)
  CODE
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  R1:left += dh
  R1:right += dh
  R1:top += dv
  R1:bottom += dv
  MemCopy(rPtr, ADDRESS(Rc1), SIZE(Rc1))
  RETURN 0

! Original Pascal: PROCEDURE InsetRect(VAR r: Rect; dh, dv: INTEGER);
QDInsetRect procedure(long rPtr, long dh, long dv)
  code
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  R1:left += dh
  R1:right -= dh
  R1:top += dv
  R1:bottom -= dv
  MemCopy(rPtr, ADDRESS(Rc1), SIZE(Rc1))
  return 0

! Original Pascal: FUNCTION SectRect(src1, src2: Rect; VAR dstRect: Rect): BOOLEAN;
QDSectRect Procedure(Long src1Ptr, Long src2Ptr, Long dstPtr)
  Code
  MemCopy(ADDRESS(Rc1), src1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), src2Ptr, SIZE(Rc2))
  ! Intersection: max of tops/lefts, min of bottoms/rights
  If R1:top > R2:top Then
    R3:top = R1:top
  Else
    R3:top = R2:top
  End
  If R1:left > R2:left Then
    R3:left = R1:left
  Else
    R3:left = R2:left
  End
  If R1:bottom < R2:bottom Then
    R3:bottom = R1:bottom
  Else
    R3:bottom = R2:bottom
  End
  If R1:right < R2:right Then
    R3:right = R1:right
  Else
    R3:right = R2:right
  End
  MemCopy(dstPtr, ADDRESS(Rc3), SIZE(Rc3))
  ! Return 1 if non-empty
  if R3:bottom > R3:top AND R3:right > R3:left
    RETURN 1
  end
  Return 0

! Original Pascal: PROCEDURE UnionRect(src1, src2: Rect; VAR dstRect: Rect);
QDUnionRect PROCEDURE(LONG src1Ptr, LONG src2Ptr, LONG dstPtr)
  CODE
  MemCopy(ADDRESS(Rc1), src1Ptr, SIZE(Rc1))
  MemCopy(ADDRESS(Rc2), src2Ptr, SIZE(Rc2))
  ! Union: min of tops/lefts, max of bottoms/rights
  if R1:top < R2:top
    R3:top = R1:top
  else
    R3:top = R2:top
  end
  IF R1:left < R2:left
    R3:left = R1:left
  ELSE
    R3:left = R2:left
  END
  If R1:bottom > R2:bottom Then
    R3:bottom = R1:bottom
  Else
    R3:bottom = R2:bottom
  End
  if R1:right > R2:right
    R3:right = R1:right
  else
    R3:right = R2:right
  end
  MemCopy(dstPtr, ADDRESS(Rc3), SIZE(Rc3))
  RETURN 0

! Original Pascal: FUNCTION PtInRect(pt: Point; r: Rect): BOOLEAN;
QDPtInRect Procedure(Long ptPtr, Long rPtr)
  Code
  MemCopy(ADDRESS(Pt1), ptPtr, SIZE(Pt1))
  MemCopy(ADDRESS(Rc1), rPtr, SIZE(Rc1))
  If P1:v >= R1:top and P1:v < R1:bottom and P1:h >= R1:left and P1:h < R1:right
    Return 1
  End
  Return 0
