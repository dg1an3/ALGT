  member()

! ============================================================================
! PenBeamIndens - Photon Dose Calculation via Superposition/Convolution
! Port of dH/PenBeam_indens Fortran 77 code (Rock Mackie, UW-Madison, 1985-92)
!
! Implements the collapsed-cone convolution/superposition method for
! computing 3D photon dose distributions in heterogeneous media.
!
! The algorithm has three major phases:
!   1. Primary fluence calculation (PBCalcFluence)
!      - Traces rays from source through phantom
!      - Applies exponential attenuation (Beer-Lambert law)
!      - Accounts for beam divergence (inverse-square) and field boundaries
!
!   2. Kernel setup and ray-trace geometry (DoRayTraceSetup)
!      - Pre-computes voxel traversal paths for spherical dose spread
!      - Merges x,y,z plane crossings into sorted radial step list
!      - Builds cumulative energy deposition lookup tables
!
!   3. Superposition/convolution (PBCalcConvolve)
!      - For each voxel in ROI, traces rays through kernel angles
!      - Scales radiological depth by local density (heterogeneity correction)
!      - Accumulates dose from all directions using pre-computed kernels
!
! Fortran negative-index arrays (-63:63) mapped to 1-based with offset:
!   Fortran index i -> Clarion index i + HALF_W + 1
!   e.g. i=-32 -> idx=1, i=0 -> idx=33, i=32 -> idx=65
!
! Grid: HALF_W=32 (-32..32 = 65 pts x/y), MAX_DEPTH=64 (1..64 z)
! ============================================================================

! --- Grid configuration ---
! The computational grid spans -HALF_W..HALF_W in x,y and 1..MAX_DEPTH in z.
! GRID_W is the total number of grid points per lateral dimension.
! GRID_VOL is the total 3D volume size for flat-array allocation.
HALF_W        EQUATE(32)
GRID_W        EQUATE(65)       ! 2*HALF_W + 1
MAX_DEPTH     EQUATE(64)
GRID_VOL      EQUATE(270400)   ! GRID_W * GRID_W * MAX_DEPTH = 65*65*64

! --- Ray-trace configuration ---
! NUM_STEPS: max voxel boundary crossings per ray direction
! MAX_PHI/MAX_THET: zenith and azimuthal angular discretization
! These control the angular resolution of the dose spread kernel.
NUM_STEPS     equate(64)       ! Max radial steps per ray
MAX_PHI       equate(48)       ! Max zenith angles
MAX_THET      equate(48)       ! Max azimuthal angles
RT_SIZE       equate(147456)   ! NUM_STEPS * MAX_PHI * MAX_THET = 64*48*48
RAD_SIZE      equate(150528)   ! (NUM_STEPS+1) * MAX_PHI * MAX_THET = 65*48*48

! --- Accessory array (beam modifier / wedge / compensator) ---
! Models transmission through beam-modifying devices.
! Reduced from Fortran's 450 half-width to 100 to fit Clarion array limits.
ACC_HALF      Equate(100)
ACC_W         Equate(201)      ! 2*ACC_HALF + 1
ACC_SIZE      Equate(40401)    ! ACC_W * ACC_W

! --- Cumulative energy lookup ---
! Pre-computed lookup table for dose kernel energy at 1mm resolution
! out to 600mm (60cm) radial distance. Used during convolution to
! avoid repeated kernel interpolation.
CUM_RAD_MAX   EQUATE(600)
CUM_SIZE      EQUATE(28848)    ! MAX_PHI * (CUM_RAD_MAX+1) = 48*601

! --- Kernel data ---
! The polyenergetic kernel describes energy deposition as a function
! of zenith angle (phi) and radial distance from interaction site.
MAX_KERNEL_RAD equate(48)
KERN_SIZE     equate(2352)     ! MAX_PHI * (MAX_KERNEL_RAD+1) = 48*49

! --- 3D volumes (flat, 1-based) ---
! All volumes share the same indexing scheme via VIdx().
! density:    mass density in g/cm^3 (1.0 = water, 0.3 = lung, etc.)
! fluence:    primary photon fluence (energy per unit area)
! energyOut:  raw convolution result (energy deposited)
! energyOut2: dose after inverse-square and depth-hardening correction
! valueOut:   normalized dose (0..1 relative to dmax)
! norm:       ray count per voxel (for fluence averaging)
Vol:density   REAL,DIM(GRID_VOL)
Vol:fluence   REAL,DIM(GRID_VOL)
Vol:energyOut real,dim(GRID_VOL)
Vol:energyOut2 real,dim(GRID_VOL)
Vol:valueOut  REAL,DIM(GRID_VOL)
Vol:norm      long,DIM(GRID_VOL)

! --- Accessory (flat, mapped from -ACC_HALF..ACC_HALF) ---
! Each element is a transmission factor (0..1). Initialized to 1.0.
accessory     Real,Dim(ACC_SIZE)

! --- Ray-trace arrays (flat) ---
! Pre-computed voxel traversal data for spherical kernel rays.
! deltaI/J/K: integer voxel offsets at each step along a ray
! radius: fractional voxel distance for each step
Rt:deltaI     LONG,DIM(RT_SIZE)
Rt:deltaJ     long,DIM(RT_SIZE)
Rt:deltaK     LONG,dim(RT_SIZE)
Rt:radius     real,DIM(RAD_SIZE)

! --- Kernel data ---
! incEnergy: differential or cumulative energy for each (phi, radius) bin
! kernAng:   zenith angle values in radians for each phi index
! radBound:  radial boundary distances (cm) between kernel bins
Kern:incEnergy REAL,dim(KERN_SIZE)     ! inc_energy(phi, 0:numrad)
Kern:ang      Real,DIM(MAX_PHI)        ! zenith angles
Kern:radBound real,Dim(MAX_KERNEL_RAD + 1) ! radial boundaries (0:numrad)

! --- Cumulative energy lookup ---
! Pre-interpolated cumulative energy at 1mm steps for fast lookup.
cumEnergy     REAL,DIM(CUM_SIZE)       ! cum_energy(phi, 0:600)

