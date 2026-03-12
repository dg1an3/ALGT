"""test_graf3d.py — Tests for Graf3D.dll (Apple Graf3D.p 1983 in Clarion).

Uses 32-bit Python + ctypes. Fixed-point convention: REAL * 10000.
Tolerance of +/-2 on fixed-point results to account for trig rounding.
"""
import ctypes
import os
import sys


FP = 10000  # fixed-point multiplier


def fp(val):
    """Convert a float to fixed-point LONG."""
    return int(round(val * FP))


def main():
    dll_path = os.path.join(os.getcwd(), "bin", "Graf3D.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return 1

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return 1

    passed = 0
    failed = 0

    def check(name, actual, expected, tol=0):
        nonlocal passed, failed
        if abs(actual - expected) <= tol:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name} - expected {expected}, got {actual} (tol={tol})")
            failed += 1

    # =========================================================
    # Init + Identity matrix check
    # =========================================================
    print("=== G3Init + Identity ===")
    lib.G3Init()
    # Diagonal should be 10000, off-diagonal should be 0
    for i in range(16):
        row = i // 4
        col = i % 4
        val = lib.G3GetMatrix(i)
        expected = fp(1.0) if row == col else 0
        check(f"identity[{row},{col}]", val, expected)

    # =========================================================
    # SetPt / GetPt roundtrip
    # =========================================================
    print("=== G3SetPt / G3GetPt ===")
    lib.G3SetPt(fp(1.5), fp(-2.75), fp(3.0))
    check("GetPtX after SetPt", lib.G3GetPtX(), fp(1.5))
    check("GetPtY after SetPt", lib.G3GetPtY(), fp(-2.75))
    check("GetPtZ after SetPt", lib.G3GetPtZ(), fp(3.0))

    # Zero point
    lib.G3SetPt(0, 0, 0)
    check("GetPtX zero", lib.G3GetPtX(), 0)
    check("GetPtY zero", lib.G3GetPtY(), 0)
    check("GetPtZ zero", lib.G3GetPtZ(), 0)

    # =========================================================
    # Scale: set point (1,1,1), scale by (2,3,4), transform
    # Expected: (2,3,4)
    # =========================================================
    print("=== G3Scale ===")
    lib.G3Init()
    lib.G3Scale(fp(2.0), fp(3.0), fp(4.0))
    lib.G3SetPt(fp(1.0), fp(1.0), fp(1.0))
    lib.G3Transform()
    check("Scale x", lib.G3GetPtX(), fp(2.0), tol=2)
    check("Scale y", lib.G3GetPtY(), fp(3.0), tol=2)
    check("Scale z", lib.G3GetPtZ(), fp(4.0), tol=2)

    # Scale with non-unit point
    lib.G3Init()
    lib.G3Scale(fp(0.5), fp(2.0), fp(3.0))
    lib.G3SetPt(fp(4.0), fp(2.0), fp(1.0))
    lib.G3Transform()
    check("Scale2 x", lib.G3GetPtX(), fp(2.0), tol=2)
    check("Scale2 y", lib.G3GetPtY(), fp(4.0), tol=2)
    check("Scale2 z", lib.G3GetPtZ(), fp(3.0), tol=2)

    # =========================================================
    # Translate: identity + translate(5,10,15), transform (0,0,0)
    # Expected: (5,10,15)
    # =========================================================
    print("=== G3Translate ===")
    lib.G3Init()
    lib.G3Translate(fp(5.0), fp(10.0), fp(15.0))
    lib.G3SetPt(0, 0, 0)
    lib.G3Transform()
    check("Translate x", lib.G3GetPtX(), fp(5.0), tol=2)
    check("Translate y", lib.G3GetPtY(), fp(10.0), tol=2)
    check("Translate z", lib.G3GetPtZ(), fp(15.0), tol=2)

    # Translate with non-zero start
    lib.G3Init()
    lib.G3Translate(fp(1.0), fp(2.0), fp(3.0))
    lib.G3SetPt(fp(10.0), fp(20.0), fp(30.0))
    lib.G3Transform()
    check("Translate+pt x", lib.G3GetPtX(), fp(11.0), tol=2)
    check("Translate+pt y", lib.G3GetPtY(), fp(22.0), tol=2)
    check("Translate+pt z", lib.G3GetPtZ(), fp(33.0), tol=2)

    # =========================================================
    # Pitch 90 degrees: (0,1,0) -> (0,0,-1)
    # Original Pascal convention: TEMP:=col1*co+col2*si; col2:=col2*co-col1*si; col1:=TEMP
    # =========================================================
    print("=== G3Pitch 90 ===")
    lib.G3Init()
    lib.G3Pitch(fp(90.0))
    lib.G3SetPt(0, fp(1.0), 0)
    lib.G3Transform()
    check("Pitch90 x", lib.G3GetPtX(), 0, tol=2)
    check("Pitch90 y", lib.G3GetPtY(), 0, tol=2)
    check("Pitch90 z", lib.G3GetPtZ(), fp(-1.0), tol=2)

    # Pitch 90: (0,0,1) -> (0,1,0)
    lib.G3Init()
    lib.G3Pitch(fp(90.0))
    lib.G3SetPt(0, 0, fp(1.0))
    lib.G3Transform()
    check("Pitch90 z->y x", lib.G3GetPtX(), 0, tol=2)
    check("Pitch90 z->y y", lib.G3GetPtY(), fp(1.0), tol=2)
    check("Pitch90 z->y z", lib.G3GetPtZ(), 0, tol=2)

    # =========================================================
    # Yaw 90 degrees: (1,0,0) -> (0,0,1)
    # Original Pascal convention: TEMP:=col0*co-col2*si; col2:=col2*co+col0*si; col0:=TEMP
    # =========================================================
    print("=== G3Yaw 90 ===")
    lib.G3Init()
    lib.G3Yaw(fp(90.0))
    lib.G3SetPt(fp(1.0), 0, 0)
    lib.G3Transform()
    check("Yaw90 x", lib.G3GetPtX(), 0, tol=2)
    check("Yaw90 y", lib.G3GetPtY(), 0, tol=2)
    check("Yaw90 z", lib.G3GetPtZ(), fp(1.0), tol=2)

    # Yaw 90: (0,0,1) -> (-1,0,0)
    lib.G3Init()
    lib.G3Yaw(fp(90.0))
    lib.G3SetPt(0, 0, fp(1.0))
    lib.G3Transform()
    check("Yaw90 z->-x x", lib.G3GetPtX(), fp(-1.0), tol=2)
    check("Yaw90 z->-x y", lib.G3GetPtY(), 0, tol=2)
    check("Yaw90 z->-x z", lib.G3GetPtZ(), 0, tol=2)

    # =========================================================
    # Roll 90 degrees: (1,0,0) -> (0,-1,0)
    # Original Pascal convention: TEMP:=col0*co+col1*si; col1:=col1*co-col0*si; col0:=TEMP
    # =========================================================
    print("=== G3Roll 90 ===")
    lib.G3Init()
    lib.G3Roll(fp(90.0))
    lib.G3SetPt(fp(1.0), 0, 0)
    lib.G3Transform()
    check("Roll90 x", lib.G3GetPtX(), 0, tol=2)
    check("Roll90 y", lib.G3GetPtY(), fp(-1.0), tol=2)
    check("Roll90 z", lib.G3GetPtZ(), 0, tol=2)

    # Roll 90: (0,1,0) -> (1,0,0)
    lib.G3Init()
    lib.G3Roll(fp(90.0))
    lib.G3SetPt(0, fp(1.0), 0)
    lib.G3Transform()
    check("Roll90 y->x x", lib.G3GetPtX(), fp(1.0), tol=2)
    check("Roll90 y->x y", lib.G3GetPtY(), 0, tol=2)
    check("Roll90 y->x z", lib.G3GetPtZ(), 0, tol=2)

    # =========================================================
    # Combined transforms: Scale + Translate
    # Scale(2,2,2) then Translate(10,0,0), transform (1,0,0)
    # Expected: scale first -> (2,0,0), then translate -> (12,0,0)
    # =========================================================
    print("=== Combined: Scale + Translate ===")
    lib.G3Init()
    lib.G3Scale(fp(2.0), fp(2.0), fp(2.0))
    lib.G3Translate(fp(10.0), 0, 0)
    lib.G3SetPt(fp(1.0), 0, 0)
    lib.G3Transform()
    check("Scale+Trans x", lib.G3GetPtX(), fp(12.0), tol=2)
    check("Scale+Trans y", lib.G3GetPtY(), 0, tol=2)
    check("Scale+Trans z", lib.G3GetPtZ(), 0, tol=2)

    # =========================================================
    # Combined transforms: Pitch + Translate
    # Pitch 90 then Translate(0,0,5), transform (0,1,0)
    # Pitch: (0,1,0) -> (0,0,1), then add translate: (0,0,6)
    # =========================================================
    print("=== Combined: Pitch + Translate ===")
    lib.G3Init()
    lib.G3Pitch(fp(90.0))
    lib.G3Translate(0, 0, fp(5.0))
    lib.G3SetPt(0, fp(1.0), 0)
    lib.G3Transform()
    check("Pitch+Trans x", lib.G3GetPtX(), 0, tol=2)
    check("Pitch+Trans y", lib.G3GetPtY(), 0, tol=2)
    check("Pitch+Trans z", lib.G3GetPtZ(), fp(6.0), tol=2)

    # =========================================================
    # G3SetMatrix / G3GetMatrix
    # =========================================================
    print("=== G3SetMatrix / G3GetMatrix ===")
    lib.G3Init()
    lib.G3SetMatrix(0, fp(99.0))
    check("SetMatrix [0,0]", lib.G3GetMatrix(0), fp(99.0))
    lib.G3SetMatrix(5, fp(-7.5))
    check("SetMatrix [1,1]", lib.G3GetMatrix(5), fp(-7.5))

    # =========================================================
    # 180-degree rotations
    # =========================================================
    print("=== 180-degree rotations ===")
    # Roll 180: (1,0,0) -> (-1,0,0)
    lib.G3Init()
    lib.G3Roll(fp(180.0))
    lib.G3SetPt(fp(1.0), 0, 0)
    lib.G3Transform()
    check("Roll180 x", lib.G3GetPtX(), fp(-1.0), tol=2)
    check("Roll180 y", lib.G3GetPtY(), 0, tol=2)

    # Pitch 180: (0,1,0) -> (0,-1,0)
    lib.G3Init()
    lib.G3Pitch(fp(180.0))
    lib.G3SetPt(0, fp(1.0), 0)
    lib.G3Transform()
    check("Pitch180 y", lib.G3GetPtY(), fp(-1.0), tol=2)
    check("Pitch180 z", lib.G3GetPtZ(), 0, tol=2)

    # ---- Summary ----
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    if failed == 0:
        print("ALL TESTS PASSED")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
