  MEMBER()

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    FLMandelbrot(LONG cx10k, LONG cy10k, LONG maxIter),LONG,C,NAME('FLMandelbrot'),EXPORT
    FLJulia(LONG zx10k, LONG zy10k, LONG cx10k, LONG cy10k, LONG maxIter),LONG,C,NAME('FLJulia'),EXPORT
    FLMandelbrotRow(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG maxIter),LONG,C,NAME('FLMandelbrotRow'),EXPORT
    FLJuliaRow(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG cx10k, LONG cy10k, LONG maxIter),LONG,C,NAME('FLJuliaRow'),EXPORT
    FLLogistic(LONG p10k, LONG k10k),LONG,C,NAME('FLLogistic'),EXPORT
    FLLogisticIterate(LONG p10k, LONG k10k, LONG steps, LONG skip, LONG bufPtr, LONG bufSize),LONG,C,NAME('FLLogisticIterate'),EXPORT
  END

! ---------------------------------------------------------------
! FLMandelbrot: compute iteration count for c = (cx/10000, cy/10000)
! Iterate z = z^2 + c until |z|^2 > 4 or maxIter reached
!
! Original Pascal (MANDEL.PAS):
!   While (X*X+Y*Y<4.0) and (Count<100) do begin
!     XY := 2*X*Y;
!     X := X*X - Y*Y + LambdaX;
!     Y := XY + LambdaY;
!     Count := Count+1;
!   End;
! ---------------------------------------------------------------
FLMandelbrot PROCEDURE(LONG cx10k, LONG cy10k, LONG maxIter)
Cx    Real
Cy    Real
zx    Real
zy    Real
tmp   Real
count Long
  CODE
  Cx = cx10k / 10000.0
  Cy = cy10k / 10000.0
  zx = 0.0
  zy = 0.0
  count = 0
  Loop While count < maxIter
    If (zx * zx + zy * zy) > 4.0
      RETURN count
    End
    tmp = zx * zx - zy * zy + Cx
    zy = 2.0 * zx * zy + Cy
    zx = tmp
    count += 1
  End
  RETURN maxIter

! ---------------------------------------------------------------
! FLJulia: compute Julia iteration count for initial z with constant c
!
! Original C (JULIAB.C, D.G.Lane):
!   R = sqrt((X-A1)*(X-A1) + (Y-B1)*(Y-B1)) / 2.0;
!   T = (X-A1) / 2.0;
!   X1[J] = sqrt(R + T);
!   Y1[J] = sqrt(R - T);
! Note: Our Clarion version uses forward iteration (z=z^2+c) not
! inverse iteration like the original C.
! ---------------------------------------------------------------
FLJulia PROCEDURE(LONG zx10k, LONG zy10k, LONG cx10k, LONG cy10k, LONG maxIter)
cx    Real
cy    Real
ZX    Real
ZY    Real
Tmp   Real
iter  Long
  CODE
  cx = cx10k / 10000.0
  cy = cy10k / 10000.0
  ZX = zx10k / 10000.0
  ZY = zy10k / 10000.0
  iter = 0
  LOOP WHILE iter < maxIter
    If (ZX * ZX + ZY * ZY) > 4.0
      Return iter
    End
    Tmp = ZX * ZX - ZY * ZY + cx
    ZY = 2.0 * ZX * ZY + cy
    ZX = Tmp
    iter += 1
  END
  Return maxIter

! ---------------------------------------------------------------
! FLMandelbrotRow: compute full row of Mandelbrot values into buffer
! For pixel i in 0..width-1: cx = xMin + i*(xMax-xMin)/width
! Write iteration count to buffer[i] (array of LONGs)
! ---------------------------------------------------------------
FLMandelbrotRow PROCEDURE(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG maxIter)
Cx    Real
cy    Real
zx    Real
zy    Real
tmp   Real
xmin  Real
xmax  Real
Step  Real
col   Long
j     Long
val   LONG
  CODE
  xmin = xMin10k / 10000.0
  xmax = xMax10k / 10000.0
  cy = y10k / 10000.0
  Step = (xmax - xmin) / width
  col = 0
  Loop While col < width
    Cx = xmin + col * Step
    zx = 0.0
    zy = 0.0
    j = 0
    Loop While j < maxIter
      If (zx * zx + zy * zy) > 4.0
        BREAK
      End
      tmp = zx * zx - zy * zy + Cx
      zy = 2.0 * zx * zy + cy
      zx = tmp
      j += 1
    End
    val = j
    MemCopy(bufPtr + col * 4, ADDRESS(val), 4)
    col += 1
  End
  RETURN 0

! ---------------------------------------------------------------
! FLJuliaRow: compute full row of Julia values into buffer
! ---------------------------------------------------------------
FLJuliaRow PROCEDURE(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG cx10k, LONG cy10k, LONG maxIter)
cx    Real
cy    Real
ZX    Real
ZY    Real
Tmp   Real
xMin  Real
xMax  Real
step  Real
col   Long
j     Long
Val   Long
  CODE
  cx = cx10k / 10000.0
  cy = cy10k / 10000.0
  xMin = xMin10k / 10000.0
  xMax = xMax10k / 10000.0
  step = (xMax - xMin) / width
  col = 0
  Loop While col < width
    ZX = xMin + col * step
    ZY = y10k / 10000.0
    j = 0
    Loop While j < maxIter
      If (ZX * ZX + ZY * ZY) > 4.0
        BREAK
      End
      Tmp = ZX * ZX - ZY * ZY + cx
      ZY = 2.0 * ZX * ZY + cy
      ZX = Tmp
      j += 1
    End
    Val = j
    MemCopy(bufPtr + col * 4, ADDRESS(Val), 4)
    col += 1
  End
  Return 0

! ---------------------------------------------------------------
! FLLogistic: one iteration of logistic map p_new = p + k*p*(1-p)
! All values in fixed-point * 10000
!
! Original C (MEASLES.C, Becker & Dorfler p.23):
!   double f(double p, double k) {
!     return (p + k*p*(1-p));
!   }
! ---------------------------------------------------------------
FLLogistic PROCEDURE(LONG p10k, LONG k10k)
population Real
rate       Real
pNew       Real
  CODE
  population = p10k / 10000.0
  rate = k10k / 10000.0
  pNew = population + rate * population * (1.0 - population)
  RETURN ROUND(pNew * 10000.0, 1)

! ---------------------------------------------------------------
! FLLogisticIterate: iterate logistic map, store values after skip
! ---------------------------------------------------------------
FLLogisticIterate PROCEDURE(LONG p10k, LONG k10k, LONG steps, LONG skip, LONG bufPtr, LONG bufSize)
p      Real
k      Real
i      Long
stored Long
val    LONG
  CODE
  p = p10k / 10000.0
  k = k10k / 10000.0
  stored = 0
  i = 0
  Loop While i < steps
    p = p + k * p * (1.0 - p)
    If i >= skip AND stored < bufSize
      val = ROUND(p * 10000.0, 1)
      MemCopy(bufPtr + stored * 4, ADDRESS(val), 4)
      stored += 1
    End
    i += 1
  End
  RETURN stored