! --- Beam parameters ---
! Describes the photon beam geometry and attenuation properties.
Bm GROUP
energy        Real(6.0)        ! Nominal beam energy in MeV
thickness     REAL(30.0)       ! Phantom thickness (max depth) in cm
lengthX       real(0.5)        ! Voxel dimension in x (cm)
lengthY       Real(0.5)        ! Voxel dimension in y (cm)
lengthZ       REAL(0.5)        ! Voxel dimension in z (cm)
ssd           Real(100.0)      ! Source-to-surface distance in cm
xMin          real(-5.0)       ! Field boundary x minimum at surface (cm)
xMax          REAL(5.0)        ! Field boundary x maximum at surface (cm)
yMin          Real(-5.0)       ! Field boundary y minimum at surface (cm)
yMax          real(5.0)        ! Field boundary y maximum at surface (cm)
mu            REAL(0.0492)     ! Linear attenuation coefficient (cm^-1 in water)
ray           Real(1.0)        ! Rays per voxel for fluence sampling
mValue        real(0.0)        ! Depth hardening linear slope
bValue        REAL(1.0)        ! Depth hardening intercept
              END

! --- ROI (region of interest for convolution) ---
! Limits the expensive convolution loop to a subregion of the grid.
ROI GROUP
minI          LONG(0)
maxI          long(0)
minJ          Long(0)
maxJ          LONG(0)
minK          long(1)
maxK          Long(1)
              END

! --- Convolution state ---
! Kernel angular/radial discretization parameters and dose tracking.
Conv GROUP
numPhi        long(0)          ! Number of zenith angles in kernel
numRad        Long(0)          ! Number of radial bins in kernel
numThet       LONG(8)          ! Number of azimuthal angles (default 8)
depthNum      long(0)          ! Actual depth voxels = thickness / lengthZ
kernDens      Real(1.0)        ! Reference density for kernel scaling (g/cm^3)
dmaxI         Long(0)          ! i-index of dose maximum
dmaxJ         long(0)          ! j-index of dose maximum
dmaxK         LONG(0)          ! k-index of dose maximum
doseMax       real(0)          ! Maximum dose value found
              END

! --- State ---
initialized   long(0)

  MAP
    ! --- Setup procedures ---
    PBInit(REAL energy, REAL thickness, REAL lx, REAL ly, REAL lz, |
           REAL ssd, REAL xmin, REAL xmax, REAL ymin, REAL ymax, |
           REAL mu, REAL ray),LONG,C,NAME('PBInit'),EXPORT
    PBSetROI(REAL xminR, REAL xmaxR, REAL yminR, REAL ymaxR, |
             REAL zminR, REAL zmaxR),LONG,C,NAME('PBSetROI'),EXPORT
    PBClose(),LONG,C,NAME('PBClose'),EXPORT

    ! --- Density configuration ---
    ! PBSetDensityHomogeneous: fills entire phantom with uniform density
    ! PBSetDensityCylinder: cylindrical insert (e.g. bone/lung) in surrounding medium
    ! PBSetDensityVoxel/PBGetDensityVoxel: per-voxel density access
    PBSetDensityHomogeneous(REAL dens),LONG,C,NAME('PBSetDensityHomogeneous'),EXPORT
    PBSetDensityCylinder(REAL cylRadius, REAL cylLength, |
                         REAL xOffset, REAL zOffset, |
                         REAL cylDens, REAL surroundDens),LONG,C,NAME('PBSetDensityCylinder'),EXPORT
    PBSetDensityVoxel(LONG i, LONG j, LONG k, REAL val),LONG,C,NAME('PBSetDensityVoxel'),EXPORT
    PBGetDensityVoxel(LONG i, LONG j, LONG k),REAL,C,NAME('PBGetDensityVoxel'),EXPORT

    ! --- Calculation ---
    ! PBCalcFluence: primary fluence with exponential attenuation
    ! PBCalcConvolve: full superposition using dose kernels
    PBCalcFluence(),LONG,C,NAME('PBCalcFluence'),EXPORT
    PBSetKernelPoint(LONG phi, LONG rad, REAL val),LONG,C,NAME('PBSetKernelPoint'),EXPORT
    PBSetKernelAngle(LONG phi, REAL angle),LONG,C,NAME('PBSetKernelAngle'),EXPORT
    PBSetKernelRadBound(LONG rad, REAL bound),LONG,C,NAME('PBSetKernelRadBound'),EXPORT
    PBSetKernelParams(LONG nPhi, LONG nRad, LONG nThet, REAL kDens),LONG,C,NAME('PBSetKernelParams'),EXPORT
    PBCalcConvolve(),LONG,C,NAME('PBCalcConvolve'),EXPORT

    ! --- Result accessors ---
    PBGetFluence(LONG i, LONG j, LONG k),REAL,C,NAME('PBGetFluence'),EXPORT
    PBGetDose(LONG i, LONG j, LONG k),REAL,C,NAME('PBGetDose'),EXPORT
    PBGetDoseMax(),REAL,C,NAME('PBGetDoseMax'),EXPORT
    PBGetDmaxI(),LONG,C,NAME('PBGetDmaxI'),EXPORT
    PBGetDmaxJ(),LONG,C,NAME('PBGetDmaxJ'),EXPORT
    PBGetDmaxK(),LONG,C,NAME('PBGetDmaxK'),EXPORT
    PBGetGridW(),LONG,C,NAME('PBGetGridW'),EXPORT
    PBGetHalfW(),LONG,C,NAME('PBGetHalfW'),EXPORT
    PBGetMaxDepth(),LONG,C,NAME('PBGetMaxDepth'),EXPORT
    PBGetDepthNum(),LONG,C,NAME('PBGetDepthNum'),EXPORT

    ! --- Internal helpers (not exported) ---
    ! VIdx: maps (i,j,k) with negative indices to flat 1-based array position
    ! AccIdx: maps accessory (i,j) to flat index
    ! RtIdx/RadIdx: map ray-trace (radInc,phi,thet) to flat indices
    ! CumIdx/KernIdx: map kernel data to flat indices
    VIdx(LONG i, LONG j, LONG k),LONG
    AccIdx(LONG i, LONG j),LONG
    RtIdx(LONG radInc, LONG phi, LONG thet),LONG
    RadIdx(LONG radInc, LONG phi, LONG thet),LONG
    CumIdx(LONG phi, LONG radStep),LONG
    KernIdx(LONG phi, LONG rad),LONG
    DoMakeVector(LONG numStep, REAL factor1, REAL factor2, REAL factor3, |
                 LONG rIdx, LONG d1Idx, LONG d2Idx, LONG d3Idx)
    DoRayTraceSetup()
    DoEnergyLookup(LONG phi)
    DoInterpEnergy(REAL bound1, REAL bound2, LONG radNumb, LONG phiNumb),REAL
    LocalExp(REAL val),REAL
    LocalNint(REAL val),LONG
  END

