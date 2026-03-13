"""Tests for DoseCalcLib - 2D dose calculation engine.

Tests TERMA ray tracing and spherical kernel convolution using
kernel data loaded from KernelLib.
"""
import ctypes
import os
import sys


def main():
    bin_dir = os.path.join(os.path.dirname(__file__), "bin")
    dose_path = os.path.join(bin_dir, "DoseCalcLib.dll")
    kern_path = os.path.join(os.path.dirname(__file__), "..", "brimstone-kernel", "bin", "KernelLib.dll")

    if not os.path.exists(dose_path):
        print(f"DoseCalcLib.dll not found: {dose_path}")
        return 1
    if not os.path.exists(kern_path):
        print(f"KernelLib.dll not found: {kern_path}")
        return 1

    kern = ctypes.CDLL(kern_path)
    dose = ctypes.CDLL(dose_path)

    # Configure return types
    for fn in ['KernLoad', 'KernFree', 'KernGetNumPhi', 'KernGetNumRad',
               'KernGetInterpRows']:
        getattr(kern, fn).restype = ctypes.c_long
    for fn in ['KernGetMu', 'KernGetAngle', 'KernGetInterpEnergy']:
        getattr(kern, fn).restype = ctypes.c_double

    for fn in ['DcInit', 'DcFree', 'DcSetDensity', 'DcSetKernel',
               'DcSetKernelAngle', 'DcSetKernelEnergy', 'DcSetupLUT',
               'DcCalcTerma', 'DcCalcDose']:
        getattr(dose, fn).restype = ctypes.c_long
    for fn in ['DcGetDensity', 'DcGetTerma', 'DcGetDose',
               'DcGetMaxDose', 'DcGetMaxTerma', 'DcGetFluenceSurf']:
        getattr(dose, fn).restype = ctypes.c_double

    passed = 0
    failed = 0
    D = ctypes.c_double

    def check(name, actual, expected, tol=1e-6):
        nonlocal passed, failed
        if isinstance(expected, float):
            ok = abs(actual - expected) < tol
        else:
            ok = actual == expected
        status = "PASS" if ok else "FAIL"
        if not ok:
            print(f"  {status}: {name} — got {actual}, expected {expected}")
            failed += 1
        else:
            print(f"  {status}: {name}")
            passed += 1

    def check_gt(name, actual, threshold):
        nonlocal passed, failed
        ok = actual > threshold
        status = "PASS" if ok else "FAIL"
        if not ok:
            print(f"  {status}: {name} — got {actual:.6g}, expected > {threshold}")
            failed += 1
        else:
            print(f"  {status}: {name} (={actual:.6g})")
            passed += 1

    def check_true(name, condition):
        nonlocal passed, failed
        status = "PASS" if condition else "FAIL"
        print(f"  {status}: {name}")
        if condition:
            passed += 1
        else:
            failed += 1

    def check_near(name, actual, expected, tol):
        nonlocal passed, failed
        ok = abs(actual - expected) < tol
        status = "PASS" if ok else "FAIL"
        if not ok:
            print(f"  {status}: {name} — got {actual:.6g}, expected ~{expected} (tol={tol})")
            failed += 1
        else:
            print(f"  {status}: {name} (={actual:.6g})")
            passed += 1

    GW = 16  # grid width/height (keep small for speed)
    SPACING = 10.0  # mm

    # =========================================================================
    print("=== Test 1: Grid initialization ===")

    rc = dose.DcInit(GW, GW, D(SPACING))
    check("DcInit returns 0", rc, 0)

    rc = dose.DcSetDensity(5, 5, D(1.0))
    check("DcSetDensity returns 0", rc, 0)
    check("DcGetDensity(5,5)", dose.DcGetDensity(5, 5), 1.0)

    rc = dose.DcSetDensity(GW, 0, D(1.0))
    check("Out of bounds returns -1", rc, -1)

    rc = dose.DcInit(0, 10, D(10.0))
    check("Bad width returns -1", rc, -1)
    rc = dose.DcInit(129, 10, D(10.0))
    check("Oversized returns -1", rc, -1)

    # =========================================================================
    print("\n=== Test 2: Load 6MV kernel and transfer to DoseCalc ===")

    rc = kern.KernLoad(6)
    check("KernLoad(6) returns 0", rc, 0)

    nPhi = kern.KernGetNumPhi()
    mu = kern.KernGetMu()
    interpRows = kern.KernGetInterpRows()
    check("NumPhi = 24", nPhi, 24)
    check_gt("Mu > 0", mu, 0.0)
    check_gt("InterpRows > 0", interpRows, 0)

    # Helper: set up kernel + LUT on current grid
    def setup_kernel():
        dose.DcSetKernel(nPhi, D(mu))
        for i in range(1, nPhi + 1):
            dose.DcSetKernelAngle(i, D(kern.KernGetAngle(i)))
        for phi in range(1, nPhi + 1):
            for radMM in range(1, interpRows + 1):
                dose.DcSetKernelEnergy(phi, radMM, D(kern.KernGetInterpEnergy(phi, radMM)))
        return dose.DcSetupLUT()

    # Init grid and kernel
    dose.DcInit(GW, GW, D(SPACING))
    rc = setup_kernel()
    check("DcSetupLUT returns 0", rc, 0)

    # =========================================================================
    print("\n=== Test 3: TERMA through uniform water ===")

    # Fill with water
    for y in range(GW):
        for x in range(GW):
            dose.DcSetDensity(x, y, D(1.0))

    srcX, srcY = GW / 2.0, -50.0  # source above center
    beamMin, beamMax = GW / 2.0 - 4.0, GW / 2.0 + 4.0

    rc = dose.DcCalcTerma(D(srcX), D(srcY), D(beamMin), D(beamMax), 2)
    check("DcCalcTerma returns 0", rc, 0)

    maxTerma = dose.DcGetMaxTerma()
    check_gt("MaxTerma > 0", maxTerma, 0.0)
    check_gt("FluenceSurf > 0", dose.DcGetFluenceSurf(), 0.0)

    # TERMA decreases with depth
    cx = GW // 2
    tSurf = dose.DcGetTerma(cx, 0)
    tMid = dose.DcGetTerma(cx, GW // 2)
    tDeep = dose.DcGetTerma(cx, GW - 1)
    check_gt("TERMA surface > 0", tSurf, 0.0)
    check_true("TERMA surf > mid", tSurf > tMid)
    check_true("TERMA mid > deep", tMid > tDeep)

    # TERMA zero outside beam
    check_near("TERMA outside beam ~ 0", dose.DcGetTerma(0, GW // 2), 0.0, 1e-10)

    # Rough symmetry
    tL = dose.DcGetTerma(cx - 2, 4)
    tR = dose.DcGetTerma(cx + 2, 4)
    if tL > 0 and tR > 0:
        ratio = tL / tR
        check_true("TERMA symmetric (0.8-1.2)", 0.8 < ratio < 1.2)
    else:
        check_gt("TERMA left > 0", tL, 0.0)

    print("  TERMA depth profile at center:")
    for y in range(0, GW, 2):
        print(f"    y={y:2d}: {dose.DcGetTerma(cx, y):.6g}")

    # =========================================================================
    print("\n=== Test 4: Full dose calculation ===")

    rc = dose.DcCalcDose()
    check("DcCalcDose returns 0", rc, 0)
    check_near("MaxDose = 1.0 (normalized)", dose.DcGetMaxDose(), 1.0, 1e-6)

    dSurf = dose.DcGetDose(cx, 0)
    dMid = dose.DcGetDose(cx, GW // 2)
    dDeep = dose.DcGetDose(cx, GW - 1)

    check_gt("Dose at mid > 0", dMid, 0.0)
    check_true("Dose mid > deep", dMid > dDeep)

    # Dose outside beam should be small
    dOut = dose.DcGetDose(0, GW // 2)
    check_true("Dose outside beam < 0.05", dOut < 0.05)

    print("  Dose depth profile at center:")
    for y in range(0, GW, 2):
        print(f"    y={y:2d}: {dose.DcGetDose(cx, y):.6g}")

    print("  Dose lateral profile at y=6:")
    for x in range(0, GW, 2):
        print(f"    x={x:2d}: {dose.DcGetDose(x, 6):.6g}")

    # =========================================================================
    print("\n=== Test 5: Non-uniform density (bone slab) ===")

    # Re-init with same grid, keep kernel
    dose.DcInit(GW, GW, D(SPACING))
    setup_kernel()

    # Water top, bone bottom
    for y in range(GW):
        for x in range(GW):
            rho = 1.0 if y < GW // 2 else 1.8
            dose.DcSetDensity(x, y, D(rho))

    rc = dose.DcCalcTerma(D(srcX), D(srcY), D(beamMin), D(beamMax), 2)
    check("DcCalcTerma (bone) returns 0", rc, 0)

    # Bone attenuates faster
    tWater = dose.DcGetTerma(cx, GW // 2 - 2)
    tBone = dose.DcGetTerma(cx, GW // 2 + 2)
    tDeepBone = dose.DcGetTerma(cx, GW - 2)
    check_gt("TERMA in water > 0", tWater, 0.0)
    check_gt("TERMA in bone > 0", tBone, 0.0)
    check_true("TERMA bone attenuates", tBone > tDeepBone)

    rc = dose.DcCalcDose()
    check("DcCalcDose (bone) returns 0", rc, 0)
    check_near("MaxDose = 1.0 (normalized)", dose.DcGetMaxDose(), 1.0, 1e-6)

    # =========================================================================
    print("\n=== Test 6: Air cavity ===")

    dose.DcInit(GW, GW, D(SPACING))
    setup_kernel()

    # Water with air cavity at rows 4-5
    for y in range(GW):
        for x in range(GW):
            if 4 <= y <= 5:
                dose.DcSetDensity(x, y, D(0.001))  # air
            else:
                dose.DcSetDensity(x, y, D(1.0))

    rc = dose.DcCalcTerma(D(srcX), D(srcY), D(beamMin), D(beamMax), 2)
    check("DcCalcTerma (air) returns 0", rc, 0)

    # TERMA in air should be near zero (very low density)
    tAir = dose.DcGetTerma(cx, 4)
    tBelowAir = dose.DcGetTerma(cx, 7)
    check_true("TERMA in air very small", tAir < tBelowAir * 0.1)
    check_gt("TERMA below air cavity > 0", tBelowAir, 0.0)

    rc = dose.DcCalcDose()
    check("DcCalcDose (air) returns 0", rc, 0)

    # =========================================================================
    print("\n=== Cleanup ===")
    dose.DcFree()
    kern.KernFree()
    print("  Done")

    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed, {passed + failed} total")
    return 1 if failed > 0 else 0


if __name__ == '__main__':
    sys.exit(main())
