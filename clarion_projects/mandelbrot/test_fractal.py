"""
Test suite for FractalLib.dll — Mandelbrot, Julia, and logistic map computations.

Uses fixed-point arithmetic: all coordinates multiplied by 10000
(e.g., -1.5 becomes -15000, passed as LONG).

Requires 32-bit Python (Clarion produces 32-bit DLLs).
"""
import ctypes
import os
import sys


def load_dll():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "FractalLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        print("Build with: MSBuild.exe FractalLib.cwproj")
        sys.exit(1)
    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        sys.exit(1)
    return lib


def to_fp(val):
    """Convert float to fixed-point (multiply by 10000)."""
    return int(val * 10000)


def from_fp(val):
    """Convert fixed-point back to float."""
    return val / 10000.0


def test_mandelbrot_single(lib):
    """Test individual Mandelbrot points."""
    print("=== Mandelbrot Single-Point Tests ===")
    passed = 0
    total = 0

    max_iter = 100

    # (0, 0) is in the set — should reach maxIter
    total += 1
    result = lib.FLMandelbrot(to_fp(0.0), to_fp(0.0), max_iter)
    if result == max_iter:
        print(f"  PASS: (0, 0) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: (0, 0) -> {result} (expected {max_iter})")

    # (2, 0) escapes immediately: z1 = 0+2 = 2, |z1|^2 = 4, not > 4
    # z2 = 4+2 = 6, |z2|^2 = 36 > 4 -> escapes at iteration 2
    # But check: iter 0: z=(0,0), |z|^2=0; z->(0+2,0)=(2,0)
    #            iter 1: z=(2,0), |z|^2=4, not > 4; z->(4+2,0)=(6,0)
    #            iter 2: z=(6,0), |z|^2=36 > 4 -> return 2
    total += 1
    result = lib.FLMandelbrot(to_fp(2.0), to_fp(0.0), max_iter)
    if result == 2:
        print(f"  PASS: (2, 0) -> {result} (expected 2)")
        passed += 1
    else:
        print(f"  FAIL: (2, 0) -> {result} (expected 2)")

    # (1, 0) escapes quickly
    # iter 0: z=(0,0), z->(1,0)
    # iter 1: z=(1,0), |z|^2=1; z->(1+1,0)=(2,0)
    # iter 2: z=(2,0), |z|^2=4, not > 4; z->(4+1,0)=(5,0)
    # iter 3: z=(5,0), |z|^2=25 > 4 -> return 3
    total += 1
    result = lib.FLMandelbrot(to_fp(1.0), to_fp(0.0), max_iter)
    if result == 3:
        print(f"  PASS: (1, 0) -> {result} (expected 3)")
        passed += 1
    else:
        print(f"  FAIL: (1, 0) -> {result} (expected 3)")

    # (-1, 0) is in the set — oscillates between -1 and 0
    # z0=(0,0)->(-1,0), z1=(-1,0)->(0,0), z2=(0,0)->(-1,0), ...
    total += 1
    result = lib.FLMandelbrot(to_fp(-1.0), to_fp(0.0), max_iter)
    if result == max_iter:
        print(f"  PASS: (-1, 0) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: (-1, 0) -> {result} (expected {max_iter})")

    # (-2, 0) is on the boundary — z oscillates 0, -2, 2, 2, 2, ...
    # Actually: z0=0->-2, z1=(-2)^2+(-2)=2, z2=2^2+(-2)=2, z3=2^2+(-2)=2
    # |z|^2 = 4, which is NOT > 4, so it stays at boundary = maxIter
    total += 1
    result = lib.FLMandelbrot(to_fp(-2.0), to_fp(0.0), max_iter)
    if result == max_iter:
        print(f"  PASS: (-2, 0) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: (-2, 0) -> {result} (expected {max_iter})")

    # (0.25, 0) is in the set (inside the main cardioid)
    total += 1
    result = lib.FLMandelbrot(to_fp(0.25), to_fp(0.0), max_iter)
    if result == max_iter:
        print(f"  PASS: (0.25, 0) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: (0.25, 0) -> {result} (expected {max_iter})")

    # (10, 0) escapes in 1 iteration: z=(0,0), |z|^2=0; z->(10,0); |z|^2=100>4 -> 1
    total += 1
    result = lib.FLMandelbrot(to_fp(10.0), to_fp(0.0), max_iter)
    if result == 1:
        print(f"  PASS: (10, 0) -> {result} (expected 1)")
        passed += 1
    else:
        print(f"  FAIL: (10, 0) -> {result} (expected 1)")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def test_julia_single(lib):
    """Test individual Julia set points."""
    print("=== Julia Single-Point Tests ===")
    passed = 0
    total = 0

    max_iter = 100
    # Classic Julia set: c = (-0.7, 0.27015)
    jcx = to_fp(-0.7)
    jcy = to_fp(0.27015)

    # (0, 0) with this c — should be in the set or close
    total += 1
    result = lib.FLJulia(to_fp(0.0), to_fp(0.0), jcx, jcy, max_iter)
    if result == max_iter:
        print(f"  PASS: z=(0,0), c=(-0.7,0.27015) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: z=(0,0), c=(-0.7,0.27015) -> {result} (expected {max_iter})")

    # (2, 0) should escape quickly
    total += 1
    result = lib.FLJulia(to_fp(2.0), to_fp(0.0), jcx, jcy, max_iter)
    if result < 10:
        print(f"  PASS: z=(2,0) escapes quickly -> {result} (expected < 10)")
        passed += 1
    else:
        print(f"  FAIL: z=(2,0) -> {result} (expected < 10)")

    # Known Julia c = (0, 1): the "dendrite" Julia set
    # z=(0,0): z1=(0,1), z2=(-1,1), z3=(0,-1), z4=(-1,1), ... -> in set
    total += 1
    result = lib.FLJulia(to_fp(0.0), to_fp(0.0), to_fp(0.0), to_fp(1.0), max_iter)
    if result == max_iter:
        print(f"  PASS: z=(0,0), c=(0,1) -> {result} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: z=(0,0), c=(0,1) -> {result} (expected {max_iter})")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def test_mandelbrot_row(lib):
    """Test a full row computation."""
    print("=== Mandelbrot Row Test ===")
    passed = 0
    total = 0

    width = 10
    max_iter = 100
    buf = (ctypes.c_int32 * width)()

    # Row at y=0, x from -2 to 1 (standard Mandelbrot range)
    result = lib.FLMandelbrotRow(
        ctypes.addressof(buf), width,
        to_fp(0.0),       # y
        to_fp(-2.0),      # xMin
        to_fp(1.0),       # xMax
        max_iter
    )

    total += 1
    if result == 0:
        print(f"  PASS: FLMandelbrotRow returned 0")
        passed += 1
    else:
        print(f"  FAIL: FLMandelbrotRow returned {result} (expected 0)")

    values = [buf[i] for i in range(width)]
    print(f"  Row values: {values}")

    # Verify specific positions:
    # pixel 0: x = -2.0 -> in set (boundary)
    # pixel ~6-7: x near 0 -> in set
    # pixel 9: x near 0.7 -> in set (main cardioid)

    # The first pixel at x=-2.0 should be maxIter (boundary of set)
    total += 1
    if values[0] == max_iter:
        print(f"  PASS: pixel 0 (x=-2.0) -> {values[0]} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: pixel 0 (x=-2.0) -> {values[0]} (expected {max_iter})")

    # The last pixel at x near 0.7 should be in the set
    total += 1
    if values[9] == max_iter:
        print(f"  PASS: pixel 9 (x~0.7) -> {values[9]} (expected {max_iter})")
        passed += 1
    else:
        print(f"  FAIL: pixel 9 (x~0.7) -> {values[9]} (expected {max_iter})")

    # Verify consistency: single-point values should match row values
    total += 1
    step = 3.0 / width  # (1 - (-2)) / width
    all_match = True
    for i in range(width):
        cx = -2.0 + i * step
        single = lib.FLMandelbrot(to_fp(cx), to_fp(0.0), max_iter)
        if single != values[i]:
            print(f"  MISMATCH at pixel {i}: row={values[i]}, single={single}, cx={cx:.4f}")
            all_match = False
    if all_match:
        print(f"  PASS: All row values match single-point computations")
        passed += 1
    else:
        print(f"  FAIL: Some row values don't match single-point computations")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def test_julia_row(lib):
    """Test a full Julia row computation."""
    print("=== Julia Row Test ===")
    passed = 0
    total = 0

    width = 10
    max_iter = 100
    buf = (ctypes.c_int32 * width)()

    jcx = to_fp(-0.7)
    jcy = to_fp(0.27015)

    result = lib.FLJuliaRow(
        ctypes.addressof(buf), width,
        to_fp(0.0),       # y (zy)
        to_fp(-1.5),      # xMin
        to_fp(1.5),       # xMax
        jcx, jcy,
        max_iter
    )

    total += 1
    if result == 0:
        print(f"  PASS: FLJuliaRow returned 0")
        passed += 1
    else:
        print(f"  FAIL: FLJuliaRow returned {result} (expected 0)")

    values = [buf[i] for i in range(width)]
    print(f"  Row values: {values}")

    # Verify consistency with single-point Julia
    total += 1
    step = 3.0 / width
    all_match = True
    for i in range(width):
        zx = -1.5 + i * step
        single = lib.FLJulia(to_fp(zx), to_fp(0.0), jcx, jcy, max_iter)
        if single != values[i]:
            print(f"  MISMATCH at pixel {i}: row={values[i]}, single={single}, zx={zx:.4f}")
            all_match = False
    if all_match:
        print(f"  PASS: All row values match single-point computations")
        passed += 1
    else:
        print(f"  FAIL: Some row values don't match single-point computations")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def test_logistic(lib):
    """Test logistic map."""
    print("=== Logistic Map Tests ===")
    passed = 0
    total = 0

    # Simple test: p=0.5, k=1.0
    # p_new = 0.5 + 1.0 * 0.5 * (1 - 0.5) = 0.5 + 0.25 = 0.75
    total += 1
    result = lib.FLLogistic(to_fp(0.5), to_fp(1.0))
    expected = to_fp(0.75)
    if result == expected:
        print(f"  PASS: FLLogistic(0.5, 1.0) -> {from_fp(result)} (expected 0.75)")
        passed += 1
    else:
        print(f"  FAIL: FLLogistic(0.5, 1.0) -> {from_fp(result)} (expected 0.75, got fp={result})")

    # p=0.1, k=2.0: p_new = 0.1 + 2.0*0.1*0.9 = 0.1 + 0.18 = 0.28
    total += 1
    result = lib.FLLogistic(to_fp(0.1), to_fp(2.0))
    expected = to_fp(0.28)
    if result == expected:
        print(f"  PASS: FLLogistic(0.1, 2.0) -> {from_fp(result)} (expected 0.28)")
        passed += 1
    else:
        print(f"  FAIL: FLLogistic(0.1, 2.0) -> {from_fp(result)} (expected 0.28, got {from_fp(result)})")

    # p=0, k=anything: p_new = 0 (fixed point at 0)
    total += 1
    result = lib.FLLogistic(to_fp(0.0), to_fp(2.5))
    if result == 0:
        print(f"  PASS: FLLogistic(0.0, 2.5) -> 0 (fixed point)")
        passed += 1
    else:
        print(f"  FAIL: FLLogistic(0.0, 2.5) -> {from_fp(result)} (expected 0)")

    # p=1, k=anything: p_new = 1 + k*1*0 = 1 (fixed point at 1)
    total += 1
    result = lib.FLLogistic(to_fp(1.0), to_fp(2.5))
    if result == to_fp(1.0):
        print(f"  PASS: FLLogistic(1.0, 2.5) -> 1.0 (fixed point)")
        passed += 1
    else:
        print(f"  FAIL: FLLogistic(1.0, 2.5) -> {from_fp(result)} (expected 1.0)")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def test_logistic_iterate(lib):
    """Test logistic map iteration with buffer output."""
    print("=== Logistic Iterate Tests ===")
    passed = 0
    total = 0

    buf_size = 20
    buf = (ctypes.c_int32 * buf_size)()

    # 10 steps, skip 0, store all
    total += 1
    stored = lib.FLLogisticIterate(
        to_fp(0.1), to_fp(2.0),
        10, 0,
        ctypes.addressof(buf), buf_size
    )
    if stored == 10:
        print(f"  PASS: Stored {stored} values (expected 10)")
        passed += 1
    else:
        print(f"  FAIL: Stored {stored} values (expected 10)")

    values = [from_fp(buf[i]) for i in range(stored)]
    print(f"  First 5 values: {values[:5]}")

    # Verify first value matches single FLLogistic call
    total += 1
    single = lib.FLLogistic(to_fp(0.1), to_fp(2.0))
    if buf[0] == single:
        print(f"  PASS: First iterated value matches FLLogistic")
        passed += 1
    else:
        print(f"  FAIL: First iterated value {buf[0]} != FLLogistic {single}")

    # Test skip: 10 steps, skip 5 -> store 5
    total += 1
    buf2 = (ctypes.c_int32 * buf_size)()
    stored2 = lib.FLLogisticIterate(
        to_fp(0.1), to_fp(2.0),
        10, 5,
        ctypes.addressof(buf2), buf_size
    )
    if stored2 == 5:
        print(f"  PASS: With skip=5, stored {stored2} values (expected 5)")
        passed += 1
    else:
        print(f"  FAIL: With skip=5, stored {stored2} values (expected 5)")

    # Values after skip should match tail of full iteration
    total += 1
    match = True
    for i in range(min(stored2, 5)):
        if buf2[i] != buf[5 + i]:
            match = False
            print(f"  MISMATCH at index {i}: skip={buf2[i]}, full={buf[5+i]}")
    if match and stored2 == 5:
        print(f"  PASS: Skipped values match tail of full iteration")
        passed += 1
    else:
        print(f"  FAIL: Skipped values don't match")

    # Test bufSize limit
    total += 1
    buf3 = (ctypes.c_int32 * 3)()
    stored3 = lib.FLLogisticIterate(
        to_fp(0.1), to_fp(2.0),
        10, 0,
        ctypes.addressof(buf3), 3
    )
    if stored3 == 3:
        print(f"  PASS: Buffer limit respected, stored {stored3} (expected 3)")
        passed += 1
    else:
        print(f"  FAIL: Buffer limit, stored {stored3} (expected 3)")

    print(f"  Results: {passed}/{total} passed\n")
    return passed, total