! === Temp arrays for make_vector ===
! Used by DoMakeVector to store plane-crossing distances and voxel offsets
! before they are merged into the main ray-trace arrays.
Mv:r          REAL,dim(NUM_STEPS)
Mv:d1         long,Dim(NUM_STEPS)
Mv:d2         LONG,DIM(NUM_STEPS)
Mv:d3         Long,dim(NUM_STEPS)

! ============================================================================
! Index helpers
! These convert multi-dimensional coordinates into flat 1-based array indices.
! ============================================================================

VIdx procedure(LONG i, LONG j, LONG k)
  code
  ! Maps Fortran (-HALF_W:HALF_W, -HALF_W:HALF_W, 1:MAX_DEPTH) to 1-based.
  ! The offset HALF_W shifts negative indices into positive range.
  ! k is already 1-based (depth), i and j need the shift.
  RETURN (k - 1) * GRID_W * GRID_W + (j + HALF_W) * GRID_W + (i + HALF_W) + 1

AccIdx PROCEDURE(long i, long j)
  CODE
  ! Maps accessory array from (-ACC_HALF..ACC_HALF) to 1-based
  return (j + ACC_HALF) * ACC_W + (i + ACC_HALF) + 1

RtIdx procedure(Long radInc, Long phi, Long thet)
  Code
  ! Ray-trace delta index: (thet,phi,radInc) -> flat
  Return (thet - 1) * MAX_PHI * NUM_STEPS + (phi - 1) * NUM_STEPS + radInc

RadIdx Procedure(LONG radInc, LONG phi, LONG thet)
  code
  ! Radius array index. radInc is 0-based here (0..NUM_STEPS)
  ! so we add 1 for Clarion's 1-based arrays.
  RETURN (thet - 1) * MAX_PHI * (NUM_STEPS + 1) + (phi - 1) * (NUM_STEPS + 1) + radInc + 1

CumIdx PROCEDURE(long phi, long radStep)
  Code
  ! Cumulative energy lookup index. radStep is 0-based (0..CUM_RAD_MAX)
  return (phi - 1) * (CUM_RAD_MAX + 1) + radStep + 1

KernIdx procedure(LONG phi, LONG rad)
  CODE
  ! Kernel data index. rad is 0-based (0..MAX_KERNEL_RAD)
  Return (phi - 1) * (MAX_KERNEL_RAD + 1) + rad + 1

! ============================================================================
! LocalExp - Taylor series approximation to exp(val)
! Used instead of Clarion's built-in for consistency with Fortran original.
! Converges to machine precision within ~20 terms for typical arguments.
! ============================================================================

LocalExp PROCEDURE(Real val)
result Real(1)
term   Real(1)
idx    long
  code
  LOOP idx = 1 TO 30
    term *= val / idx
    result += term
    if ABS(term) < 1.0e-15 then BREAK.
  end
  return result

! ============================================================================
! LocalNint - Nearest integer (Fortran NINT equivalent)
! Rounds to nearest integer, with 0.5 rounding away from zero.
! ============================================================================

LocalNint procedure(REAL val)
  CODE
  if val >= 0
    RETURN INT(val + 0.5)
  else
    return INT(val - 0.5)
  END

! ============================================================================
! PBInit - Initialize beam and phantom parameters
! Sets up beam geometry, clears all volume arrays, initializes accessory.
! Must be called before any density or fluence calculations.
! ============================================================================

PBInit Procedure(REAL energy, REAL thickness, REAL lx, REAL ly, REAL lz, |
                 Real ssd, Real xmin, Real xmax, Real ymin, Real ymax, |
                 REAL mu, REAL ray)
idx LONG
  Code
  ! Store beam geometry parameters
  Bm:energy = energy
  Bm:thickness = thickness
  Bm:lengthX = lx
  Bm:lengthY = ly
  Bm:lengthZ = lz
  Bm:ssd = ssd
  Bm:xMin = xmin
  Bm:xMax = xmax
  Bm:yMin = ymin
  Bm:yMax = ymax
  Bm:mu = mu
  Bm:ray = ray
  Bm:mValue = 0
  Bm:bValue = 1
  ! Calculate number of depth voxels from phantom thickness and voxel size
  Conv:depthNum = LocalNint(thickness / lz)
  IF Conv:depthNum > MAX_DEPTH THEN Conv:depthNum = MAX_DEPTH.
  ! Zero all volume arrays to prepare for new calculation
  loop idx = 1 TO GRID_VOL
    Vol:density[idx] = 0
    Vol:fluence[idx] = 0
    Vol:energyOut[idx] = 0
    Vol:energyOut2[idx] = 0
    Vol:valueOut[idx] = 0
    Vol:norm[idx] = 0
  END
  ! Initialize beam modifier (accessory) to full transmission
  LOOP idx = 1 to ACC_SIZE
    accessory[idx] = 1.0
  end
  initialized = 1
  RETURN 0

! ============================================================================
! PBSetROI - Set region of interest for convolution
! Converts physical coordinates (cm) to grid indices.
! Only voxels within the ROI will be processed during PBCalcConvolve.
! ============================================================================

PBSetROI Procedure(real xminR, real xmaxR, real yminR, real ymaxR, |
                   REAL zminR, REAL zmaxR)
  code
  ROI:minI = LocalNint(xminR / Bm:lengthX)
  ROI:maxI = LocalNint(xmaxR / Bm:lengthX)
  ROI:minJ = LocalNint(yminR / Bm:lengthY)
  ROI:maxJ = LocalNint(ymaxR / Bm:lengthY)
  ROI:minK = LocalNint(zminR / Bm:lengthZ) + 1
  ROI:maxK = LocalNint(zmaxR / Bm:lengthZ)
  return 0

PBClose PROCEDURE()
  code
  initialized = 0
  RETURN 0

! ============================================================================
! Density setup
! These procedures configure the mass density distribution in the phantom.
! Density is specified in g/cm^3 (water=1.0, lung~0.3, bone~1.8).
! ============================================================================

