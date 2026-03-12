  member()

! ============================================================================
! OptimLib - Numerical Optimization Library
! Port of dH/OptimizeN (Brent line search + Powell conjugate gradient)
!
! Implements two optimization algorithms:
!   1. Brent's method for 1D line minimization
!      - Bracket phase: finds three points surrounding minimum
!      - Minimize phase: parabolic interpolation with golden section fallback
!
!   2. Powell conjugate gradient for multi-dimensional minimization
!      - Uses Polak-Ribiere direction updates
!      - Embedded Brent optimizer for line search
!      - Supports gradient-based optimization
!
! Both use a step-by-step API for external function evaluation:
!   - Caller creates optimizer, sets parameters
!   - Calls Step() which returns status codes:
!     STAT_NEED_FEVAL = 1: evaluate f(x) and call SetFValue
!     STAT_NEED_GEVAL = 2: evaluate gradient and call SetGrad
!     STAT_DONE = 3: optimization complete
!   - Caller retrieves results via GetMinX / GetMinF
!
! Reference: Numerical Recipes, Powell conjugate direction algorithm
! Copyright (C) dH 1996-2004
! ============================================================================

! --- Status codes ---
STAT_IDLE       EQUATE(0)
STAT_NEED_FEVAL equate(1)       ! Caller must evaluate f(x)
STAT_NEED_GEVAL EQUATE(2)       ! Caller must evaluate gradient
STAT_DONE       equate(3)       ! Optimization complete
STAT_ERROR      Equate(-1)

! --- Brent algorithm sub-states ---
BR_INIT         equate(0)
BR_BRACKET_1    EQUATE(1)       ! Evaluating f(ax)
BR_BRACKET_2    equate(2)       ! Evaluating f(bx)
BR_BRACKET_3    EQUATE(3)       ! Evaluating f(cx) / expansion
BR_BRACKET_4    equate(4)       ! Additional bracket eval
BR_MINIMIZE     EQUATE(5)       ! Main Brent minimization loop
BR_EVAL_STEP    equate(6)       ! Waiting for f(u) during minimize
BR_DONE         EQUATE(7)

! --- CG algorithm sub-states ---
CG_INIT         Equate(0)
CG_EVAL_F0      equate(1)       ! Initial function eval
CG_EVAL_G0      EQUATE(2)       ! Initial gradient eval
CG_LINE_SEARCH  equate(3)       ! Running embedded Brent
CG_EVAL_FG      EQUATE(4)       ! Eval f+grad at new point
CG_CHECK_CONV   equate(5)       ! Check convergence
CG_DONE         EQUATE(6)

! --- Configuration ---
MAX_BRENT       Equate(4)       ! Max simultaneous Brent optimizers
MAX_CG          equate(4)       ! Max simultaneous CG optimizers
MAX_DIM         EQUATE(512)     ! Max optimization dimensions
MAX_BRENT_ITER  equate(1000)    ! Max Brent iterations
MAX_CG_ITER     EQUATE(500)     ! Max CG iterations

! --- Constants ---
! Golden ratio and related constants (Numerical Recipes)
GOLD_RATIO      equate(1618034) ! 1.618034 * 1e6 (stored as integer, converted)
CGOLD_RATIO     equate(381966)  ! 0.381966 * 1e6
TINY_VAL        equate(100)     ! 1.0e-20 * 1e22
ZEPS_VAL        equate(100)     ! 1.0e-10 * 1e12

! ============================================================================
! Brent optimizer state (flat arrays, handle-based)
! ============================================================================

! Brent state arrays (one slot per handle)
BrInUse     long,DIM(MAX_BRENT)
BrTol       REAL,dim(MAX_BRENT)
BrStatus    long,DIM(MAX_BRENT)      ! BR_* sub-state
BrIter      LONG,dim(MAX_BRENT)      ! iteration count

! Bracket points
BrAx        real,DIM(MAX_BRENT)       ! left bracket
BrBx        REAL,dim(MAX_BRENT)       ! middle (initial guess)
BrCx        real,DIM(MAX_BRENT)       ! right bracket
BrFa        REAL,dim(MAX_BRENT)       ! f(ax)
BrFb        real,DIM(MAX_BRENT)       ! f(bx)
BrFc        REAL,dim(MAX_BRENT)       ! f(cx)

