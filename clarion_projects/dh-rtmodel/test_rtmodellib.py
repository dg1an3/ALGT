"""Tests for RtModelLib - RT treatment planning model library."""
import ctypes
import os
import math
import sys

def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "RtModelLib.dll")
    if not os.path.exists(dll_path):
        print(f"DLL not found: {dll_path}")
        return 1

    lib = ctypes.CDLL(dll_path)

    # Configure return types
    for fn in ['PlanInit', 'PlanClose', 'PlanGetGridW', 'PlanGetGridH', 'PlanGetGridD',
               'PlanSetDensity', 'PlanAddBeam', 'PlanGetBeamCount', 'PlanSetBeamWeight',
               'PlanSetBeamDose', 'PlanAccumulateDose', 'PlanNormalizeDose',
               'PlanAddStructure', 'PlanGetStructureCount', 'PlanSetRegionVoxel',
               'HistCompute', 'HistGetBinCount']:
        getattr(lib, fn).restype = ctypes.c_long

    for fn in ['PlanGetDensity', 'PlanGetDose', 'PlanGetMaxDose', 'PlanGetBeamDose',
               'PlanGetBeamWeight', 'PlanGetRegionVoxel',
               'HistGetBinValue', 'HistGetCumBinValue']:
        getattr(lib, fn).restype = ctypes.c_double

    passed = 0
    failed = 0

    def check(name, actual, expected, tol=1e-9):
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

    # --- Plan initialization ---
    print("=== Plan Init ===")
    rc = lib.PlanInit(ctypes.c_long(8), ctypes.c_long(8), ctypes.c_long(1))
    check("PlanInit", rc, 0)
    check("GridW", lib.PlanGetGridW(), 8)
    check("GridH", lib.PlanGetGridH(), 8)
    check("GridD", lib.PlanGetGridD(), 1)

    # --- Density ---
    print("\n=== Density ===")
    lib.PlanSetDensity(ctypes.c_long(3), ctypes.c_long(4), ctypes.c_long(0), ctypes.c_double(500.0))
    check("SetDensity/GetDensity", lib.PlanGetDensity(3, 4, 0), 500.0)
    check("Density default", lib.PlanGetDensity(0, 0, 0), 0.0)

    # --- Beams ---
    print("\n=== Beams ===")
    b1 = lib.PlanAddBeam(ctypes.c_double(0.5), ctypes.c_double(0.0),
                         ctypes.c_double(0.0), ctypes.c_double(0.0))
    check("AddBeam", b1, 1)
    check("BeamCount", lib.PlanGetBeamCount(), 1)
    check("BeamWeight", lib.PlanGetBeamWeight(1), 0.5)

    b2 = lib.PlanAddBeam(ctypes.c_double(0.3), ctypes.c_double(90.0),
                         ctypes.c_double(0.0), ctypes.c_double(0.0))
    check("AddBeam 2", b2, 2)
    check("BeamCount", lib.PlanGetBeamCount(), 2)

    # Set beam doses
    lib.PlanSetBeamDose(ctypes.c_long(1), ctypes.c_long(3), ctypes.c_long(4), ctypes.c_long(0),
                        ctypes.c_double(100.0))
    lib.PlanSetBeamDose(ctypes.c_long(2), ctypes.c_long(3), ctypes.c_long(4), ctypes.c_long(0),
                        ctypes.c_double(200.0))
    check("BeamDose 1", lib.PlanGetBeamDose(1, 3, 4, 0), 100.0)
    check("BeamDose 2", lib.PlanGetBeamDose(2, 3, 4, 0), 200.0)

    # --- Dose accumulation ---
    print("\n=== Dose Accumulation ===")
    lib.PlanAccumulateDose()
    # Expected: 0.5*100 + 0.3*200 = 50 + 60 = 110
    check("AccumulatedDose", lib.PlanGetDose(3, 4, 0), 110.0)
    check("MaxDose", lib.PlanGetMaxDose(), 110.0)

    lib.PlanNormalizeDose()
    check("NormalizedDose", lib.PlanGetDose(3, 4, 0), 1.0)

    # --- Structures ---
    print("\n=== Structures ===")
    s1 = lib.PlanAddStructure(ctypes.c_long(1), ctypes.c_long(255),
                              ctypes.c_long(0), ctypes.c_long(0))
    check("AddStructure", s1, 1)
    check("StructureCount", lib.PlanGetStructureCount(), 1)

    lib.PlanSetRegionVoxel(ctypes.c_long(1), ctypes.c_long(3), ctypes.c_long(4),
                           ctypes.c_long(0), ctypes.c_double(1.0))
    check("RegionVoxel", lib.PlanGetRegionVoxel(1, 3, 4, 0), 1.0)

    # --- Histogram ---
    print("\n=== Histogram (DVH) ===")
    lib.HistCompute(ctypes.c_long(1))
    check("BinCount", lib.HistGetBinCount(), 256)
    # With only one voxel at dose=1.0 (max), should be in last bin
    # Cumulative bin 1 should be 1.0 (100% volume receives >= minimum dose)
    cum1 = lib.HistGetCumBinValue(ctypes.c_long(1))
    check("CumBin[1] (all volume)", cum1, 1.0)

    lib.PlanClose()

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return 1 if failed > 0 else 0

if __name__ == "__main__":
    sys.exit(main())
