  MEMBER()
! Graf3D.clw — Clarion implementation of Apple Graf3D 3D graphics library
! Based on Graf3D.p by Apple Computer, 1983
!
! This file deliberately uses variant casing to demonstrate that Clarion
! is case-insensitive. Keywords, types, and variable names appear in
! mixed case throughout — UPPER, lower, and PascalCase are all equivalent.
!
! Original Pascal (Graf3D.p, Apple Computer 1983):
!   CONST radConst=57.29578;  {180/pi}
!   TYPE Point3D = RECORD x,y,z: REAL END;
!        XfMatrix = ARRAY[0..3,0..3] OF REAL;
!
! Fixed-point convention: REAL values are passed as LONG * 10000.
! For example, 1.5 is passed as 15000; -0.0001 is passed as -1.
! Matrix stored as REAL,DIM(16) — flattened: index = row*4+col

! --- Module-level data ---
radConst  REAL(57.29578)        ! 180/pi — degrees to radians divisor

! Current 3D point
curX      real(0)
curY      REAL(0)
curZ      Real(0)

! 4x4 transformation matrix (flattened row-major)
! Original Pascal: XfMatrix = ARRAY[0..3,0..3] OF REAL;
xForm     REAL,DIM(16)

! Temporaries for rotation
tempVal   Real

  MAP
    ! Original Pascal: PROCEDURE Identity;  {reset xForm to identity}
    G3Init(),LONG,C,NAME('G3Init'),EXPORT

    ! Original Pascal: PROCEDURE SetPt3D(VAR pt3D: Point3D; x,y,z: REAL);
    G3SetPt(long xFP, LONG yFP, long zFP),LONG,C,NAME('G3SetPt'),EXPORT

    G3GetPtX(),Long,C,NAME('G3GetPtX'),EXPORT
    G3GetPtY(),LONG,C,NAME('G3GetPtY'),EXPORT
    G3GetPtZ(),long,C,NAME('G3GetPtZ'),EXPORT

    ! Original Pascal: PROCEDURE Identity;
    G3Identity(),LONG,C,NAME('G3Identity'),EXPORT

    ! Original Pascal: PROCEDURE Scale(xFactor,yFactor,zFactor: REAL);
    G3Scale(LONG xFP, Long yFP, long zFP),LONG,C,NAME('G3Scale'),EXPORT

    ! Original Pascal: PROCEDURE Translate(dx,dy,dz: REAL);
    G3Translate(long dxFP, Long dyFP, LONG dzFP),LONG,C,NAME('G3Translate'),EXPORT

    ! Original Pascal: PROCEDURE Pitch(xAngle: REAL);  {rotate around X axis}
    G3Pitch(LONG angleFP),Long,C,NAME('G3Pitch'),EXPORT

    ! Original Pascal: PROCEDURE Yaw(yAngle: REAL);    {rotate around Y axis}
    G3Yaw(long angleFP),LONG,C,NAME('G3Yaw'),EXPORT

    ! Original Pascal: PROCEDURE Roll(zAngle: REAL);   {rotate around Z axis}
    G3Roll(Long angleFP),LONG,C,NAME('G3Roll'),EXPORT

    ! Original Pascal: PROCEDURE TransForm(src: Point3D; VAR dst: Point3D);
    G3Transform(),LONG,C,NAME('G3Transform'),EXPORT

    G3GetMatrix(LONG index),long,C,NAME('G3GetMatrix'),EXPORT
    G3SetMatrix(Long index, LONG valFP),LONG,C,NAME('G3SetMatrix'),EXPORT
  END

! ================================================================
! G3Init — Initialize: reset matrix to identity, clear current point
! Original Pascal: PROCEDURE Identity;
! ================================================================
G3Init    Procedure()
i         long
  CODE
  curX = 0
  curY = 0
  curZ = 0
  loop i = 1 to 16
    xForm[i] = 0
  End
  ! Diagonal = 1: indices 1,6,11,16 (row*4+col+1 for 1-based)
  ! [0,0]=1, [1,1]=6, [2,2]=11, [3,3]=16
  xForm[1]  = 1.0
  xForm[6]  = 1.0
  xForm[11] = 1.0
  xForm[16] = 1.0
  RETURN 0

! ================================================================
! G3SetPt — Set current 3D point from fixed-point values
! Original Pascal: PROCEDURE SetPt3D(VAR pt3D: Point3D; x,y,z: REAL);
! ================================================================
G3SetPt   procedure(long xFP, LONG yFP, long zFP)
  code
  curX = xFP / 10000.0
  curY = yFP / 10000.0
  curZ = zFP / 10000.0
  return 0

