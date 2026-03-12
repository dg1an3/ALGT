"""trace_fractal.py — Run FractalLib DLL with procedure-level trace logging.

Usage: python trace_fractal.py

Outputs the same procedure-level trace format as trace_fractal.pl
so the two can be compared with diff.

Note: Row procedures (FLMandelbrotRow, FLJuliaRow) and FLLogisticIterate
use buffer pointers which are not comparable across DLL/Prolog, so only
the scalar procedures are traced here.
"""
import ctypes
import os
import sys


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def to_fp(val):
    """Convert float to fixed-point (multiply by 10000)."""
    return int(val * 10000)


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "FractalLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        print("Build with: MSBuild.exe FractalLib.cwproj", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # --- Mandelbrot single-point tests ---
    # (0, 0) -> in set, maxIter=100
    trace_call(lib, "FLMandelbrot", 0, 0, 100)

    # (2.0, 0) -> escapes at iteration 2
    trace_call(lib, "FLMandelbrot", to_fp(2.0), 0, 100)

    # (1.0, 0) -> escapes at iteration 3
    trace_call(lib, "FLMandelbrot", to_fp(1.0), 0, 100)

    # (-1.0, 0) -> in set
    trace_call(lib, "FLMandelbrot", to_fp(-1.0), 0, 100)

    # (10.0, 0) -> escapes at iteration 1
    trace_call(lib, "FLMandelbrot", to_fp(10.0), 0, 100)

    # --- Julia single-point tests ---
    # z=(0,0), c=(-0.7, 0.27015) -> in set
    # Note: 0.27015 truncated to 0.2702 in fixed-point (2702)
    trace_call(lib, "FLJulia", 0, 0, -7000, 2702, 100)

    # z=(2.0,0), c=(-0.7, 0.27015) -> escapes quickly
    trace_call(lib, "FLJulia", to_fp(2.0), 0, -7000, 2702, 100)

    # --- Logistic map tests ---
    # p=0.5, k=1.0 -> p_new = 0.75 -> 7500
    trace_call(lib, "FLLogistic", to_fp(0.5), to_fp(1.0))

    # p=0.1, k=2.0 -> p_new = 0.28 -> 2800
    trace_call(lib, "FLLogistic", to_fp(0.1), to_fp(2.0))

    # p=0.0, k=2.5 -> 0 (fixed point)
    trace_call(lib, "FLLogistic", 0, to_fp(2.5))

    return 0


if __name__ == "__main__":
    sys.exit(main())
