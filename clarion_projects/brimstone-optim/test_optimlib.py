"""Tests for OptimLib - Brent line search and Conjugate Gradient optimizer.

Tests the step-by-step optimization API with known test functions:
- Brent: minimizes f(x) = (x-3)^2 + 1, minimum at x=3, f=1
- Brent: minimizes f(x) = sin(x) on [2,5], minimum near x=4.712 (3*pi/2)
- CG: minimizes Rosenbrock f(x,y) = (1-x)^2 + 100*(y-x^2)^2, min at (1,1)
- CG: minimizes simple quadratic f(x,y) = x^2 + 4*y^2, min at (0,0)
"""
import ctypes
import os
import sys
import math


def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "OptimLib.dll")
    if not os.path.exists(dll_path):
        print(f"DLL not found: {dll_path}")
        return 1

    lib = ctypes.CDLL(dll_path)

    # Configure return types
    for fn in ['BrentCreate', 'BrentFree', 'BrentSetBracket', 'BrentStep',
               'BrentSetFValue', 'BrentGetIter',
               'CGCreate', 'CGFree', 'CGSetInitial', 'CGStep',
               'CGSetFValue', 'CGSetGrad', 'CGGetIter']:
        getattr(lib, fn).restype = ctypes.c_long

    for fn in ['BrentGetEvalX', 'BrentGetMinX', 'BrentGetMinF',
               'CGGetEvalX', 'CGGetResult', 'CGGetMinF']:
        getattr(lib, fn).restype = ctypes.c_double

    passed = 0
    failed = 0

    def check(name, actual, expected, tol=1e-4):
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

    STAT_NEED_FEVAL = 1
    STAT_NEED_GEVAL = 2
    STAT_DONE = 3

    # =========================================================================
    print("=== Brent: Quadratic f(x) = (x-3)^2 + 1 ===")

    def quadratic(x):
        return (x - 3.0) ** 2 + 1.0

    h = lib.BrentCreate(ctypes.c_double(1e-8))
    check("BrentCreate", h > 0, True)

    lib.BrentSetBracket(h, ctypes.c_double(0.0), ctypes.c_double(5.0))

    max_steps = 200
    for step in range(max_steps):
        status = lib.BrentStep(h)
        if status == STAT_DONE:
            break
        elif status == STAT_NEED_FEVAL:
            x = lib.BrentGetEvalX(h)
            fx = quadratic(x)
            lib.BrentSetFValue(h, ctypes.c_double(fx))
        else:
            print(f"  Unexpected status: {status}")
            break

    min_x = lib.BrentGetMinX(h)
    min_f = lib.BrentGetMinF(h)
    iters = lib.BrentGetIter(h)
    check_near("Brent min x", min_x, 3.0, 1e-4)
    check_near("Brent min f", min_f, 1.0, 1e-4)
    print(f"  Info: converged in {iters} iterations")
    lib.BrentFree(h)

    # =========================================================================
    print("\n=== Brent: sin(x) on [2, 5] ===")

    h = lib.BrentCreate(ctypes.c_double(1e-8))
    lib.BrentSetBracket(h, ctypes.c_double(2.0), ctypes.c_double(5.0))

    for step in range(max_steps):
        status = lib.BrentStep(h)
        if status == STAT_DONE:
            break
        elif status == STAT_NEED_FEVAL:
            x = lib.BrentGetEvalX(h)
            fx = math.sin(x)
            lib.BrentSetFValue(h, ctypes.c_double(fx))

    min_x = lib.BrentGetMinX(h)
    min_f = lib.BrentGetMinF(h)
    # sin has minimum at 3*pi/2 ≈ 4.71239
    check_near("Brent sin min x", min_x, 3 * math.pi / 2, 1e-3)
    check_near("Brent sin min f", min_f, -1.0, 1e-4)
    lib.BrentFree(h)

    # =========================================================================
    print("\n=== CG: Simple Quadratic f(x,y) = x^2 + 4*y^2 ===")

    def simple_quad(x, y):
        return x * x + 4.0 * y * y

    def simple_quad_grad(x, y):
        return (2.0 * x, 8.0 * y)

    h = lib.CGCreate(2, ctypes.c_double(1e-10))
    check("CGCreate", h > 0, True)

    # Start at (3, 2)
    lib.CGSetInitial(h, 1, ctypes.c_double(3.0))
    lib.CGSetInitial(h, 2, ctypes.c_double(2.0))

    for step in range(1000):
        status = lib.CGStep(h)
        if status == STAT_DONE:
            break
        elif status == STAT_NEED_FEVAL:
            x = lib.CGGetEvalX(h, 1)
            y = lib.CGGetEvalX(h, 2)
            fx = simple_quad(x, y)
            lib.CGSetFValue(h, ctypes.c_double(fx))
        elif status == STAT_NEED_GEVAL:
            x = lib.CGGetEvalX(h, 1)
            y = lib.CGGetEvalX(h, 2)
            gx, gy = simple_quad_grad(x, y)
            lib.CGSetGrad(h, 1, ctypes.c_double(gx))
            lib.CGSetGrad(h, 2, ctypes.c_double(gy))
        else:
            print(f"  Unexpected status: {status}")
            break

    rx = lib.CGGetResult(h, 1)
    ry = lib.CGGetResult(h, 2)
    rf = lib.CGGetMinF(h)
    iters = lib.CGGetIter(h)
    check_near("CG quad x", rx, 0.0, 0.01)
    check_near("CG quad y", ry, 0.0, 0.01)
    check_near("CG quad f", rf, 0.0, 0.01)
    print(f"  Info: converged in {iters} iterations")
    lib.CGFree(h)

    # =========================================================================
    print("\n=== CG: Rosenbrock f(x,y) = (1-x)^2 + 100*(y-x^2)^2 ===")

    def rosenbrock(x, y):
        return (1.0 - x) ** 2 + 100.0 * (y - x * x) ** 2

    def rosenbrock_grad(x, y):
        gx = -2.0 * (1.0 - x) - 400.0 * x * (y - x * x)
        gy = 200.0 * (y - x * x)
        return (gx, gy)

    h = lib.CGCreate(2, ctypes.c_double(1e-12))

    # Start at (-1, 1)
    lib.CGSetInitial(h, 1, ctypes.c_double(-1.0))
    lib.CGSetInitial(h, 2, ctypes.c_double(1.0))

    for step in range(10000):
        status = lib.CGStep(h)
        if status == STAT_DONE:
            break
        elif status == STAT_NEED_FEVAL:
            x = lib.CGGetEvalX(h, 1)
            y = lib.CGGetEvalX(h, 2)
            fx = rosenbrock(x, y)
            lib.CGSetFValue(h, ctypes.c_double(fx))
        elif status == STAT_NEED_GEVAL:
            x = lib.CGGetEvalX(h, 1)
            y = lib.CGGetEvalX(h, 2)
            gx, gy = rosenbrock_grad(x, y)
            lib.CGSetGrad(h, 1, ctypes.c_double(gx))
            lib.CGSetGrad(h, 2, ctypes.c_double(gy))

    rx = lib.CGGetResult(h, 1)
    ry = lib.CGGetResult(h, 2)
    rf = lib.CGGetMinF(h)
    iters = lib.CGGetIter(h)
    # Rosenbrock is hard — allow wider tolerance
    check_near("CG Rosenbrock x", rx, 1.0, 0.1)
    check_near("CG Rosenbrock y", ry, 1.0, 0.1)
    check_near("CG Rosenbrock f", rf, 0.0, 0.1)
    print(f"  Info: converged in {iters} iterations")
    lib.CGFree(h)

    # =========================================================================
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