PBSetDensityHomogeneous procedure(Real dens)
i   long
j   LONG
k   Long
idx long
  CODE
  ! Fill all voxels within the current depth range with uniform density
  Loop k = 1 to Conv:depthNum
    loop j = -HALF_W TO HALF_W
      LOOP i = -HALF_W to HALF_W
        idx = VIdx(i, j, k)
        Vol:density[idx] = dens
      end
    END
  end
  Return 0

! PBSetDensityCylinder - Create cylindrical density insert
! Used for heterogeneity testing (e.g. bone cylinder in lung).
! The cylinder axis is parallel to the y-axis.
! cylRadius: radius of cylinder (cm)
! cylLength: length along y-axis (cm)
! xOffset, zOffset: center position of cylinder cross-section
! cylDens: density inside cylinder
! surroundDens: density of surrounding medium
PBSetDensityCylinder PROCEDURE(real cylRadius, real cylLength, |
                               REAL xOffset, REAL zOffset, |
                               Real cylDens, Real surroundDens)
i      LONG
j      long
k      Long
idx    LONG
dist   real
  code
  ! For each voxel, compute distance from cylinder axis
  ! and assign density based on whether it's inside or outside
  LOOP k = 1 to MAX_DEPTH
    Loop j = -HALF_W TO HALF_W
      loop i = -HALF_W to HALF_W
        idx = VIdx(i, j, k)
        ! Distance from cylinder axis in the x-z plane
        dist = SQRT((i * Bm:lengthX - xOffset) * (i * Bm:lengthX - xOffset) + |
                     (k * Bm:lengthZ - zOffset) * (k * Bm:lengthZ - zOffset))
        IF dist < cylRadius AND ABS(j * Bm:lengthY) < cylLength / 2.0
          Vol:density[idx] = cylDens
        else
          Vol:density[idx] = surroundDens
        END
      end
    End
  END
  return 0

PBSetDensityVoxel Procedure(Long i, Long j, Long k, Real val)
idx LONG
  code
  ! Bounds check: reject indices outside grid
  if i < -HALF_W OR i > HALF_W THEN return -1.
  IF j < -HALF_W or j > HALF_W then RETURN -1.
  if k < 1 OR k > MAX_DEPTH then return -1.
  idx = VIdx(i, j, k)
  Vol:density[idx] = val
  RETURN 0

PBGetDensityVoxel PROCEDURE(long i, long j, long k)
  Code
  IF i < -HALF_W or i > HALF_W THEN return 0.
  if j < -HALF_W OR j > HALF_W then RETURN 0.
  IF k < 1 or k > MAX_DEPTH THEN return 0.
  RETURN Vol:density[VIdx(i, j, k)]

! ============================================================================
! Fluence calculation (port of div_fluence_calc.for)
!
! Computes primary photon fluence by tracing rays from the source
! through the phantom. Each ray starts at the source position and
! propagates along a divergent path through the voxel grid.
!
! Physics modeled:
!   - Exponential attenuation: I = I0 * exp(-mu * radiological_path)
!   - Beam divergence: rays fan out from source (inverse-square built in)
!   - Field boundaries: partial voxel weighting at field edges
!   - Accessory transmission: beam modifier (wedge, compensator)
!   - Density-dependent path: uses local density for radiological depth
!
! After tracing all rays, fluence is normalized by the number of rays
! passing through each voxel (stored in Vol:norm).
! ============================================================================

