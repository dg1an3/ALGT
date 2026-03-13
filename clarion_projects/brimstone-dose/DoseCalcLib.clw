  MEMBER()

! ============================================================================
! DoseCalcLib - 2D Dose Calculation Engine
! Port of dH/Brimstone TERMA ray tracing + spherical kernel convolution
!
! Algorithm:
!   1. TERMA: trace rays from source through density grid,
!      computing exponential attenuation: TERMA = mu * rho * exp(-mu * path)
!   2. Convolution: for each dose point, integrate kernel energy weighted
!      by TERMA from neighboring voxels along all kernel directions
!
! Uses 2D collapsed superposition: the 3D spherical kernel is projected
! onto the XY plane using NUM_THETA=2 azimuthal samples.
!
! Beam geometry: source at (srcX, srcY), rays diverge through the grid.
! The grid uses (x,y) coordinates with y=0 at top, y increasing downward.
! Source is typically above the grid (srcY < 0).
!
! Reference: Mackie et al. 1985, Ahnesjo et al. 1989
! Port of dH/RtModel BeamDoseCalc + EnergyDepKernel
! ============================================================================

! --- Grid configuration ---
MAX_GRID        EQUATE(128)
MAX_GRID_SQ     EQUATE(16384)     ! 128*128

! --- Kernel configuration ---
MAX_KPHI        EQUATE(48)        ! max phi angles in kernel
MAX_INTERP      EQUATE(600)       ! interpolated kernel rows (1mm each)
NUM_THETA       EQUATE(2)         ! azimuthal samples
NUM_RAD_STEPS   EQUATE(64)        ! radial ray-trace steps

! --- Grid state ---
DcGridW         LONG(0)
DcGridH         LONG(0)
DcSpacing       REAL(0)           ! voxel size in mm
DcSpacingCm     REAL(0)           ! voxel size in cm

! Grid arrays (flat: y * MAX_GRID + x + 1)
DcDensity       REAL,DIM(MAX_GRID_SQ)
DcTerma         REAL,DIM(MAX_GRID_SQ)
DcDose          REAL,DIM(MAX_GRID_SQ)

! --- Kernel data (set via API from KernelLib) ---
DcNumPhi        LONG(0)
DcMu            REAL(0)           ! attenuation coefficient (cm^-1)
DcAngles        REAL,DIM(MAX_KPHI)
DcKernEnergy    REAL,DIM(MAX_KPHI * MAX_INTERP)  ! cumulative energy [phi][radMM]

! --- Radial LUT for convolution ---
! Pre-computed ray-trace geometry: for each (theta, phi, step),
! store the physical radius through the voxel and the (dx, dy) offset.
!
! Layout: flat arrays indexed by LutIdx(theta, phi, step)
! radius has one extra entry at step=0 (always 0)
MAX_LUT         EQUATE(6240)      ! 2 * 48 * 65
LutRadius       REAL,DIM(MAX_LUT)

MAX_LUT_OFF     EQUATE(12288)     ! 2 * 48 * 64 * 2
LutOffDx        LONG,DIM(6144)    ! 2 * 48 * 64
LutOffDy        LONG,DIM(6144)    ! 2 * 48 * 64

! --- Diagnostic ---
DcFluenceSurf   REAL(0)