! Brent minimize state
BrA         real,DIM(MAX_BRENT)       ! current bracket lower
BrB         REAL,dim(MAX_BRENT)       ! current bracket upper
BrX         real,DIM(MAX_BRENT)       ! best x so far
BrW         REAL,dim(MAX_BRENT)       ! second best x
BrV         real,DIM(MAX_BRENT)       ! third best x
BrFx        REAL,dim(MAX_BRENT)       ! f(best x)
BrFw        real,DIM(MAX_BRENT)       ! f(second best)
BrFv        REAL,dim(MAX_BRENT)       ! f(third best)
BrD         real,DIM(MAX_BRENT)       ! step size
BrE         REAL,dim(MAX_BRENT)       ! step before last
BrU         real,DIM(MAX_BRENT)       ! trial point
BrFu        REAL,dim(MAX_BRENT)       ! f(trial point)
BrEvalX     real,DIM(MAX_BRENT)       ! x value to evaluate

! ============================================================================
! Conjugate gradient state (flat arrays, handle-based)
! ============================================================================

CgInUse     LONG,dim(MAX_CG)
CgNDim      long,DIM(MAX_CG)         ! problem dimension
CgTol       REAL,dim(MAX_CG)
CgStatus    long,DIM(MAX_CG)         ! CG_* sub-state
CgIter      LONG,dim(MAX_CG)         ! iteration count

! CG vectors (flat: handle * MAX_DIM + idx)
CgX         REAL,DIM(MAX_CG * MAX_DIM)   ! current point
CgGrad      real,DIM(MAX_CG * MAX_DIM)   ! gradient at current
CgGradPrev  REAL,DIM(MAX_CG * MAX_DIM)   ! previous gradient
CgDir       real,DIM(MAX_CG * MAX_DIM)   ! search direction
CgDirPrev   REAL,DIM(MAX_CG * MAX_DIM)   ! previous direction
CgLineOrig  real,DIM(MAX_CG * MAX_DIM)   ! line search origin
CgLineDir   REAL,DIM(MAX_CG * MAX_DIM)   ! line search direction

! CG scalars
CgFx        real,DIM(MAX_CG)          ! f at current point
CgFxPrev    REAL,dim(MAX_CG)          ! f at previous point
CgGamma     real,DIM(MAX_CG)          ! Polak-Ribiere coefficient
CgLambda    REAL,dim(MAX_CG)          ! line search result
CgBrentH    long,DIM(MAX_CG)          ! embedded Brent handle

! CG eval point (for returning to caller)
CgEvalX     REAL,DIM(MAX_CG * MAX_DIM)

  MAP
    ! --- Brent 1D optimizer ---
    BrentCreate(REAL tol),LONG,C,NAME('BrentCreate'),EXPORT
    BrentFree(LONG h),LONG,C,NAME('BrentFree'),EXPORT
    BrentSetBracket(LONG h, REAL ax, REAL bx),LONG,C,NAME('BrentSetBracket'),EXPORT
    BrentStep(LONG h),LONG,C,NAME('BrentStep'),EXPORT
    BrentGetEvalX(LONG h),REAL,C,NAME('BrentGetEvalX'),EXPORT
    BrentSetFValue(LONG h, REAL fval),LONG,C,NAME('BrentSetFValue'),EXPORT
    BrentGetMinX(LONG h),REAL,C,NAME('BrentGetMinX'),EXPORT
    BrentGetMinF(LONG h),REAL,C,NAME('BrentGetMinF'),EXPORT
    BrentGetIter(LONG h),LONG,C,NAME('BrentGetIter'),EXPORT

    ! --- Conjugate gradient optimizer ---
    CGCreate(LONG ndim, REAL tol),LONG,C,NAME('CGCreate'),EXPORT
    CGFree(LONG h),LONG,C,NAME('CGFree'),EXPORT
    CGSetInitial(LONG h, LONG idx, REAL val),LONG,C,NAME('CGSetInitial'),EXPORT
    CGStep(LONG h),LONG,C,NAME('CGStep'),EXPORT
    CGGetEvalX(LONG h, LONG idx),REAL,C,NAME('CGGetEvalX'),EXPORT
    CGSetFValue(LONG h, REAL fval),LONG,C,NAME('CGSetFValue'),EXPORT
    CGSetGrad(LONG h, LONG idx, REAL val),LONG,C,NAME('CGSetGrad'),EXPORT
    CGGetResult(LONG h, LONG idx),REAL,C,NAME('CGGetResult'),EXPORT
    CGGetMinF(LONG h),REAL,C,NAME('CGGetMinF'),EXPORT
    CGGetIter(LONG h),LONG,C,NAME('CGGetIter'),EXPORT

    ! --- Internal helpers ---
    CgVecIdx(LONG h, LONG idx),LONG
    BrentDoMinStep(LONG h),LONG
    LocalSign(REAL a, REAL b),REAL
    LocalMax(REAL a, REAL b),REAL
    LocalMin(REAL a, REAL b),REAL
  END