PBCalcFluence PROCEDURE()
i           long
j           LONG
k           Long
idx         LONG
smallFieldI long
largeFieldI Long
smallFieldJ LONG
largeFieldJ long
iNear       Long
jNear       LONG
! Geometric variables for ray tracing
mindDepth   real        ! Distance from source to first voxel center
xInc        REAL        ! Lateral ray spacing in x
yInc        Real        ! Lateral ray spacing in y
fieldX0     real        ! Initial x-position at first depth
fieldY0     REAL        ! Initial y-position at first depth
lenSquare   Real        ! Squared distance from source to voxel
len0        real        ! Distance from source to first voxel center
lenInc      REAL        ! Path length increment per depth step
distance    Real        ! Running distance along ray
! Attenuation tracking
path        real        ! Cumulative radiological path length
pathInc     REAL        ! Path increment for current voxel
lastPathInc Real        ! Path increment from previous voxel
deltaPath   real        ! Total path increment (current + previous half)
atten       REAL        ! Running attenuation factor exp(-mu*path)
! Field boundary weighting
latScale    Real        ! Lateral scale factor for divergence
fieldX      real        ! Projected x-position at current depth
fieldY      REAL        ! Projected y-position at current depth
weightX     Real        ! Fractional weight for x field boundary
weightY     real        ! Fractional weight for y field boundary
divScale    REAL        ! Divergence scale for field boundary projection
minFieldX   Real        ! Diverged field x minimum at current depth
maxFieldX   real        ! Diverged field x maximum at current depth
minFieldY   REAL        ! Diverged field y minimum at current depth
maxFieldY   Real        ! Diverged field y maximum at current depth
! Fluence accumulation
fluInc      real        ! Current fluence increment
oldFluInc   REAL        ! Previous fluence increment (unused, kept for compat)
incFlu      Real        ! Incident fluence from accessory
! Normalization bounds
bottomScale real
xBotMin     REAL
xBotMax     Real
yBotMin     real
yBotMax     REAL
iMin        Long
iMax        LONG
jMin        long
jMax        Long
  CODE
  if initialized = 0 THEN return -1.

  ! Distance from source to center of first voxel layer
  mindDepth = Bm:ssd + 0.5 * Bm:lengthZ
  ! Ray spacing: divide voxel size by rays-per-voxel
  xInc = Bm:lengthX / Bm:ray
  yInc = Bm:lengthY / Bm:ray

  ! Convert field boundaries to ray indices
  smallFieldI = LocalNint(Bm:xMin / xInc)
  largeFieldI = LocalNint(Bm:xMax / xInc)
  smallFieldJ = LocalNint(Bm:yMin / yInc)
  largeFieldJ = LocalNint(Bm:yMax / yInc)

  ! Ray-trace loop: trace one ray per sub-voxel position in the field
  LOOP i = smallFieldI to largeFieldI
    loop j = smallFieldJ TO largeFieldJ
      ! Get beam modifier (accessory/wedge) transmission at this ray position
      IF i >= -ACC_HALF and i <= ACC_HALF AND j >= -ACC_HALF and j <= ACC_HALF
        incFlu = accessory[AccIdx(i, j)]
      else
        incFlu = 1.0
      END

      ! Project ray position to first voxel depth (accounts for divergence)
      fieldX0 = i * xInc * mindDepth / Bm:ssd
      fieldY0 = j * yInc * mindDepth / Bm:ssd

      ! Compute initial distance from source to first voxel center
      lenSquare = fieldX0 * fieldX0 + fieldY0 * fieldY0 + mindDepth * mindDepth
      len0 = Sqrt(lenSquare)
      lenInc = len0 * Bm:lengthZ / mindDepth
      distance = len0

      ! Initialize attenuation tracking for this ray
      lastPathInc = 0.0
      path = 0.0
      atten = 1.0
      fluInc = 0
      oldFluInc = 0

      ! Trace through each depth voxel along this ray
      Loop k = 1 TO Conv:depthNum
        ! Lateral position expands with depth due to divergence
        latScale = 1.0 + (k - 1) * Bm:lengthZ / mindDepth
        fieldX = fieldX0 * latScale
        fieldY = fieldY0 * latScale

        ! Find nearest voxel to this ray position
        iNear = LocalNint(fieldX / Bm:lengthX)
        jNear = LocalNint(fieldY / Bm:lengthY)

        ! Skip if ray has diverged outside the grid
        IF iNear < -HALF_W or iNear > HALF_W then Cycle.
        if jNear < -HALF_W OR jNear > HALF_W THEN cycle.

        ! Compute radiological path increment using local density.
        ! Uses trapezoidal rule: average of current and previous half-steps.
        pathInc = 0.5 * lenInc * Vol:density[VIdx(iNear, jNear, k)]
        deltaPath = pathInc + lastPathInc
        path += deltaPath
        lastPathInc = pathInc

        ! Initialize boundary weights to 1.0 (fully inside field)
        weightX = 1.0
        weightY = 1.0

        ! Field boundary weighting with divergence correction.
        ! At each depth, the field edges are projected outward by the
        ! divergence factor. Voxels at the field edge get partial weight
        ! proportional to the fraction of the voxel inside the field.
        divScale = (Bm:ssd + (k - 0.5) * Bm:lengthZ) / Bm:ssd
        minFieldX = Bm:xMin * divScale
        maxFieldX = Bm:xMax * divScale
        minFieldY = Bm:yMin * divScale
        maxFieldY = Bm:yMax * divScale

        ! X boundary partial weighting
        if iNear = LocalNint(minFieldX / Bm:lengthX)
          weightX = iNear - minFieldX / Bm:lengthX + 0.5
        END
        IF iNear < LocalNint(minFieldX / Bm:lengthX) then weightX = 0.0.
        if iNear = LocalNint(maxFieldX / Bm:lengthX)
          weightX = maxFieldX / Bm:lengthX - 0.5 - (iNear - 1)
        end
        IF iNear > LocalNint(maxFieldX / Bm:lengthX) THEN weightX = 0.0.

        ! Y boundary partial weighting
        if jNear = LocalNint(minFieldY / Bm:lengthY)
          weightY = jNear - minFieldY / Bm:lengthY + 0.5
        END
        IF jNear < LocalNint(minFieldY / Bm:lengthY) then weightY = 0.0.
        if jNear = LocalNint(maxFieldY / Bm:lengthY)
          weightY = maxFieldY / Bm:lengthY - 0.5 - (jNear - 1)
        end
        IF jNear > LocalNint(maxFieldY / Bm:lengthY) THEN weightY = 0.0.

        ! Calculate and accumulate fluence at this voxel.
        ! Fluence = incident * attenuation * mu * boundary_weights
        ! The attenuation factor decreases exponentially with radiological path.
        idx = VIdx(iNear, jNear, k)
        IF Vol:density[idx] <> 0.0
          atten *= LocalExp(-Bm:mu * deltaPath)
          oldFluInc = fluInc
          fluInc = incFlu * atten * Bm:mu * weightX * weightY
          Vol:fluence[idx] += fluInc
          Vol:norm[idx] += 1
        ELSE
          ! Zero-density voxels (air cavities) get zero fluence
          Vol:fluence[idx] = 0.0
          Vol:norm[idx] = 1
        end

        distance += lenInc
      end
    END
  end

  ! Normalize fluence by dividing by the number of rays through each voxel.
  ! The normalization bounds account for field divergence at the phantom bottom.
  bottomScale = (Bm:ssd + Bm:thickness) / Bm:ssd
  if Bm:xMin > 0.0
    xBotMin = Bm:xMin
  ELSE
    xBotMin = Bm:xMin * bottomScale
  end
  IF Bm:xMax < 0.0
    xBotMax = Bm:xMax
  else
    xBotMax = Bm:xMax * bottomScale
  END
  if Bm:yMin > 0.0
    yBotMin = Bm:yMin
  ELSE
    yBotMin = Bm:yMin * bottomScale
  end
  IF Bm:yMax < 0.0
    yBotMax = Bm:yMax
  else
    yBotMax = Bm:yMax * bottomScale
  END

  iMin = LocalNint(xBotMin / Bm:lengthX)
  iMax = LocalNint(xBotMax / Bm:lengthX)
  jMin = LocalNint(yBotMin / Bm:lengthY)
  jMax = LocalNint(yBotMax / Bm:lengthY)

  loop i = iMin TO iMax
    IF i < -HALF_W or i > HALF_W THEN cycle.
    LOOP j = jMin to jMax
      if j < -HALF_W OR j > HALF_W then Cycle.
      Loop k = 1 TO Conv:depthNum
        idx = VIdx(i, j, k)
        IF Vol:norm[idx] <> 0
          Vol:fluence[idx] /= Vol:norm[idx]
        end
      END
    end
  END

  return 0

! ============================================================================
! Kernel data loading (called from Python to set kernel points)
! The kernel describes the dose spread around a photon interaction site.
! It is specified as energy deposited per unit fluence as a function of
! zenith angle (phi) and radial distance from the interaction point.
! ============================================================================

PBSetKernelParams PROCEDURE(long nPhi, long nRad, long nThet, real kDens)
  Code
  Conv:numPhi = nPhi
  Conv:numRad = nRad
  Conv:numThet = nThet
  Conv:kernDens = kDens
  return 0