! --- Constants ---
DC_PI           EQUATE(31416)     ! 3.1416 * 10000

  MAP
    DcInit(LONG gridW, LONG gridH, REAL spacing),LONG,C,NAME('DcInit'),EXPORT
    DcFree(),LONG,C,NAME('DcFree'),EXPORT
    DcSetDensity(LONG x, LONG y, REAL val),LONG,C,NAME('DcSetDensity'),EXPORT
    DcGetDensity(LONG x, LONG y),REAL,C,NAME('DcGetDensity'),EXPORT
    DcSetKernel(LONG numPhi, REAL mu),LONG,C,NAME('DcSetKernel'),EXPORT
    DcSetKernelAngle(LONG idx, REAL angle),LONG,C,NAME('DcSetKernelAngle'),EXPORT
    DcSetKernelEnergy(LONG phi, LONG radMM, REAL val),LONG,C,NAME('DcSetKernelEnergy'),EXPORT
    DcSetupLUT(),LONG,C,NAME('DcSetupLUT'),EXPORT
    DcCalcTerma(REAL srcX, REAL srcY, REAL beamMinX, REAL beamMaxX, LONG raysPerVoxel),LONG,C,NAME('DcCalcTerma'),EXPORT
    DcCalcDose(),LONG,C,NAME('DcCalcDose'),EXPORT
    DcGetTerma(LONG x, LONG y),REAL,C,NAME('DcGetTerma'),EXPORT
    DcGetDose(LONG x, LONG y),REAL,C,NAME('DcGetDose'),EXPORT
    DcGetMaxDose(),REAL,C,NAME('DcGetMaxDose'),EXPORT
    DcGetMaxTerma(),REAL,C,NAME('DcGetMaxTerma'),EXPORT
    DcGetFluenceSurf(),REAL,C,NAME('DcGetFluenceSurf'),EXPORT

    ! Internal helpers
    DcGridIdx(LONG x, LONG y),LONG
    DcKernIdx(LONG phi, LONG radMM),LONG
    DcLutRadIdx(LONG theta, LONG phi, LONG step),LONG
    DcLutOffIdx(LONG theta, LONG phi, LONG step),LONG
    DcLocalExp(REAL val),REAL
    DcLocalSin(REAL val),REAL
    DcLocalCos(REAL val),REAL
    DcLocalSqrt(REAL val),REAL
    DcLocalAbs(REAL val),REAL
    DcLocalFloor(REAL val),LONG
    DcLocalRound(REAL val),LONG
    DcTraceRay(REAL rayX, REAL rayY, REAL srcX, REAL srcY, REAL fluence0),LONG
  END

! ============================================================================
! Index helpers
! ============================================================================

DcGridIdx PROCEDURE(LONG x, LONG y)
  CODE
  RETURN y * MAX_GRID + x + 1

DcKernIdx PROCEDURE(LONG phi, LONG radMM)
  CODE
  RETURN (phi - 1) * MAX_INTERP + radMM

DcLutRadIdx PROCEDURE(LONG theta, LONG phi, LONG step)
  CODE
  ! step 0..64, phi 1..numPhi, theta 1..NUM_THETA
  RETURN (theta - 1) * MAX_KPHI * 65 + (phi - 1) * 65 + step + 1

DcLutOffIdx PROCEDURE(LONG theta, LONG phi, LONG step)
  CODE
  ! step 1..64, phi 1..numPhi, theta 1..NUM_THETA
  RETURN (theta - 1) * MAX_KPHI * NUM_RAD_STEPS + (phi - 1) * NUM_RAD_STEPS + step

! ============================================================================
! Math helpers (Clarion lacks exp, sin, cos, sqrt built-ins)
! ============================================================================

DcLocalExp PROCEDURE(REAL val)
Result REAL(1)
Term   REAL(1)
I      LONG
  CODE
  LOOP I = 1 TO 30
    Term *= val / I
    Result += Term
    IF ABS(Term) < 1.0e-15 THEN BREAK.
  END
  RETURN Result

DcLocalSin PROCEDURE(REAL val)
! Taylor series: sin(x) = x - x^3/3! + x^5/5! - ...
Result REAL
Term   REAL
I      LONG
x      REAL
  CODE
  ! Reduce to [-pi, pi]
  x = val
  LOOP WHILE x > 3.14159265358979
    x -= 6.28318530717959
  END
  LOOP WHILE x < -3.14159265358979
    x += 6.28318530717959
  END
  Result = x
  Term = x
  LOOP I = 1 TO 12
    Term *= -x * x / ((2 * I) * (2 * I + 1))
    Result += Term
  END
  RETURN Result

DcLocalCos PROCEDURE(REAL val)
  CODE
  RETURN DcLocalSin(val + 1.5707963267949)

DcLocalSqrt PROCEDURE(REAL val)
guess REAL
prev  REAL
I     LONG
  CODE
  IF val <= 0 THEN RETURN 0.
  guess = val
  IF guess > 1 THEN guess = guess / 2.
  LOOP I = 1 TO 50
    prev = guess
    guess = (guess + val / guess) / 2.0
    IF ABS(guess - prev) < 1.0e-12 * guess THEN BREAK.
  END
  RETURN guess

