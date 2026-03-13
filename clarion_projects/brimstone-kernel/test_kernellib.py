"""Tests for KernelLib - Energy deposition kernel reader.

Loads kernel data files and verifies:
- File parsing (dimensions, angles, radial boundaries)
- Incremental and cumulative energy values
- Interpolated energy at 1mm resolution
- Attenuation coefficients for 2, 6, 15 MV
"""
import ctypes
import os
import sys
import math


def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "KernelLib.dll")
    if not os.path.exists(dll_path):
        print(f"DLL not found: {dll_path}")
        return 1

    lib = ctypes.CDLL(dll_path)

    # Configure return types
    for fn in ['KernLoad', 'KernFree', 'KernGetNumPhi', 'KernGetNumRad',
               'KernGetInterpRows']:
        getattr(lib, fn).restype = ctypes.c_long

    for fn in ['KernGetMu', 'KernGetAngle', 'KernGetRadBound',
               'KernGetIncEnergy', 'KernGetCumEnergy', 'KernGetInterpEnergy']:
        getattr(lib, fn).restype = ctypes.c_double

    passed = 0
    failed = 0

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

    # =========================================================================
    print("=== Load 6MV kernel ===")

    rc = lib.KernLoad(6)
    check("KernLoad(6) returns 0", rc, 0)

    nPhi = lib.KernGetNumPhi()
    nRad = lib.KernGetNumRad()
    check("NumPhi", nPhi, 24)
    check("NumRad", nRad, 48)
    check_near("Mu (6MV)", lib.KernGetMu(), 0.02770, 1e-5)

    # Check first angle (from file: 8.0266349E-02 radians)
    check_near("Angle[1]", lib.KernGetAngle(1), 0.080266349, 1e-5)
    # Last angle should be near pi (3.059592)
    check_near("Angle[24]", lib.KernGetAngle(nPhi), 3.059592, 1e-3)

    # First radial boundary (implicit 0.0)
    check_near("RadBound[1] (implicit 0)", lib.KernGetRadBound(1), 0.0, 1e-10)
    # Second boundary = 0.025 cm
    check_near("RadBound[2]", lib.KernGetRadBound(2), 0.025, 1e-4)
    # Last boundary = 60.0 cm
    check_near("RadBound[49]", lib.KernGetRadBound(nRad + 1), 60.0, 0.1)

    # Check first incremental energy value (phi=1, rad=1)
    # From file: 3.3753677E-03
    check_near("IncEnergy[1,1]", lib.KernGetIncEnergy(1, 1), 3.3753677e-03, 1e-6)

    # Cumulative energy at (1,1) should equal incremental (first element)
    check_near("CumEnergy[1,1]", lib.KernGetCumEnergy(1, 1), 3.3753677e-03, 1e-6)

    # Cumulative energy at (1,2) = inc[1,1] + inc[1,2]
    inc1 = lib.KernGetIncEnergy(1, 1)
    inc2 = lib.KernGetIncEnergy(1, 2)
    cum2 = lib.KernGetCumEnergy(1, 2)
    check_near("CumEnergy[1,2] = cum[1]+inc[2]", cum2, inc1 + inc2, 1e-8)

    # Cumulative should be monotonically increasing (all values positive)
    cum_prev = lib.KernGetCumEnergy(1, 1)
    mono_ok = True
    for r in range(2, nRad + 1):
        cum_cur = lib.KernGetCumEnergy(1, r)
        if cum_cur < cum_prev - 1e-15:
            mono_ok = False
            break
        cum_prev = cum_cur
    check("CumEnergy[1,:] monotonic", mono_ok, True)

    # Check interpolated energy
    interp_rows = lib.KernGetInterpRows()
    check("InterpRows", interp_rows, 600)

    # Interpolated at radMM=1 (0.1cm) should be > 0
    ie1 = lib.KernGetInterpEnergy(1, 1)
    check("InterpEnergy[1,1] = 0 (at 0mm)", ie1, 0.0, 1e-15)
    ie2 = lib.KernGetInterpEnergy(1, 2)
    check("InterpEnergy[1,2] > 0 (at 1mm)", ie2 > 0, True)

    # Interpolated should be monotonically non-decreasing
    ie_prev = lib.KernGetInterpEnergy(1, 1)
    interp_mono = True
    for mm in range(2, 101):  # check first 10cm
        ie_cur = lib.KernGetInterpEnergy(1, mm)
        if ie_cur < ie_prev - 1e-15:
            interp_mono = False
            break
        ie_prev = ie_cur
    check("InterpEnergy[1,1:100] monotonic", interp_mono, True)

    # Interpolated at large radius should approach total cumulative
    ie_end = lib.KernGetInterpEnergy(1, 600)
    cum_total = lib.KernGetCumEnergy(1, nRad)
    check_near("InterpEnergy[1,600] ~ CumEnergy[1,48]", ie_end, cum_total, 1e-4)

    lib.KernFree()

    # =========================================================================
    print("\n=== Load 15MV kernel ===")

    rc = lib.KernLoad(15)
    check("KernLoad(15) returns 0", rc, 0)
    check_near("Mu (15MV)", lib.KernGetMu(), 0.01941, 1e-5)

    nPhi15 = lib.KernGetNumPhi()
    nRad15 = lib.KernGetNumRad()
    check("15MV NumPhi", nPhi15, 48)
    check("15MV NumRad", nRad15, 24)

    # 15MV should have different energy values than 6MV
    inc15_1_1 = lib.KernGetIncEnergy(1, 1)
    check("15MV IncEnergy[1,1] > 0", inc15_1_1 > 0, True)

    lib.KernFree()

    # =========================================================================
    print("\n=== Load 2MV kernel ===")

    rc = lib.KernLoad(2)
    check("KernLoad(2) returns 0", rc, 0)
    check_near("Mu (2MV)", lib.KernGetMu(), 0.04942, 1e-5)
    lib.KernFree()

    # =========================================================================
    print("\n=== Error handling ===")

    rc = lib.KernLoad(99)
    check("KernLoad(99) returns -1", rc, -1)

    # =========================================================================
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