PBSetKernelPoint procedure(LONG phi, LONG rad, REAL val)
idx long
  CODE
  if phi < 1 OR phi > MAX_PHI then return -1.
  IF rad < 0 or rad > MAX_KERNEL_RAD THEN RETURN -1.
  idx = KernIdx(phi, rad)
  Kern:incEnergy[idx] = val
  return 0

PBSetKernelAngle PROCEDURE(long phi, real angle)
  code
  IF phi < 1 or phi > MAX_PHI THEN return -1.
  Kern:ang[phi] = angle
  RETURN 0

PBSetKernelRadBound procedure(Long rad, Real bound)
  CODE
  if rad < 0 OR rad > MAX_KERNEL_RAD then return -1.
  Kern:radBound[rad + 1] = bound
  RETURN 0

! ============================================================================
! make_vector (port of make_vector.for)
! Computes plane-crossing distances and voxel index offsets for a ray
! in a given direction. The direction is specified by three factors
! (projections of the unit direction vector onto the voxel grid axes).
!
! For each step n, computes the distance at which the ray crosses
! the n-th plane perpendicular to the primary axis (factor1).
! Also computes the integer voxel offsets in all three dimensions.
! Results are stored in module-level Mv:r, Mv:d1, Mv:d2, Mv:d3 arrays.
! ============================================================================

DoMakeVector PROCEDURE(Long numStep, REAL factor1, REAL factor2, REAL factor3, |
                       long rIdx, long d1Idx, long d2Idx, long d3Idx)
idx  LONG
d    real
rVal Real
  code
  ! rIdx, d1Idx etc. are ignored — we use module-level Mv group arrays
  loop idx = 1 TO numStep
    ! d is the distance to the midpoint of voxel idx along the primary axis
    d = idx - 0.5
    IF factor1 < 0.0 then d = -d.
    ! Convert to radial distance by dividing by the direction cosine
    if ABS(factor1) >= 1.0e-4
      rVal = d / factor1
    ELSE
      ! Nearly perpendicular to this plane set — use large distance
      rVal = 100000.0
    end
    Mv:r[idx] = rVal
    ! Compute integer voxel offsets at this radial distance.
    ! The 0.99 factor avoids rounding to the next voxel at exact boundaries.
    Mv:d1[idx] = LocalNint(0.99 * rVal * factor1)
    Mv:d2[idx] = LocalNint(rVal * factor2)
    Mv:d3[idx] = LocalNint(rVal * factor3)
  END

! ============================================================================
! Ray-trace setup (port of ray_trace_set_up.for)
!
! Pre-computes the voxel traversal path for each (phi, theta) direction
! in the dose kernel. For each direction:
!   1. Compute plane-crossing distances for x, y, and z voxel planes
!   2. Merge the three crossing lists in order of increasing distance
!   3. Store the resulting voxel offsets (deltaI,J,K) and step distances
!
! This is called once before convolution and reused for every voxel.
! The merging step is the key algorithmic insight: by combining crossings
! from all three plane sets, we get an accurate voxel-by-voxel traversal
! that correctly handles oblique rays.
! ============================================================================

DoRayTraceSetup procedure()
phi       long
thet      LONG
sPhi      Real
cPhi      real
sThet     REAL
cThet     Real
pi        real(3.141593)
angInc    REAL
i         Long
j         long
k         LONG
n         Long
lastRad   real
! Temp arrays for x,y,z plane crossings before merging
rxArr     Real,DIM(NUM_STEPS)
ryArr     REAL,Dim(NUM_STEPS)
rzArr     real,DIM(NUM_STEPS)
diX       Long,DIM(NUM_STEPS)
djX       LONG,dim(NUM_STEPS)
dkX       long,Dim(NUM_STEPS)
diY       Long,DIM(NUM_STEPS)
djY       LONG,dim(NUM_STEPS)
dkY       long,Dim(NUM_STEPS)
diZ       Long,DIM(NUM_STEPS)
djZ       LONG,dim(NUM_STEPS)
dkZ       long,Dim(NUM_STEPS)
rtI       Long
  CODE
  ! Azimuthal angle increment: divide full circle equally
  angInc = 2.0 * pi / Conv:numThet

  loop phi = 1 TO Conv:numPhi
    ! Compute direction cosines for this zenith angle
    sPhi = SIN(Kern:ang[phi])
    cPhi = COS(Kern:ang[phi])

    LOOP thet = 1 to Conv:numThet
      ! Compute direction cosines for this azimuthal angle
      sThet = sin(thet * angInc)
      cThet = cos(thet * angInc)

      ! X-plane crossings: distances where ray crosses x-perpendicular planes
      DoMakeVector(NUM_STEPS, sPhi*cThet/Bm:lengthX, sPhi*sThet/Bm:lengthY, |
                   cPhi/Bm:lengthZ, 0, 0, 0, 0)
      Loop n = 1 TO NUM_STEPS
        rxArr[n] = Mv:r[n]
        diX[n] = Mv:d1[n]
        djX[n] = Mv:d2[n]
        dkX[n] = Mv:d3[n]
      end

      ! Y-plane crossings: note swapped factor order for y-primary axis
      DoMakeVector(NUM_STEPS, sPhi*sThet/Bm:lengthY, sPhi*cThet/Bm:lengthX, |
                   cPhi/Bm:lengthZ, 0, 0, 0, 0)
      LOOP n = 1 to NUM_STEPS
        ryArr[n] = Mv:r[n]
        djY[n] = Mv:d1[n]
        diY[n] = Mv:d2[n]
        dkY[n] = Mv:d3[n]
      END

      ! Z-plane crossings: z-primary axis
      DoMakeVector(NUM_STEPS, cPhi/Bm:lengthZ, sPhi*sThet/Bm:lengthY, |
                   sPhi*cThet/Bm:lengthX, 0, 0, 0, 0)
      loop n = 1 TO NUM_STEPS
        rzArr[n] = Mv:r[n]
        dkZ[n] = Mv:d1[n]
        djZ[n] = Mv:d2[n]
        diZ[n] = Mv:d3[n]
      end

      ! Initialize radius at step 0 to zero
      Rt:radius[RadIdx(0, phi, thet)] = 0.0
      i = 1
      j = 1
      k = 1
      lastRad = 0.0

      ! Merge three crossing lists by selecting the nearest crossing.
      ! At each step, pick whichever plane set has the smallest distance.
      ! This produces an ordered sequence of voxel boundary crossings.
      Loop n = 1 TO NUM_STEPS
        rtI = RtIdx(n, phi, thet)
        IF rxArr[i] <= ryArr[j] and rxArr[i] <= rzArr[k]
          ! X-plane crossing is nearest
          Rt:radius[RadIdx(n, phi, thet)] = rxArr[i] - lastRad
          Rt:deltaI[rtI] = diX[i]
          Rt:deltaJ[rtI] = djX[i]
          Rt:deltaK[rtI] = dkX[i]
          lastRad = rxArr[i]
          i += 1
          if i > NUM_STEPS THEN i = NUM_STEPS.
        ELSIF ryArr[j] <= rxArr[i] and ryArr[j] <= rzArr[k]
          ! Y-plane crossing is nearest
          Rt:radius[RadIdx(n, phi, thet)] = ryArr[j] - lastRad
          Rt:deltaI[rtI] = diY[j]
          Rt:deltaJ[rtI] = djY[j]
          Rt:deltaK[rtI] = dkY[j]
          lastRad = ryArr[j]
          j += 1
          IF j > NUM_STEPS then j = NUM_STEPS.
        else
          ! Z-plane crossing is nearest
          Rt:radius[RadIdx(n, phi, thet)] = rzArr[k] - lastRad
          Rt:deltaI[rtI] = diZ[k]
          Rt:deltaJ[rtI] = djZ[k]
          Rt:deltaK[rtI] = dkZ[k]
          lastRad = rzArr[k]
          k += 1
          if k > NUM_STEPS THEN k = NUM_STEPS.
        END
      end
    End
  END