DcLocalAbs PROCEDURE(REAL val)
  CODE
  IF val < 0 THEN RETURN -val.
  RETURN val

DcLocalFloor PROCEDURE(REAL val)
  CODE
  IF val >= 0
    RETURN INT(val)
  ELSE
    IF INT(val) = val
      RETURN INT(val)
    END
    RETURN INT(val) - 1
  END

DcLocalRound PROCEDURE(REAL val)
  CODE
  IF val >= 0
    RETURN INT(val + 0.5)
  ELSE
    RETURN INT(val - 0.5)
  END

! ============================================================================
! DcInit: Initialize grid and clear arrays
! ============================================================================

DcInit PROCEDURE(LONG gridW, LONG gridH, REAL spacing)
I LONG
  CODE
  IF gridW < 1 OR gridW > MAX_GRID THEN RETURN -1.
  IF gridH < 1 OR gridH > MAX_GRID THEN RETURN -1.
  DcGridW = gridW
  DcGridH = gridH
  DcSpacing = spacing
  DcSpacingCm = spacing * 0.1  ! mm to cm
  ! Clear grids
  LOOP I = 1 TO MAX_GRID_SQ
    DcDensity[I] = 0
    DcTerma[I] = 0
    DcDose[I] = 0
  END
  DcFluenceSurf = 0
  RETURN 0

DcFree PROCEDURE()
  CODE
  DcGridW = 0
  DcGridH = 0
  RETURN 0

! ============================================================================
! Grid accessors
! ============================================================================

DcSetDensity PROCEDURE(LONG x, LONG y, REAL val)
  CODE
  IF x < 0 OR x >= DcGridW OR y < 0 OR y >= DcGridH THEN RETURN -1.
  DcDensity[DcGridIdx(x, y)] = val
  RETURN 0

DcGetDensity PROCEDURE(LONG x, LONG y)
  CODE
  IF x < 0 OR x >= DcGridW OR y < 0 OR y >= DcGridH THEN RETURN 0.
  RETURN DcDensity[DcGridIdx(x, y)]

DcGetTerma PROCEDURE(LONG x, LONG y)
  CODE
  IF x < 0 OR x >= DcGridW OR y < 0 OR y >= DcGridH THEN RETURN 0.
  RETURN DcTerma[DcGridIdx(x, y)]

DcGetDose PROCEDURE(LONG x, LONG y)
  CODE
  IF x < 0 OR x >= DcGridW OR y < 0 OR y >= DcGridH THEN RETURN 0.
  RETURN DcDose[DcGridIdx(x, y)]

DcGetMaxDose PROCEDURE()
mx    REAL(0)
I     LONG
  CODE
  LOOP I = 1 TO DcGridW * DcGridH
    IF DcDose[I] > mx THEN mx = DcDose[I].
  END
  RETURN mx

DcGetMaxTerma PROCEDURE()
mx    REAL(0)
I     LONG
  CODE
  LOOP I = 1 TO DcGridW * DcGridH
    IF DcTerma[I] > mx THEN mx = DcTerma[I].
  END
  RETURN mx

DcGetFluenceSurf PROCEDURE()
  CODE
  RETURN DcFluenceSurf

! ============================================================================
! Kernel setup (data passed in from KernelLib via Python)
! ============================================================================

DcSetKernel PROCEDURE(LONG numPhi, REAL mu)
  CODE
  IF numPhi < 1 OR numPhi > MAX_KPHI THEN RETURN -1.
  DcNumPhi = numPhi
  DcMu = mu
  RETURN 0

DcSetKernelAngle PROCEDURE(LONG idx, REAL angle)
  CODE
  IF idx < 1 OR idx > DcNumPhi THEN RETURN -1.
  DcAngles[idx] = angle
  RETURN 0

DcSetKernelEnergy PROCEDURE(LONG phi, LONG radMM, REAL val)
  CODE
  IF phi < 1 OR phi > DcNumPhi THEN RETURN -1.
  IF radMM < 1 OR radMM > MAX_INTERP THEN RETURN -1.
  DcKernEnergy[DcKernIdx(phi, radMM)] = val
  RETURN 0