def render_mandelbrot(lib):
    """Render a small ASCII Mandelbrot set for visual verification."""
    print("=== ASCII Mandelbrot Rendering (80x24) ===")
    width = 80
    height = 24
    max_iter = 50
    chars = " .:-=+*#%@"

    buf = (ctypes.c_int32 * width)()

    for row in range(height):
        y = 1.2 - row * 2.4 / height
        lib.FLMandelbrotRow(
            ctypes.addressof(buf), width,
            to_fp(y),
            to_fp(-2.5),
            to_fp(1.0),
            max_iter
        )
        line = ""
        for col in range(width):
            val = buf[col]
            if val == max_iter:
                line += " "
            else:
                idx = val % len(chars)
                line += chars[idx]
        print(line)
    print()


def main():
    lib = load_dll()

    total_passed = 0
    total_tests = 0

    p, t = test_mandelbrot_single(lib)
    total_passed += p
    total_tests += t

    p, t = test_julia_single(lib)
    total_passed += p
    total_tests += t

    p, t = test_mandelbrot_row(lib)
    total_passed += p
    total_tests += t

    p, t = test_julia_row(lib)
    total_passed += p
    total_tests += t

    p, t = test_logistic(lib)
    total_passed += p
    total_tests += t

    p, t = test_logistic_iterate(lib)
    total_passed += p
    total_tests += t

    print(f"{'='*50}")
    print(f"TOTAL: {total_passed}/{total_tests} tests passed")
    if total_passed == total_tests:
        print("ALL TESTS PASSED")
    else:
        print(f"FAILURES: {total_tests - total_passed}")
    print()

    render_mandelbrot(lib)


if __name__ == "__main__":
    main()