! ============================================================================
! Energy lookup (port of energy_lookup.for + interp_energy.for)
!
! DoInterpEnergy: linearly interpolates the kernel energy between
! radial bin boundaries. Used to evaluate kernel at arbitrary distances.
!
! DoEnergyLookup: builds a cumulative energy lookup table at 1mm
! resolution (0..600mm). This pre-computation trades memory for speed
! during the main convolution loop.
! ============================================================================

DoInterpEnergy Procedure(Real bound1, Real bound2, Long radNumb, Long phiNumb)
e1  real
e2  REAL
rb1 Real
rb2 real
  CODE
  ! Get cumulative energy at adjacent radial boundaries
  e1 = Kern:incEnergy[KernIdx(phiNumb, radNumb - 1)]
  e2 = Kern:incEnergy[KernIdx(phiNumb, radNumb)]
  ! Get the actual radial distances at those boundaries
  rb1 = Kern:radBound[radNumb]      ! radNumb-1 in 0-based -> radNumb in 1-based
  rb2 = Kern:radBound[radNumb + 1]  ! radNumb in 0-based -> radNumb+1 in 1-based
  ! Avoid division by zero if boundaries coincide
  if rb2 = rb1 THEN return e1.
  ! Linear interpolation between the two boundary values
  Return e1 + (e2 - e1) * (bound2 - rb1) / (rb2 - rb1)

DoEnergyLookup PROCEDURE(long phi)
i       LONG
r       long
radNumb Long
lastRad REAL
radDist real
totE    Real
  code
  radNumb = 1
  lastRad = 0.0
  ! cumEnergy(phi, 0) = 0: no energy deposited at zero distance
  cumEnergy[CumIdx(phi, 0)] = 0.0

  ! Build lookup table at 1mm intervals from 0.1 to 59.9 cm
  LOOP i = 1 to 599
    radDist = i * 0.1
    ! Advance through kernel radial bins until we find the containing bin
    loop r = radNumb - 1 TO Conv:numRad
      IF Kern:radBound[r + 1] > radDist then Break.
    END
    radNumb = r
    ! Interpolate cumulative energy at this distance
    totE = DoInterpEnergy(lastRad, radDist, radNumb, phi)
    lastRad = radDist
    cumEnergy[CumIdx(phi, i)] = totE
  end

! ============================================================================
! Convolution/Superposition (port of new_sphere_convolve.for)
!
! This is the core dose calculation: for each voxel in the ROI,
! it traces rays in all kernel directions, accumulates the dose
! contribution from fluence at upstream voxels, and corrects for
! density heterogeneity and beam divergence.
!
! The key formula is:
!   dose(r) = sum_over_rays[ fluence(r') * kernel_energy(|r-r'|) ]
! where r' are the voxels along each ray direction and kernel_energy
! is looked up from the pre-computed cumulative table.
!
! The density ratio (local density / kernel reference density) scales
! the radiological distance, providing first-order heterogeneity correction.
!
! After superposition, the dose is corrected for:
!   - Inverse-square divergence: (SSD / distance)^2
!   - Depth hardening: linear correction factor m*depth + b
!   - Normalization to dose maximum (output in 0..1 range)
! ============================================================================