! ============================================================================
! DcSetupLUT: Pre-compute radial lookup table for kernel convolution
! Port of CEnergyDepKernel::SetupRadialLUT (2D version)
!
! For each zenith angle phi and azimuthal angle theta, computes the
! sequence of voxel boundaries crossed by a ray in that direction.
! Stores physical radius and voxel offset at each crossing.
! ============================================================================

DcSetupLUT PROCEDURE()
nPhi      LONG
nTheta    LONG
sphi      REAL
cphi      REAL
sthet     REAL
cthet     REAL
thetaStep REAL
dirX      REAL
dirY      REAL
! Temporary arrays for boundary offsets per dimension
radX      REAL,DIM(NUM_RAD_STEPS)
radY      REAL,DIM(NUM_RAD_STEPS)
offXdx    LONG,DIM(NUM_RAD_STEPS)
offXdy    LONG,DIM(NUM_RAD_STEPS)
offYdx    LONG,DIM(NUM_RAD_STEPS)
offYdy    LONG,DIM(NUM_RAD_STEPS)
! Merge state
nX        LONG
nY        LONG
nN        LONG
lastRad   REAL
ridx      LONG
oidx      LONG
  CODE
  IF DcNumPhi = 0 THEN RETURN -1.
  IF DcSpacingCm <= 0 THEN RETURN -1.

  thetaStep = 6.28318530717959 / NUM_THETA  ! 2*pi / NUM_THETA

  LOOP nPhi = 1 TO DcNumPhi
    sphi = DcLocalSin(DcAngles[nPhi])
    cphi = DcLocalCos(DcAngles[nPhi])

    LOOP nTheta = 1 TO NUM_THETA
      sthet = DcLocalSin(nTheta * thetaStep)
      cthet = DcLocalCos(nTheta * thetaStep)

      ! Direction in voxel coordinates (normalized by pixel spacing in cm)
      ! In 2D: X corresponds to the beam-axis direction (cphi)
      !         Y corresponds to lateral (sphi * cthet)
      ! The kernel phi=0 is forward along beam axis
      dirX = cphi / DcSpacingCm
      dirY = sphi * cthet / DcSpacingCm

      ! Compute boundary offsets for X dimension (inlined)
      LOOP nN = 1 TO NUM_RAD_STEPS
        IF DcLocalAbs(dirX) >= 1.0e-4
          radX[nN] = DcLocalAbs(((nN - 1) + 0.5) / dirX)
        ELSE
          radX[nN] = 100000.0
        END
        offXdx[nN] = DcLocalRound(0.99 * radX[nN] * dirX)
        offXdy[nN] = DcLocalRound(radX[nN] * dirY)
      END
      ! Compute boundary offsets for Y dimension (inlined)
      LOOP nN = 1 TO NUM_RAD_STEPS
        IF DcLocalAbs(dirY) >= 1.0e-4
          radY[nN] = DcLocalAbs(((nN - 1) + 0.5) / dirY)
        ELSE
          radY[nN] = 100000.0
        END
        offYdx[nN] = DcLocalRound(radY[nN] * dirX)
        offYdy[nN] = DcLocalRound(0.99 * radY[nN] * dirY)
      END

      ! Merge the two sorted radius lists
      nX = 1
      nY = 1
      lastRad = 0

      ! Set step 0 radius = 0
      ridx = DcLutRadIdx(nTheta, nPhi, 0)
      LutRadius[ridx] = 0

      LOOP nN = 1 TO NUM_RAD_STEPS
        ridx = DcLutRadIdx(nTheta, nPhi, nN)
        oidx = DcLutOffIdx(nTheta, nPhi, nN)

        IF radX[nX] <= radY[nY]
          LutRadius[ridx] = radX[nX] - lastRad
          lastRad = radX[nX]
          LutOffDx[oidx] = offXdx[nX]
          LutOffDy[oidx] = offXdy[nX]
          nX += 1
          IF nX > NUM_RAD_STEPS THEN nX = NUM_RAD_STEPS.
        ELSE
          LutRadius[ridx] = radY[nY] - lastRad
          lastRad = radY[nY]
          LutOffDx[oidx] = offYdx[nY]
          LutOffDy[oidx] = offYdy[nY]
          nY += 1
          IF nY > NUM_RAD_STEPS THEN nY = NUM_RAD_STEPS.
        END
      END
    END
  END
  RETURN 0