! ================================================================
! G3GetPtX/Y/Z — Get current point components as fixed-point
! ================================================================
G3GetPtX  Procedure()
  Code
  Return ROUND(curX * 10000, 1)

G3GetPtY  PROCEDURE()
  CODE
  RETURN ROUND(curY * 10000, 1)

G3GetPtZ  procedure()
  code
  return ROUND(curZ * 10000, 1)

! ================================================================
! G3Identity — Reset transformation matrix to identity
! Original Pascal: PROCEDURE Identity;
!   FOR i:=0 TO 3 DO FOR j:=0 TO 3 DO
!     IF i=j THEN xForm[i,j]:=1 ELSE xForm[i,j]:=0;
! ================================================================
G3Identity Procedure()
i          Long
  Code
  Loop i = 1 to 16
    xForm[i] = 0
  end
  xForm[1]  = 1.0
  xForm[6]  = 1.0
  xForm[11] = 1.0
  xForm[16] = 1.0
  return 0

! ================================================================
! G3Scale — Scale matrix columns
! Original Pascal: PROCEDURE Scale(xFactor,yFactor,zFactor: REAL);
!   FOR i:=0 TO 3 DO BEGIN
!     xForm[i,0] := xForm[i,0] * xFactor;
!     xForm[i,1] := xForm[i,1] * yFactor;
!     xForm[i,2] := xForm[i,2] * zFactor;
!   END;
! ================================================================
G3Scale   procedure(LONG xFP, Long yFP, long zFP)
xFactor   Real
yFactor   REAL
zFactor   real
row       long
base      Long
  code
  xFactor = xFP / 10000.0
  yFactor = yFP / 10000.0
  zFactor = zFP / 10000.0
  ! Multiply each row's columns 0,1,2 by factors
  ! Flattened: col 0 = base+1, col 1 = base+2, col 2 = base+3
  loop row = 0 to 3
    base = row * 4
    xForm[base + 1] = xForm[base + 1] * xFactor
    xForm[base + 2] = xForm[base + 2] * yFactor
    xForm[base + 3] = xForm[base + 3] * zFactor
  End
  Return 0

! ================================================================
! G3Translate — Add translation to row 3 of matrix
! Original Pascal: PROCEDURE Translate(dx,dy,dz: REAL);
!   xForm[3,0] := xForm[3,0] + dx;
!   xForm[3,1] := xForm[3,1] + dy;
!   xForm[3,2] := xForm[3,2] + dz;
! ================================================================
G3Translate Procedure(long dxFP, Long dyFP, LONG dzFP)
dx          REAL
dy          real
dz          Real
  CODE
  dx = dxFP / 10000.0
  dy = dyFP / 10000.0
  dz = dzFP / 10000.0
  ! Row 3, cols 0,1,2 => indices 13,14,15 (1-based)
  xForm[13] = xForm[13] + dx
  xForm[14] = xForm[14] + dy
  xForm[15] = xForm[15] + dz
  RETURN 0

! ================================================================
! G3Pitch — Rotate around X axis by degrees
! Original Pascal: PROCEDURE Pitch(xAngle: REAL);
!   si := SIN(xAngle/radConst); co := COS(xAngle/radConst);
!   FOR i:=0 TO 3 DO BEGIN
!     TEMP := xForm[i,1]*co + xForm[i,2]*si;
!     xForm[i,2] := xForm[i,2]*co - xForm[i,1]*si;
!     xForm[i,1] := TEMP;
!   END;
! Flattened: col 1 = row*4+2, col 2 = row*4+3 (1-based)
! ================================================================
G3Pitch   procedure(LONG angleFP)
angle     real
si        REAL
co        Real
row       long
c1        Long
c2        long
  code
  angle = angleFP / 10000.0
  si = SIN(angle / radConst)
  co = COS(angle / radConst)
  Loop row = 0 to 3
    c1 = row * 4 + 2    ! col 1 (1-based index)
    c2 = row * 4 + 3    ! col 2 (1-based index)
    tempVal = xForm[c1] * co + xForm[c2] * si
    xForm[c2] = xForm[c2] * co - xForm[c1] * si
    xForm[c1] = tempVal
  end
  return 0