PBCalcConvolve procedure()
i          long
j          LONG
k          Long
phi        long
thet       LONG
radInc     Long
delI       LONG
delJ       long
delK       Long
idx        long
fIdx       LONG
pathInc    Real
radDist    real
deltaRad   REAL
lastRad    Real
totEnergy  real
lastEnergy REAL
energy     Real
newDist    real
depthDist  REAL
cFactor    Real
a          long
  CODE
  if initialized = 0 THEN return -1.

  ! Convert kernel from differential to cumulative energy form.
  ! After this loop, incEnergy[phi,rad] = sum of energy from 0 to rad.
  loop a = 1 TO Conv:numPhi
    Kern:incEnergy[KernIdx(a, 0)] = 0.0
    LOOP radInc = 1 to Conv:numRad
      Kern:incEnergy[KernIdx(a, radInc)] += Kern:incEnergy[KernIdx(a, radInc - 1)]
    end
  END

  ! Pre-compute voxel traversal paths for all kernel directions
  DoRayTraceSetup()

  ! Pre-compute cumulative energy lookup tables for each zenith angle
  LOOP a = 1 to Conv:numPhi
    DoEnergyLookup(a)
  end

  ! === Main convolution loops ===
  ! Outer loops: iterate over each voxel in the ROI
  ! Inner loops: for each voxel, trace rays in all (thet,phi) directions
  loop k = ROI:minK TO ROI:maxK
    IF k < 1 or k > Conv:depthNum THEN cycle.
    LOOP j = ROI:minJ to ROI:maxJ
      if j < -HALF_W OR j > HALF_W then Cycle.
      Loop i = ROI:minI TO ROI:maxI
        IF i < -HALF_W or i > HALF_W THEN cycle.
        idx = VIdx(i, j, k)
        ! Skip air voxels (zero density = no dose deposition)
        if Vol:density[idx] = 0.0 THEN Cycle.

        ! Trace rays in all azimuthal and zenith directions
        loop thet = 1 TO Conv:numThet
          LOOP phi = 1 to Conv:numPhi
            lastRad = 0.0
            radDist = 0.0
            lastEnergy = 0.0

            ! Follow pre-computed ray path, stepping through voxels
            Loop radInc = 1 TO NUM_STEPS
              ! Get voxel offset for this step along this ray
              delI = Rt:deltaI[RtIdx(radInc, phi, thet)]
              delJ = Rt:deltaJ[RtIdx(radInc, phi, thet)]
              delK = Rt:deltaK[RtIdx(radInc, phi, thet)]

              ! Check if ray has exited the grid volume
              IF k - delK < 1 or k - delK > Conv:depthNum THEN break.
              if i - delI > HALF_W OR i - delI < -HALF_W then Break.
              IF j - delJ > HALF_W or j - delJ < -HALF_W THEN break.

              ! Scale step distance by local density ratio.
              ! This is the heterogeneity correction: in dense media,
              ! the effective radiological distance is larger.
              pathInc = Rt:radius[RadIdx(radInc, phi, thet)]
              fIdx = VIdx(i - delI, j - delJ, k - delK)
              deltaRad = pathInc * Vol:density[fIdx] / Conv:kernDens
              radDist += deltaRad

              ! Stop tracing when beyond kernel range (60 cm)
              if radDist >= 60 THEN break.

              ! Look up cumulative kernel energy at this radiological distance
              totEnergy = cumEnergy[CumIdx(phi, LocalNint(radDist * 10.0))]
              ! Incremental energy = difference from last step
              energy = totEnergy - lastEnergy
              lastEnergy = totEnergy

              ! Accumulate dose: energy from kernel * fluence at source voxel
              Vol:energyOut[idx] += energy * Vol:fluence[fIdx]
            END
          end
        END
      end
    END
  end

  ! === Post-processing: convert raw energy to calibrated dose ===
  ! Apply inverse-square divergence correction and depth hardening.
  Conv:doseMax = 0.0
  LOOP k = ROI:minK to ROI:maxK
    if k < 1 OR k > Conv:depthNum then Cycle.
    Loop j = ROI:minJ TO ROI:maxJ
      IF j < -HALF_W or j > HALF_W THEN cycle.
      LOOP i = ROI:minI to ROI:maxI
        if i < -HALF_W OR i > HALF_W then Cycle.
        idx = VIdx(i, j, k)

        ! Distance from source to this voxel (for inverse-square)
        newDist = SQRT((Bm:ssd + k * Bm:lengthZ - 0.5) * (Bm:ssd + k * Bm:lengthZ - 0.5) + |
                       (j * Bm:lengthY) * (j * Bm:lengthY) + |
                       (i * Bm:lengthX) * (i * Bm:lengthX))
        ! Distance from surface to this voxel (for depth hardening)
        depthDist = Sqrt((k * Bm:lengthZ - 0.5) * (k * Bm:lengthZ - 0.5) + |
                         (j * Bm:lengthY) * (j * Bm:lengthY) + |
                         (i * Bm:lengthX) * (i * Bm:lengthX))

        ! Depth hardening correction: compensates for beam spectral changes
        ! with depth. mValue=0, bValue=1 gives no correction (default).
        cFactor = Bm:mValue * depthDist + Bm:bValue

        ! Final dose = energy * unit_conversion * inverse_square * hardening
        ! 1.602e-10 converts MeV/g to Gy (SI dose units)
        Vol:energyOut2[idx] = (Vol:energyOut[idx] * 1.602e-10 / Conv:numThet) * |
                          (Bm:ssd / newDist) * (Bm:ssd / newDist) * cFactor

        ! Track dose maximum location for normalization
        if Vol:energyOut2[idx] > Conv:doseMax
          Conv:doseMax = Vol:energyOut2[idx]
          Conv:dmaxI = i
          Conv:dmaxJ = j
          Conv:dmaxK = k
        END
      end
    END
  end

  ! Normalize all dose values to dmax (output range 0..1)
  IF Conv:doseMax > 0.0
    loop k = ROI:minK TO ROI:maxK
      if k < 1 OR k > Conv:depthNum then Cycle.
      Loop j = ROI:minJ TO ROI:maxJ
        IF j < -HALF_W or j > HALF_W THEN cycle.
        LOOP i = ROI:minI to ROI:maxI
          if i < -HALF_W OR i > HALF_W then Cycle.
          idx = VIdx(i, j, k)
          Vol:valueOut[idx] = Vol:energyOut2[idx] / Conv:doseMax
        END
      end
    END
  end

  Return 0

! ============================================================================
! Result accessors
! These provide read-only access to computed results from Python/ctypes.
! ============================================================================

PBGetFluence PROCEDURE(long i, long j, long k)
  code
  IF i < -HALF_W or i > HALF_W THEN return 0.
  if j < -HALF_W OR j > HALF_W then RETURN 0.
  IF k < 1 or k > MAX_DEPTH THEN return 0.
  RETURN Vol:fluence[VIdx(i, j, k)]

PBGetDose procedure(LONG i, LONG j, LONG k)
  CODE
  if i < -HALF_W OR i > HALF_W then return 0.
  IF j < -HALF_W or j > HALF_W THEN RETURN 0.
  if k < 1 OR k > MAX_DEPTH then return 0.
  Return Vol:valueOut[VIdx(i, j, k)]

PBGetDoseMax PROCEDURE()
  code
  return Conv:doseMax

PBGetDmaxI procedure()
  CODE
  Return Conv:dmaxI

PBGetDmaxJ PROCEDURE()
  code
  return Conv:dmaxJ

PBGetDmaxK procedure()
  CODE
  Return Conv:dmaxK

PBGetGridW PROCEDURE()
  code
  return GRID_W

PBGetHalfW procedure()
  CODE
  Return HALF_W

PBGetMaxDepth PROCEDURE()
  code
  return MAX_DEPTH

PBGetDepthNum procedure()
  CODE
  Return Conv:depthNum