! ============================================================================
! DcCalcTerma: Compute TERMA via ray tracing from source through density
! Port of CBeamDoseCalc::CalcTerma + TraceRayTerma
!
! Source at (srcX, srcY) in voxel coordinates.
! Beam aperture from beamMinX to beamMaxX at the top of the grid.
! raysPerVoxel controls sampling density (more rays = smoother).
! ============================================================================

DcCalcTerma PROCEDURE(REAL srcX, REAL srcY, REAL beamMinX, REAL beamMaxX, LONG raysPerVoxel)
deltaRay  REAL
fluence0  REAL
rayX      REAL
I         LONG
rc        LONG
  CODE
  ! Clear TERMA
  LOOP I = 1 TO MAX_GRID_SQ
    DcTerma[I] = 0
  END
  DcFluenceSurf = 0

  IF raysPerVoxel < 1 THEN raysPerVoxel = 1.

  deltaRay = 1.0 / raysPerVoxel
  ! Fluence per ray: proportional to voxel size and sampling density
  fluence0 = DcSpacing * deltaRay

  ! Trace rays across the beam aperture
  rayX = beamMinX
  LOOP WHILE rayX < beamMaxX
    rc = DcTraceRay(rayX, -0.5, srcX, srcY, fluence0)
    rayX += deltaRay
  END

  RETURN 0

! ============================================================================
! DcTraceRay: Trace single ray from entry point toward source
! Port of CBeamDoseCalc::TraceRayTerma
!
! Ray starts at (rayX, rayY) and goes in the direction away from source.
! The direction is computed from source to ray entry point.
! ============================================================================

DcTraceRay PROCEDURE(REAL rayX, REAL rayY, REAL srcX, REAL srcY, REAL fluence0)
dirX      REAL
dirY      REAL
dirLen    REAL
dirPhys   REAL
path      REAL
minDist   REAL
nx        LONG
ny        LONG
dVal      REAL
deltaPath REAL
fluenceInc REAL
eps       REAL(1.0e-6)
distX     REAL
distY     REAL
gidx      LONG
maxIter   LONG
  CODE
  ! Direction from source to entry point (normalized)
  dirX = rayX - srcX
  dirY = rayY - srcY
  dirLen = DcLocalSqrt(dirX * dirX + dirY * dirY)
  IF dirLen < 1.0e-10 THEN RETURN 0.
  dirX = dirX / dirLen
  dirY = dirY / dirLen

  ! Physical length of direction in cm
  dirPhys = DcLocalSqrt((dirX * DcSpacing) * (dirX * DcSpacing) |
                      + (dirY * DcSpacing) * (dirY * DcSpacing)) * 0.1

  path = 0
  DcFluenceSurf += fluence0

  ! Ray trace: step through voxels along the ray
  LOOP maxIter = 1 TO 1000
    ! Find current voxel
    IF dirX > 0
      nx = DcLocalFloor(rayX + 0.5 + eps)
      distX = (nx + 0.5 - rayX) / dirX
    ELSIF dirX < 0
      nx = DcLocalFloor(rayX + 0.5 + eps)
      distX = (nx - 0.5 - rayX) / dirX
    ELSE
      nx = DcLocalRound(rayX)
      distX = 100000.0
    END

    IF dirY > 0
      ny = DcLocalFloor(rayY + 0.5 + eps)
      distY = (ny + 0.5 - rayY) / dirY
    ELSIF dirY < 0
      ny = DcLocalFloor(rayY + 0.5 + eps)
      distY = (ny - 0.5 - rayY) / dirY
    ELSE
      ny = DcLocalRound(rayY)
      distY = 100000.0
    END

    ! Minimum distance to next boundary
    IF distX < distY
      minDist = distX
    ELSE
      minDist = distY
    END
    ! Enforce minimum step to avoid zero-distance stalls
    IF minDist < 1.0e-4 THEN minDist = 1.0e-4.

    ! Check bounds
    IF nx < 0 OR nx >= DcGridW THEN BREAK.
    IF ny < 0 OR ny >= DcGridH THEN BREAK.

    ! Get density at current voxel
    gidx = DcGridIdx(nx, ny)
    dVal = DcDensity[gidx]

    ! Compute path increment (radiological path in cm)
    deltaPath = dVal * minDist * dirPhys

    ! Update cumulative path
    path += deltaPath

    ! TERMA = fluence × mu × density × exp(-mu × path)
    IF dVal > 0.01
      fluenceInc = fluence0 * DcLocalExp(-DcMu * path) * DcMu * deltaPath
      DcTerma[gidx] += fluenceInc
    END

    ! Advance ray
    rayX += minDist * dirX
    rayY += minDist * dirY

    ! Safety: stop if we've gone too far
    IF path > 100 THEN BREAK.
  END

  ! Reduce by remaining fluence
  DcFluenceSurf -= fluence0 * DcLocalExp(-DcMu * path)
  RETURN 0

