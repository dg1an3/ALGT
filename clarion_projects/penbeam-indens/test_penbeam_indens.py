"""Tests for PenBeamIndens - Photon dose calculation via superposition.

Tests the fluence calculation against expected physics behavior:
- Central axis fluence should be highest
- Fluence decreases with depth (exponential attenuation)
- Fluence drops off at field boundaries
- Homogeneous phantom with known parameters
"""
import ctypes
import os
import sys
import math

def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "PenBeamIndens.dll")
    if not os.path.exists(dll_path):
        print(f"DLL not found: {dll_path}")
        return 1

    lib = ctypes.CDLL(dll_path)

    # Configure return types
    for fn in ['PBInit', 'PBSetROI', 'PBClose', 'PBSetDensityHomogeneous',
               'PBSetDensityCylinder', 'PBSetDensityVoxel', 'PBCalcFluence',
               'PBSetKernelParams', 'PBSetKernelPoint', 'PBSetKernelAngle',
               'PBSetKernelRadBound', 'PBCalcConvolve',
               'PBGetGridW', 'PBGetHalfW', 'PBGetMaxDepth', 'PBGetDepthNum',
               'PBGetDmaxI', 'PBGetDmaxJ', 'PBGetDmaxK']:
        getattr(lib, fn).restype = ctypes.c_long

    for fn in ['PBGetDensityVoxel', 'PBGetFluence', 'PBGetDose', 'PBGetDoseMax']:
        getattr(lib, fn).restype = ctypes.c_double

    passed = 0
    failed = 0

    def check(name, actual, expected, tol=1e-9):
        nonlocal passed, failed
        if isinstance(expected, float):
            ok = abs(actual - expected) < tol
        elif isinstance(expected, bool):
            ok = bool(actual) == expected
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
            print(f"  {status}: {name} — got {actual}, expected > {threshold}")
            failed += 1
        else:
            print(f"  {status}: {name} (={actual:.6g})")
            passed += 1

    def check_lt(name, actual, threshold):
        nonlocal passed, failed
        ok = actual < threshold
        status = "PASS" if ok else "FAIL"
        if not ok:
            print(f"  {status}: {name} — got {actual}, expected < {threshold}")
            failed += 1
        else:
            print(f"  {status}: {name} (={actual:.6g})")
            passed += 1

    # =========================================================================
    print("=== Grid Configuration ===")
    check("GridW", lib.PBGetGridW(), 65)
    check("HalfW", lib.PBGetHalfW(), 32)
    check("MaxDepth", lib.PBGetMaxDepth(), 64)

    # =========================================================================
    print("\n=== Init & Density ===")
    # 6 MV beam, 30cm phantom, 0.5cm voxels, 100cm SSD, 10x10 field
    rc = lib.PBInit(
        ctypes.c_double(6.0),     # energy MeV
        ctypes.c_double(30.0),    # thickness cm
        ctypes.c_double(0.5),     # voxel x
        ctypes.c_double(0.5),     # voxel y
        ctypes.c_double(0.5),     # voxel z
        ctypes.c_double(100.0),   # SSD
        ctypes.c_double(-5.0),    # xmin
        ctypes.c_double(5.0),     # xmax
        ctypes.c_double(-5.0),    # ymin
        ctypes.c_double(5.0),     # ymax
        ctypes.c_double(0.0492),  # mu
        ctypes.c_double(1.0),     # ray
    )
    check("PBInit", rc, 0)
    check("DepthNum", lib.PBGetDepthNum(), 60)  # 30/0.5 = 60

    # Set homogeneous water phantom
    rc = lib.PBSetDensityHomogeneous(ctypes.c_double(1.0))
    check("SetDensityHomogeneous", rc, 0)
    check("Density(0,0,1)", lib.PBGetDensityVoxel(0, 0, 1), 1.0)
    check("Density(10,10,30)", lib.PBGetDensityVoxel(10, 10, 30), 1.0)

    # =========================================================================
    print("\n=== Fluence Calculation ===")
    rc = lib.PBCalcFluence()
    check("PBCalcFluence", rc, 0)

    # Central axis fluence at shallow depth should be positive
    flu_shallow = lib.PBGetFluence(0, 0, 2)
    check_gt("Fluence(0,0,2) > 0", flu_shallow, 0.0)

    # Central axis fluence at deeper depth should be less (attenuation)
    flu_deep = lib.PBGetFluence(0, 0, 40)
    check_gt("Fluence(0,0,40) > 0", flu_deep, 0.0)
    check_lt("Fluence deep < shallow", flu_deep, flu_shallow)

    # Off-axis fluence should decrease
    flu_offaxis = lib.PBGetFluence(8, 0, 10)
    flu_center = lib.PBGetFluence(0, 0, 10)
    check_gt("Fluence center > off-axis", flu_center, flu_offaxis)

    # Outside field should have zero fluence
    flu_outside = lib.PBGetFluence(20, 0, 10)
    check("Fluence outside field ~0", flu_outside, 0.0)

    # Fluence should be symmetric (x and y)
    flu_pos = lib.PBGetFluence(3, 0, 10)
    flu_neg = lib.PBGetFluence(-3, 0, 10)
    check("Fluence symmetry x",
          abs(flu_pos - flu_neg) < 0.01 * max(abs(flu_pos), 1e-10), True)

    flu_py = lib.PBGetFluence(0, 3, 10)
    flu_ny = lib.PBGetFluence(0, -3, 10)
    check("Fluence symmetry y",
          abs(flu_py - flu_ny) < 0.01 * max(abs(flu_py), 1e-10), True)

    # =========================================================================
    print("\n=== Depth Dose Profile ===")
    print("  Depth(cm)  Fluence")
    depths = [1, 5, 10, 15, 20, 25, 30, 40, 50, 58]
    prev_flu = float('inf')
    monotone = True
    for k in depths:
        flu = lib.PBGetFluence(0, 0, k)
        label = f"  {k*0.5:6.1f}     {flu:.6e}"
        print(label)
        if flu > prev_flu * 1.01:  # allow small noise
            monotone = False
        prev_flu = flu
    check("Depth fluence monotonically decreasing", monotone, True)

    # =========================================================================
    print("\n=== Heterogeneous Phantom ===")
    # Reset and try cylinder phantom
    lib.PBInit(
        ctypes.c_double(6.0), ctypes.c_double(15.0),
        ctypes.c_double(0.5), ctypes.c_double(0.5), ctypes.c_double(0.5),
        ctypes.c_double(100.0),
        ctypes.c_double(-5.0), ctypes.c_double(5.0),
        ctypes.c_double(-5.0), ctypes.c_double(5.0),
        ctypes.c_double(0.0492), ctypes.c_double(1.0),
    )
    lib.PBSetDensityCylinder(
        ctypes.c_double(5.0),   # radius
        ctypes.c_double(10.0),  # length
        ctypes.c_double(0.0),   # x offset
        ctypes.c_double(8.0),   # z offset
        ctypes.c_double(1.0),   # cylinder density (water)
        ctypes.c_double(0.3),   # surrounding (lung-like)
    )
    # Check cylinder interior
    check("Cylinder center density", lib.PBGetDensityVoxel(0, 0, 16), 1.0)
    # Check surrounding
    d_outside = lib.PBGetDensityVoxel(20, 0, 16)
    check("Surrounding density", d_outside, 0.3)

    lib.PBCalcFluence()
    flu_cyl = lib.PBGetFluence(0, 0, 10)
    check_gt("Fluence in cylinder > 0", flu_cyl, 0.0)

    lib.PBClose()

    # =========================================================================
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