! ============================================================================
! Helper functions
! ============================================================================

CgVecIdx Procedure(Long h, Long idx)
  Code
  ! Maps (handle, dimension_index) to flat array position
  Return (h - 1) * MAX_DIM + idx + 1

LocalSign PROCEDURE(REAL a, REAL b)
  Code
  ! Returns |a| with the sign of b (Fortran SIGN function)
  If b >= 0
    Return ABS(a)
  Else
    Return -ABS(a)
  End

LocalMax procedure(Real a, Real b)
  CODE
  if a > b
    RETURN a
  end
  Return b

LocalMin PROCEDURE(real a, real b)
  code
  IF a < b
    return a
  END
  RETURN b

! ============================================================================
! Brent optimizer implementation
! ============================================================================

BrentCreate procedure(REAL tol)
h LONG
  code
  ! Find free slot
  LOOP h = 1 to MAX_BRENT
    if BrInUse[h] = 0
      BrInUse[h] = 1
      BrTol[h] = tol
      BrStatus[h] = BR_INIT
      BrIter[h] = 0
      BrD[h] = 0
      BrE[h] = 0
      Return h
    END
  end
  RETURN -1  ! no free slots

BrentFree PROCEDURE(long h)
  CODE
  if h < 1 OR h > MAX_BRENT then return -1.
  BrInUse[h] = 0
  RETURN 0

! BrentSetBracket: set initial bracket [ax, bx] and start bracketing
! The algorithm will find cx such that f(bx) < f(ax) and f(bx) < f(cx)
BrentSetBracket procedure(Long h, Real ax, Real bx)
  Code
  If h < 1 Or h > MAX_BRENT Then Return -1.
  If BrInUse[h] = 0 Then Return -1.
  BrAx[h] = ax
  BrBx[h] = bx
  BrStatus[h] = BR_BRACKET_1
  BrEvalX[h] = ax
  Return 0