! ============================================================================
! DcCalcDose: Convolve TERMA with kernel to compute dose
! Port of CEnergyDepKernel::CalcSphereConvolve + CalcSphereTrace (2D)
!
! For each dose point, traces rays along all kernel directions (phi, theta),
! accumulates kernel energy weighted by TERMA from source voxels.
! ============================================================================

DcCalcDose PROCEDURE()
x         LONG
y         LONG
nTheta    LONG
nPhi      LONG
nRadial   LONG
radDist   REAL
prevE     REAL
totalE    REAL
energy    REAL
kx        LONG
ky        LONG
doseVal   REAL
maxDose   REAL
radMM     LONG
gidx      LONG
kidx      LONG
ridx      LONG
oidx      LONG
  CODE
  ! Clear dose
  LOOP I# = 1 TO MAX_GRID_SQ
    DcDose[I#] = 0
  END

  IF DcNumPhi = 0 THEN RETURN -1.

  ! For each voxel in the grid
  LOOP y = 0 TO DcGridH - 1
    LOOP x = 0 TO DcGridW - 1
      gidx = DcGridIdx(x, y)

      ! Only compute dose where density > threshold
      IF DcDensity[gidx] < 0.01 THEN CYCLE.

      doseVal = 0

      ! Loop over azimuthal angles
      LOOP nTheta = 1 TO NUM_THETA
        ! Loop over zenith angles
        LOOP nPhi = 1 TO DcNumPhi
          radDist = 0
          prevE = 0

          ! Trace along this kernel direction
          LOOP nRadial = 1 TO NUM_RAD_STEPS
            ! Get voxel offset from LUT
            oidx = DcLutOffIdx(nTheta, nPhi, nRadial)
            kx = x - LutOffDx[oidx]
            ky = y - LutOffDy[oidx]

            ! Check bounds
            IF kx < 0 OR kx >= DcGridW THEN BREAK.
            IF ky < 0 OR ky >= DcGridH THEN BREAK.

            ! Accumulate physical radius (in cm)
            ridx = DcLutRadIdx(nTheta, nPhi, nRadial)
            radDist += LutRadius[ridx]

            ! Stop after 4 cm radiological distance
            IF radDist > 4.0 THEN BREAK.

            ! Look up cumulative kernel energy at this radius
            radMM = DcLocalFloor(radDist * 10.0 + 0.5)
            IF radMM < 1 THEN radMM = 1.
            IF radMM > MAX_INTERP THEN radMM = MAX_INTERP.
            kidx = DcKernIdx(nPhi, radMM)
            totalE = DcKernEnergy[kidx]

            ! Energy deposited in this shell
            energy = totalE - prevE
            prevE = totalE

            ! Accumulate: dose += kernel_energy × TERMA(source)
            doseVal += energy * DcTerma[DcGridIdx(kx, ky)]
          END
        END
      END

      ! Average over azimuthal samples
      doseVal = doseVal / NUM_THETA

      ! Convert energy to dose by dividing by mass (density)
      IF DcDensity[gidx] > 0.25
        doseVal = doseVal / DcDensity[gidx]
      ELSE
        doseVal = 0
      END

      DcDose[gidx] = doseVal
    END
  END

  ! Normalize dose to max
  maxDose = 0
  LOOP I# = 1 TO DcGridW * DcGridH
    IF DcDose[I#] > maxDose THEN maxDose = DcDose[I#].
  END
  IF maxDose > 0
    LOOP I# = 1 TO DcGridW * DcGridH
      DcDose[I#] = DcDose[I#] / maxDose
    END
  END

  RETURN 0
