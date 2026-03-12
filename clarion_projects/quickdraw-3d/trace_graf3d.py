"""trace_graf3d.py — Run Graf3D.dll with procedure-level trace logging.

Usage: python trace_graf3d.py

Outputs CALL ProcName(args) -> result format for each DLL call,
comparable with a Prolog trace (trace_graf3d.pl).

Based on Apple Graf3D.p (1983) — 3D point and matrix operations.
Fixed-point convention: REAL * 10000.
"""
import ctypes
import os
import sys


FP = 10000


def fp(val):
    """Convert a float to fixed-point LONG."""
    return int(round(val * FP))


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "Graf3D.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # --- Init ---
    print("--- Init ---")
    trace_call(lib, "G3Init")

    # --- Identity matrix check ---
    print("--- Identity matrix diagonal ---")
    for i in range(16):
        trace_call(lib, "G3GetMatrix", i)

    # --- SetPt / GetPt ---
    print("--- SetPt / GetPt ---")
    trace_call(lib, "G3SetPt", fp(1.5), fp(-2.75), fp(3.0))
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Scale ---
    print("--- Scale ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Scale", fp(2.0), fp(3.0), fp(4.0))
    trace_call(lib, "G3SetPt", fp(1.0), fp(1.0), fp(1.0))
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Translate ---
    print("--- Translate ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Translate", fp(5.0), fp(10.0), fp(15.0))
    trace_call(lib, "G3SetPt", 0, 0, 0)
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Pitch 90 ---
    print("--- Pitch 90 ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Pitch", fp(90.0))
    trace_call(lib, "G3SetPt", 0, fp(1.0), 0)
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Yaw 90 ---
    print("--- Yaw 90 ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Yaw", fp(90.0))
    trace_call(lib, "G3SetPt", fp(1.0), 0, 0)
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Roll 90 ---
    print("--- Roll 90 ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Roll", fp(90.0))
    trace_call(lib, "G3SetPt", fp(1.0), 0, 0)
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    # --- Combined: Scale + Translate ---
    print("--- Combined: Scale + Translate ---")
    trace_call(lib, "G3Init")
    trace_call(lib, "G3Scale", fp(2.0), fp(2.0), fp(2.0))
    trace_call(lib, "G3Translate", fp(10.0), 0, 0)
    trace_call(lib, "G3SetPt", fp(1.0), 0, 0)
    trace_call(lib, "G3Transform")
    trace_call(lib, "G3GetPtX")
    trace_call(lib, "G3GetPtY")
    trace_call(lib, "G3GetPtZ")

    return 0


if __name__ == "__main__":
    sys.exit(main())