! BrentStep: advance the optimizer by one step.
! Returns STAT_NEED_FEVAL if caller must evaluate f(BrentGetEvalX()).
! Returns STAT_DONE when minimum is found.
BrentStep Procedure(Long h)
gold    Real
fu      Real
r       Real
q       Real
ulim    Real
temp    Real
  Code
  If h < 1 Or h > MAX_BRENT Then Return STAT_ERROR.
  If BrInUse[h] = 0 Then Return STAT_ERROR.

  gold = 1.618034

  ! --- Bracketing phase ---
  Case BrStatus[h]
  Of BR_BRACKET_1
    ! Need f(ax) — request evaluation
    BrEvalX[h] = BrAx[h]
    Return STAT_NEED_FEVAL

  Of BR_BRACKET_2
    ! Have f(ax) in BrFa, need f(bx)
    BrEvalX[h] = BrBx[h]
    Return STAT_NEED_FEVAL

  Of BR_BRACKET_3
    ! Have f(ax) and f(bx). Ensure f(bx) <= f(ax) by swapping if needed.
    If BrFb[h] > BrFa[h]
      temp = BrAx[h]
      BrAx[h] = BrBx[h]
      BrBx[h] = temp
      temp = BrFa[h]
      BrFa[h] = BrFb[h]
      BrFb[h] = temp
    End
    ! Golden section extrapolation for initial cx
    BrCx[h] = BrBx[h] + gold * (BrBx[h] - BrAx[h])
    BrEvalX[h] = BrCx[h]
    Return STAT_NEED_FEVAL

  Of BR_BRACKET_4
    ! Have f(cx). If f(bx) < f(cx), bracket is [ax, bx, cx] — done bracketing.
    If BrFb[h] <= BrFc[h]
      ! Bracket found: f(ax) >= f(bx) <= f(cx)
      ! Initialize Brent minimization state
      If BrAx[h] < BrCx[h]
        BrA[h] = BrAx[h]
        BrB[h] = BrCx[h]
      Else
        BrA[h] = BrCx[h]
        BrB[h] = BrAx[h]
      End
      BrX[h] = BrBx[h]
      BrW[h] = BrBx[h]
      BrV[h] = BrBx[h]
      BrFx[h] = BrFb[h]
      BrFw[h] = BrFb[h]
      BrFv[h] = BrFb[h]
      BrE[h] = 0
      BrD[h] = 0
      BrStatus[h] = BR_MINIMIZE
      Return BrentDoMinStep(h)
    Else
      ! Extend bracket: shift and try further
      BrAx[h] = BrBx[h]
      BrFa[h] = BrFb[h]
      BrBx[h] = BrCx[h]
      BrFb[h] = BrFc[h]
      BrCx[h] = BrBx[h] + gold * (BrBx[h] - BrAx[h])
      BrEvalX[h] = BrCx[h]
      Return STAT_NEED_FEVAL
    End

  Of BR_MINIMIZE
    Return BrentDoMinStep(h)

  Of BR_EVAL_STEP
    ! We have f(u) result in BrFu[h]
    ! Update bracket and best points
    fu = BrFu[h]
    If fu <= BrFx[h]
      ! New point is better than current best
      If BrU[h] >= BrX[h]
        BrA[h] = BrX[h]
      Else
        BrB[h] = BrX[h]
      End
      BrV[h] = BrW[h]
      BrFv[h] = BrFw[h]
      BrW[h] = BrX[h]
      BrFw[h] = BrFx[h]
      BrX[h] = BrU[h]
      BrFx[h] = fu
    Else
      ! New point is worse — tighten bracket
      If BrU[h] < BrX[h]
        BrA[h] = BrU[h]
      Else
        BrB[h] = BrU[h]
      End
      If fu <= BrFw[h] Or BrW[h] = BrX[h]
        BrV[h] = BrW[h]
        BrFv[h] = BrFw[h]
        BrW[h] = BrU[h]
        BrFw[h] = fu
      Elsif fu <= BrFv[h] Or BrV[h] = BrX[h] Or BrV[h] = BrW[h]
        BrV[h] = BrU[h]
        BrFv[h] = fu
      End
    End
    BrStatus[h] = BR_MINIMIZE
    Return BrentDoMinStep(h)

  Of BR_DONE
    Return STAT_DONE
  End

  Return STAT_ERROR

