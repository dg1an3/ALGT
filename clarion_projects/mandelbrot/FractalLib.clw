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
! ---------------------------------------------------------------
FLMandelbrot PROCEDURE(LONG cx10k, LONG cy10k, LONG maxIter)
cx    REAL
cy    REAL
zx    REAL
zy    REAL
tmp   REAL
i     LONG
  CODE
  cx = cx10k / 10000.0
  cy = cy10k / 10000.0
  zx = 0.0
  zy = 0.0
  i = 0
  LOOP WHILE i < maxIter
    IF (zx * zx + zy * zy) > 4.0
      RETURN i
    END
    tmp = zx * zx - zy * zy + cx
    zy = 2.0 * zx * zy + cy
    zx = tmp
    i += 1
  END
  RETURN maxIter

! ---------------------------------------------------------------
! FLJulia: compute Julia iteration count for initial z with constant c
! ---------------------------------------------------------------
FLJulia PROCEDURE(LONG zx10k, LONG zy10k, LONG cx10k, LONG cy10k, LONG maxIter)
cx    REAL
cy    REAL
zx    REAL
zy    REAL
tmp   REAL
i     LONG
  CODE
  cx = cx10k / 10000.0
  cy = cy10k / 10000.0
  zx = zx10k / 10000.0
  zy = zy10k / 10000.0
  i = 0
  LOOP WHILE i < maxIter
    IF (zx * zx + zy * zy) > 4.0
      RETURN i
    END
    tmp = zx * zx - zy * zy + cx
    zy = 2.0 * zx * zy + cy
    zx = tmp
    i += 1
  END
  RETURN maxIter

! ---------------------------------------------------------------
! FLMandelbrotRow: compute full row of Mandelbrot values into buffer
! For pixel i in 0..width-1: cx = xMin + i*(xMax-xMin)/width
! Write iteration count to buffer[i] (array of LONGs)
! ---------------------------------------------------------------
FLMandelbrotRow PROCEDURE(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG maxIter)
cx    REAL
cy    REAL
zx    REAL
zy    REAL
tmp   REAL
xMin  REAL
xMax  REAL
step  REAL
i     LONG
j     LONG
val   LONG
  CODE
  xMin = xMin10k / 10000.0
  xMax = xMax10k / 10000.0
  cy = y10k / 10000.0
  step = (xMax - xMin) / width
  i = 0
  LOOP WHILE i < width
    cx = xMin + i * step
    zx = 0.0
    zy = 0.0
    j = 0
    LOOP WHILE j < maxIter
      IF (zx * zx + zy * zy) > 4.0
        BREAK
      END
      tmp = zx * zx - zy * zy + cx
      zy = 2.0 * zx * zy + cy
      zx = tmp
      j += 1
    END
    val = j
    MemCopy(bufPtr + i * 4, ADDRESS(val), 4)
    i += 1
  END
  RETURN 0

! ---------------------------------------------------------------
! FLJuliaRow: compute full row of Julia values into buffer
! ---------------------------------------------------------------
FLJuliaRow PROCEDURE(LONG bufPtr, LONG width, LONG y10k, LONG xMin10k, LONG xMax10k, LONG cx10k, LONG cy10k, LONG maxIter)
cx    REAL
cy    REAL
zx    REAL
zy    REAL
tmp   REAL
xMin  REAL
xMax  REAL
step  REAL
i     LONG
j     LONG
val   LONG
  CODE
  cx = cx10k / 10000.0
  cy = cy10k / 10000.0
  xMin = xMin10k / 10000.0
  xMax = xMax10k / 10000.0
  step = (xMax - xMin) / width
  i = 0
  LOOP WHILE i < width
    zx = xMin + i * step
    zy = y10k / 10000.0
    j = 0
    LOOP WHILE j < maxIter
      IF (zx * zx + zy * zy) > 4.0
        BREAK
      END
      tmp = zx * zx - zy * zy + cx
      zy = 2.0 * zx * zy + cy
      zx = tmp
      j += 1
    END
    val = j
    MemCopy(bufPtr + i * 4, ADDRESS(val), 4)
    i += 1
  END
  RETURN 0

! ---------------------------------------------------------------
! FLLogistic: one iteration of logistic map p_new = p + k*p*(1-p)
! All values in fixed-point * 10000
! ---------------------------------------------------------------
FLLogistic PROCEDURE(LONG p10k, LONG k10k)
p     REAL
k     REAL
pNew  REAL
  CODE
  p = p10k / 10000.0
  k = k10k / 10000.0
  pNew = p + k * p * (1.0 - p)
  RETURN ROUND(pNew * 10000.0, 1)

! ---------------------------------------------------------------
! FLLogisticIterate: iterate logistic map, store values after skip
! ---------------------------------------------------------------
FLLogisticIterate PROCEDURE(LONG p10k, LONG k10k, LONG steps, LONG skip, LONG bufPtr, LONG bufSize)
p     REAL
k     REAL
i     LONG
stored LONG
val   LONG
  CODE
  p = p10k / 10000.0
  k = k10k / 10000.0
  stored = 0
  i = 0
  LOOP WHILE i < steps
    p = p + k * p * (1.0 - p)
    IF i >= skip AND stored < bufSize
      val = ROUND(p * 10000.0, 1)
      MemCopy(bufPtr + stored * 4, ADDRESS(val), 4)
      stored += 1
    END
    i += 1
  END
  RETURN stored
