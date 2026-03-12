"""Tests for MtlLib - Vector/Matrix math library."""
import ctypes
import os
import math
import sys

PYTHON32 = os.path.expanduser("~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe")

def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "MtlLib.dll")
    if not os.path.exists(dll_path):
        print(f"DLL not found: {dll_path}")
        return 1

    lib = ctypes.CDLL(dll_path)

    # Configure return types
    lib.VNCreate.restype = ctypes.c_long
    lib.VNFree.restype = ctypes.c_long
    lib.VNGetDim.restype = ctypes.c_long
    lib.VNSetElement.restype = ctypes.c_long
    lib.VNGetElement.restype = ctypes.c_double
    lib.VNSetZero.restype = ctypes.c_long
    lib.VNGetLength.restype = ctypes.c_double
    lib.VNDotProduct.restype = ctypes.c_double
    lib.VNScale.restype = ctypes.c_long
    lib.VNAddInPlace.restype = ctypes.c_long
    lib.VNCopy.restype = ctypes.c_long
    lib.M4Create.restype = ctypes.c_long
    lib.M4Free.restype = ctypes.c_long
    lib.M4SetIdentity.restype = ctypes.c_long
    lib.M4SetElement.restype = ctypes.c_long
    lib.M4GetElement.restype = ctypes.c_double
    lib.M4Multiply.restype = ctypes.c_long
    lib.M4Transpose.restype = ctypes.c_long
    lib.MtlSqrt.restype = ctypes.c_double
    lib.MtlExp.restype = ctypes.c_double
    lib.MtlPi.restype = ctypes.c_double

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

    # --- VectorN tests ---
    print("=== VectorN ===")
    h1 = lib.VNCreate(ctypes.c_long(3))
    check("VNCreate", h1 > 0, True)
    check("VNGetDim", lib.VNGetDim(h1), 3)

    lib.VNSetElement(h1, ctypes.c_long(1), ctypes.c_double(3.0))
    lib.VNSetElement(h1, ctypes.c_long(2), ctypes.c_double(4.0))
    lib.VNSetElement(h1, ctypes.c_long(3), ctypes.c_double(0.0))
    check("VNGetElement[1]", lib.VNGetElement(h1, ctypes.c_long(1)), 3.0)
    check("VNGetElement[2]", lib.VNGetElement(h1, ctypes.c_long(2)), 4.0)
    check("VNGetLength (3,4,0)", lib.VNGetLength(h1), 5.0)

    h2 = lib.VNCreate(ctypes.c_long(3))
    lib.VNSetElement(h2, ctypes.c_long(1), ctypes.c_double(1.0))
    lib.VNSetElement(h2, ctypes.c_long(2), ctypes.c_double(2.0))
    lib.VNSetElement(h2, ctypes.c_long(3), ctypes.c_double(3.0))
    dot = lib.VNDotProduct(h1, h2)
    check("VNDotProduct", dot, 11.0)  # 3*1 + 4*2 + 0*3

    lib.VNScale(h2, ctypes.c_double(2.0))
    check("VNScale[1]", lib.VNGetElement(h2, ctypes.c_long(1)), 2.0)
    check("VNScale[2]", lib.VNGetElement(h2, ctypes.c_long(2)), 4.0)

    h3 = lib.VNCopy(h1)
    check("VNCopy", lib.VNGetElement(h3, ctypes.c_long(1)), 3.0)

    lib.VNAddInPlace(h3, h2)
    check("VNAddInPlace[1]", lib.VNGetElement(h3, ctypes.c_long(1)), 5.0)  # 3+2

    lib.VNFree(h1)
    lib.VNFree(h2)
    lib.VNFree(h3)

    # --- Matrix tests ---
    print("\n=== Matrix4x4 ===")
    m1 = lib.M4Create()
    check("M4Create", m1 > 0, True)
    check("M4 identity [0,0]", lib.M4GetElement(m1, 0, 0), 1.0)
    check("M4 identity [0,1]", lib.M4GetElement(m1, 0, 1), 0.0)
    check("M4 identity [3,3]", lib.M4GetElement(m1, 3, 3), 1.0)

    # Set translation
    lib.M4SetElement(m1, ctypes.c_long(0), ctypes.c_long(3), ctypes.c_double(10.0))
    lib.M4SetElement(m1, ctypes.c_long(1), ctypes.c_long(3), ctypes.c_double(20.0))
    lib.M4SetElement(m1, ctypes.c_long(2), ctypes.c_long(3), ctypes.c_double(30.0))
    check("Translation X", lib.M4GetElement(m1, 0, 3), 10.0)

    # Multiply identity * translation = translation
    m2 = lib.M4Create()  # Identity
    m3 = lib.M4Multiply(m2, m1)
    check("M4Multiply identity", lib.M4GetElement(m3, 0, 3), 10.0)

    lib.M4Free(m1)
    lib.M4Free(m2)
    lib.M4Free(m3)

    # --- Utility tests ---
    print("\n=== Utilities ===")
    check("MtlSqrt(25)", lib.MtlSqrt(ctypes.c_double(25.0)), 5.0)
    check("MtlExp(0)", lib.MtlExp(ctypes.c_double(0.0)), 1.0)
    check("MtlExp(1)", lib.MtlExp(ctypes.c_double(1.0)), math.e, tol=1e-6)
    check("MtlPi", lib.MtlPi(), math.pi, tol=1e-10)

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return 1 if failed > 0 else 0

if __name__ == "__main__":
    sys.exit(main())