! BrentDoMinStep: compute next trial point using parabolic/golden section
BrentDoMinStep Procedure(Long h)
xm      Real
tol1    Real
tol2    Real
r       Real
q       Real
p       Real
eTemp   Real
cgold   Real
  Code
  cgold = 0.3819660
  BrIter[h] += 1

  ! Check iteration limit
  If BrIter[h] > MAX_BRENT_ITER
    BrStatus[h] = BR_DONE
    Return STAT_DONE
  End

  xm = 0.5 * (BrA[h] + BrB[h])
  tol1 = BrTol[h] * ABS(BrX[h]) + 1.0e-10
  tol2 = 2.0 * tol1

  ! Convergence check: bracket small enough?
  If ABS(BrX[h] - xm) <= (tol2 - 0.5 * (BrB[h] - BrA[h]))
    BrStatus[h] = BR_DONE
    Return STAT_DONE
  End

  ! Try parabolic interpolation
  If ABS(BrE[h]) > tol1
    ! Fit parabola through x, w, v
    r = (BrX[h] - BrW[h]) * (BrFx[h] - BrFv[h])
    q = (BrX[h] - BrV[h]) * (BrFx[h] - BrFw[h])
    p = (BrX[h] - BrV[h]) * q - (BrX[h] - BrW[h]) * r
    q = 2.0 * (q - r)
    If q > 0
      p = -p
    Else
      q = -q
    End
    eTemp = BrE[h]
    BrE[h] = BrD[h]

    ! Accept parabolic step if it's within bounds and smaller than half last step
    If ABS(p) < ABS(0.5 * q * eTemp) And p > q * (BrA[h] - BrX[h]) And p < q * (BrB[h] - BrX[h])
      BrD[h] = p / q
      BrU[h] = BrX[h] + BrD[h]
      ! Don't evaluate too close to bracket endpoints
      If (BrU[h] - BrA[h]) < tol2 Or (BrB[h] - BrU[h]) < tol2
        BrD[h] = LocalSign(tol1, xm - BrX[h])
      End
    Else
      ! Fall back to golden section
      If BrX[h] >= xm
        BrE[h] = BrA[h] - BrX[h]
      Else
        BrE[h] = BrB[h] - BrX[h]
      End
      BrD[h] = cgold * BrE[h]
    End
  Else
    ! Golden section step
    If BrX[h] >= xm
      BrE[h] = BrA[h] - BrX[h]
    Else
      BrE[h] = BrB[h] - BrX[h]
    End
    BrD[h] = cgold * BrE[h]
  End

  ! Set trial point — don't step smaller than tol1
  If ABS(BrD[h]) >= tol1
    BrU[h] = BrX[h] + BrD[h]
  Else
    BrU[h] = BrX[h] + LocalSign(tol1, BrD[h])
  End

  BrEvalX[h] = BrU[h]
  BrStatus[h] = BR_EVAL_STEP
  Return STAT_NEED_FEVAL

! BrentSetFValue: provide the function value at the requested eval point
BrentSetFValue Procedure(Long h, Real fval)
  Code
  If h < 1 Or h > MAX_BRENT Then Return -1.

  Case BrStatus[h]
  Of BR_BRACKET_1
    BrFa[h] = fval
    BrStatus[h] = BR_BRACKET_2
  Of BR_BRACKET_2
    BrFb[h] = fval
    BrStatus[h] = BR_BRACKET_3
  Of BR_BRACKET_3
    BrFc[h] = fval
    BrStatus[h] = BR_BRACKET_4
  Of BR_BRACKET_4
    BrFc[h] = fval
    ! Stay in BR_BRACKET_4 — BrentStep will handle
  Of BR_EVAL_STEP
    BrFu[h] = fval
    ! Stay in BR_EVAL_STEP — BrentStep will process
  End
  Return 0

BrentGetEvalX Procedure(Long h)
  Code
  If h < 1 Or h > MAX_BRENT Then Return 0.
  Return BrEvalX[h]

BrentGetMinX Procedure(Long h)
  Code
  If h < 1 Or h > MAX_BRENT Then Return 0.
  Return BrX[h]

BrentGetMinF Procedure(Long h)
  Code
  If h < 1 Or h > MAX_BRENT Then Return 0.
  Return BrFx[h]

BrentGetIter Procedure(Long h)
  Code
  If h < 1 Or h > MAX_BRENT Then Return 0.
  Return BrIter[h]

! ============================================================================
! Conjugate gradient optimizer implementation
! ============================================================================

CGCreate procedure(Long ndim, Real tol)
h   Long
idx Long
  Code
  If ndim > MAX_DIM Then Return -1.
  Loop h = 1 To MAX_CG
    If CgInUse[h] = 0
      CgInUse[h] = 1
      CgNDim[h] = ndim
      CgTol[h] = tol
      CgStatus[h] = CG_INIT
      CgIter[h] = 0
      CgFx[h] = 0
      CgFxPrev[h] = 0
      CgGamma[h] = 0
      CgBrentH[h] = 0
      ! Zero all vectors
      Loop idx = 1 To ndim
        CgX[CgVecIdx(h, idx)] = 0
        CgGrad[CgVecIdx(h, idx)] = 0
        CgGradPrev[CgVecIdx(h, idx)] = 0
        CgDir[CgVecIdx(h, idx)] = 0
        CgDirPrev[CgVecIdx(h, idx)] = 0
        CgLineOrig[CgVecIdx(h, idx)] = 0
        CgLineDir[CgVecIdx(h, idx)] = 0
        CgEvalX[CgVecIdx(h, idx)] = 0
      End
      Return h
    End
  End
  Return -1