! ================================================================
! G3Yaw — Rotate around Y axis by degrees
! Original Pascal: PROCEDURE Yaw(yAngle: REAL);
!   si := SIN(yAngle/radConst); co := COS(yAngle/radConst);
!   FOR i:=0 TO 3 DO BEGIN
!     TEMP := xForm[i,0]*co - xForm[i,2]*si;
!     xForm[i,2] := xForm[i,2]*co + xForm[i,0]*si;
!     xForm[i,0] := TEMP;
!   END;
! Flattened: col 0 = row*4+1, col 2 = row*4+3 (1-based)
! ================================================================
G3Yaw     Procedure(long angleFP)
angle     REAL
si        real
co        Real
row       LONG
c0        long
c2        Long
  Code
  angle = angleFP / 10000.0
  si = SIN(angle / radConst)
  co = COS(angle / radConst)
  loop row = 0 to 3
    c0 = row * 4 + 1    ! col 0 (1-based index)
    c2 = row * 4 + 3    ! col 2 (1-based index)
    tempVal = xForm[c0] * co - xForm[c2] * si
    xForm[c2] = xForm[c2] * co + xForm[c0] * si
    xForm[c0] = tempVal
  End
  Return 0

! ================================================================
! G3Roll — Rotate around Z axis by degrees
! Original Pascal: PROCEDURE Roll(zAngle: REAL);
!   si := SIN(zAngle/radConst); co := COS(zAngle/radConst);
!   FOR i:=0 TO 3 DO BEGIN
!     TEMP := xForm[i,0]*co + xForm[i,1]*si;
!     xForm[i,1] := xForm[i,1]*co - xForm[i,0]*si;
!     xForm[i,0] := TEMP;
!   END;
! Flattened: col 0 = row*4+1, col 1 = row*4+2 (1-based)
! ================================================================
G3Roll    procedure(Long angleFP)
angle     real
si        REAL
co        Real
row       Long
c0        LONG
c1        long
  code
  angle = angleFP / 10000.0
  si = SIN(angle / radConst)
  co = COS(angle / radConst)
  Loop row = 0 to 3
    c0 = row * 4 + 1    ! col 0 (1-based index)
    c1 = row * 4 + 2    ! col 1 (1-based index)
    tempVal = xForm[c0] * co + xForm[c1] * si
    xForm[c1] = xForm[c1] * co - xForm[c0] * si
    xForm[c0] = tempVal
  end
  return 0

! ================================================================
! G3Transform — Apply transformation matrix to current point
! Original Pascal: PROCEDURE TransForm(src: Point3D; VAR dst: Point3D);
!   dst.x := src.x*xForm[0,0] + src.y*xForm[1,0] + src.z*xForm[2,0] + xForm[3,0];
!   dst.y := src.x*xForm[0,1] + src.y*xForm[1,1] + src.z*xForm[2,1] + xForm[3,1];
!   dst.z := src.x*xForm[0,2] + src.y*xForm[1,2] + src.z*xForm[2,2] + xForm[3,2];
!
! Flattened (1-based):
!   [0,0]=1  [0,1]=2  [0,2]=3  [0,3]=4
!   [1,0]=5  [1,1]=6  [1,2]=7  [1,3]=8
!   [2,0]=9  [2,1]=10 [2,2]=11 [2,3]=12
!   [3,0]=13 [3,1]=14 [3,2]=15 [3,3]=16
! ================================================================
G3Transform Procedure()
srcX        Real
srcY        REAL
srcZ        real
  CODE
  srcX = curX
  srcY = curY
  srcZ = curZ
  curX = srcX*xForm[1] + srcY*xForm[5] + srcZ*xForm[9]  + xForm[13]
  curY = srcX*xForm[2] + srcY*xForm[6] + srcZ*xForm[10] + xForm[14]
  curZ = srcX*xForm[3] + srcY*xForm[7] + srcZ*xForm[11] + xForm[15]
  Return 0

! ================================================================
! G3GetMatrix — Get matrix element by flattened index (0-based input)
! Returns fixed-point * 10000
! ================================================================
G3GetMatrix procedure(LONG index)
  code
  ! Convert 0-based input index to 1-based array index
  return ROUND(xForm[index + 1] * 10000, 1)

! ================================================================
! G3SetMatrix — Set matrix element by flattened index (0-based input)
! Value is fixed-point * 10000
! ================================================================
G3SetMatrix Procedure(Long index, LONG valFP)
  Code
  xForm[index + 1] = valFP / 10000.0
  Return 0