CGFree Procedure(Long h)
  Code
  If h < 1 Or h > MAX_CG Then Return -1.
  ! Free embedded Brent if active
  If CgBrentH[h] > 0
    BrentFree(CgBrentH[h])
    CgBrentH[h] = 0
  End
  CgInUse[h] = 0
  Return 0

CGSetInitial Procedure(Long h, Long idx, Real val)
  Code
  If h < 1 Or h > MAX_CG Then Return -1.
  If idx < 1 Or idx > CgNDim[h] Then Return -1.
  CgX[CgVecIdx(h, idx)] = val
  Return 0

! CGStep: advance the conjugate gradient optimizer.
! Returns STAT_NEED_FEVAL, STAT_NEED_GEVAL, or STAT_DONE.
CGStep Procedure(Long h)
idx       Long
ndim      Long
gg        Real
dgg       Real
gamma     Real
fPrev     Real
fCurr     Real
lambda    Real
brStat    Long
vi        Long
  Code
  If h < 1 Or h > MAX_CG Then Return STAT_ERROR.
  If CgInUse[h] = 0 Then Return STAT_ERROR.

  ndim = CgNDim[h]

  Case CgStatus[h]
  Of CG_INIT
    ! Copy starting point to eval buffer
    Loop idx = 1 To ndim
      CgEvalX[CgVecIdx(h, idx)] = CgX[CgVecIdx(h, idx)]
    End
    CgStatus[h] = CG_EVAL_F0
    Return STAT_NEED_FEVAL

  Of CG_EVAL_F0
    ! Have initial f(x0), now need gradient
    CgStatus[h] = CG_EVAL_G0
    Return STAT_NEED_GEVAL

  Of CG_EVAL_G0
    ! Have initial gradient. Set initial direction = -gradient (steepest descent).
    Loop idx = 1 To ndim
      CgGradPrev[CgVecIdx(h, idx)] = CgGrad[CgVecIdx(h, idx)]
      CgDir[CgVecIdx(h, idx)] = -CgGrad[CgVecIdx(h, idx)]
      CgDirPrev[CgVecIdx(h, idx)] = CgDir[CgVecIdx(h, idx)]
    End
    CgFxPrev[h] = CgFx[h]
    ! Fall through to line search setup
    CgStatus[h] = CG_LINE_SEARCH
    ! Save line search origin and direction
    Loop idx = 1 To ndim
      CgLineOrig[CgVecIdx(h, idx)] = CgX[CgVecIdx(h, idx)]
      CgLineDir[CgVecIdx(h, idx)] = CgDir[CgVecIdx(h, idx)]
    End
    ! Create Brent optimizer for line search
    If CgBrentH[h] > 0
      BrentFree(CgBrentH[h])
    End
    CgBrentH[h] = BrentCreate(CgTol[h])
    BrentSetBracket(CgBrentH[h], 0.0, 1.0)
    ! Request first Brent eval
    lambda = BrentGetEvalX(CgBrentH[h])
    ! Set eval point = origin + lambda * direction
    Loop idx = 1 To ndim
      vi = CgVecIdx(h, idx)
      CgEvalX[vi] = CgLineOrig[vi] + lambda * CgLineDir[vi]
    End
    Return STAT_NEED_FEVAL

  Of CG_LINE_SEARCH
    ! Advance Brent line search
    BrentSetFValue(CgBrentH[h], CgFx[h])
    brStat = BrentStep(CgBrentH[h])
    If brStat = STAT_DONE
      ! Line search complete — update position
      lambda = BrentGetMinX(CgBrentH[h])
      CgFx[h] = BrentGetMinF(CgBrentH[h])
      Loop idx = 1 To ndim
        vi = CgVecIdx(h, idx)
        CgX[vi] = CgLineOrig[vi] + lambda * CgLineDir[vi]
        CgEvalX[vi] = CgX[vi]
      End
      BrentFree(CgBrentH[h])
      CgBrentH[h] = 0
      CgIter[h] += 1
      CgStatus[h] = CG_EVAL_FG
      ! Need gradient at new point
      Return STAT_NEED_GEVAL
    Elsif brStat = STAT_NEED_FEVAL
      ! Brent wants f(lambda)
      lambda = BrentGetEvalX(CgBrentH[h])
      Loop idx = 1 To ndim
        vi = CgVecIdx(h, idx)
        CgEvalX[vi] = CgLineOrig[vi] + lambda * CgLineDir[vi]
      End
      Return STAT_NEED_FEVAL
    Else
      Return STAT_ERROR
    End

  Of CG_EVAL_FG
    ! Have gradient at new point. Check convergence.
    fPrev = CgFxPrev[h]
    fCurr = CgFx[h]

    ! Convergence: 2|fp - fc| <= tol * (|fp| + |fc| + 1e-10)
    If 2.0 * ABS(fPrev - fCurr) <= CgTol[h] * (ABS(fPrev) + ABS(fCurr) + 1.0e-10)
      CgStatus[h] = CG_DONE
      Return STAT_DONE
    End

    ! Check iteration limit
    If CgIter[h] >= MAX_CG_ITER
      CgStatus[h] = CG_DONE
      Return STAT_DONE
    End

    ! Polak-Ribiere direction update
    ! gamma = (grad_new . (grad_new - grad_prev)) / (grad_prev . grad_prev)
    gg = 0
    dgg = 0
    Loop idx = 1 To ndim
      vi = CgVecIdx(h, idx)
      gg += CgGradPrev[vi] * CgGradPrev[vi]
      dgg += CgGrad[vi] * (CgGrad[vi] - CgGradPrev[vi])
    End

    If gg = 0
      ! Gradient is zero — we're at minimum
      CgStatus[h] = CG_DONE
      Return STAT_DONE
    End

    gamma = dgg / gg
    ! Restart if gamma is negative (ensures descent direction)
    If gamma < 0
      gamma = 0
    End

    ! Update direction: dir = -grad + gamma * dir_prev
    Loop idx = 1 To ndim
      vi = CgVecIdx(h, idx)
      CgGradPrev[vi] = CgGrad[vi]
      CgDirPrev[vi] = CgDir[vi]
      CgDir[vi] = -CgGrad[vi] + gamma * CgDirPrev[vi]
    End

    CgFxPrev[h] = CgFx[h]

    ! Start new line search
    CgStatus[h] = CG_LINE_SEARCH
    Loop idx = 1 To ndim
      vi = CgVecIdx(h, idx)
      CgLineOrig[vi] = CgX[vi]
      CgLineDir[vi] = CgDir[vi]
    End
    CgBrentH[h] = BrentCreate(CgTol[h])
    BrentSetBracket(CgBrentH[h], 0.0, 1.0)
    lambda = BrentGetEvalX(CgBrentH[h])
    Loop idx = 1 To ndim
      vi = CgVecIdx(h, idx)
      CgEvalX[vi] = CgLineOrig[vi] + lambda * CgLineDir[vi]
    End
    Return STAT_NEED_FEVAL

  Of CG_DONE
    Return STAT_DONE
  End

  Return STAT_ERROR

CGSetFValue Procedure(Long h, Real fval)
  Code
  If h < 1 Or h > MAX_CG Then Return -1.
  CgFx[h] = fval
  Return 0

CGSetGrad Procedure(Long h, Long idx, Real val)
  Code
  If h < 1 Or h > MAX_CG Then Return -1.
  If idx < 1 Or idx > CgNDim[h] Then Return -1.
  CgGrad[CgVecIdx(h, idx)] = val
  Return 0

CGGetEvalX Procedure(Long h, Long idx)
  Code
  If h < 1 Or h > MAX_CG Then Return 0.
  If idx < 1 Or idx > CgNDim[h] Then Return 0.
  Return CgEvalX[CgVecIdx(h, idx)]

CGGetResult Procedure(Long h, Long idx)
  Code
  If h < 1 Or h > MAX_CG Then Return 0.
  If idx < 1 Or idx > CgNDim[h] Then Return 0.
  Return CgX[CgVecIdx(h, idx)]

CGGetMinF Procedure(Long h)
  Code
  If h < 1 Or h > MAX_CG Then Return 0.
  Return CgFx[h]

CGGetIter Procedure(Long h)
  Code
  If h < 1 Or h > MAX_CG Then Return 0.
  Return CgIter[h]
