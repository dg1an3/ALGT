"""trace_grafutil.py — Run GrafUtil.dll with procedure-level trace logging.

Usage: python trace_grafutil.py

Outputs CALL ProcName(args) -> result format for each DLL call,
comparable with a Prolog trace implementation.
"""
import ctypes
import os
import sys


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    func.restype = ctypes.c_int32
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "GrafUtil.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # --- Bitwise operations ---
    print("--- BitAnd ---")
    trace_call(lib, "GUBitAnd", 0xFF00, 0x0F0F)
    trace_call(lib, "GUBitAnd", -1, 0)

    print("--- BitOr ---")
    trace_call(lib, "GUBitOr", 0xFF00, 0x00FF)
    trace_call(lib, "GUBitOr", 0, 0)

    print("--- BitXor ---")
    trace_call(lib, "GUBitXor", 0xFF, 0xFF)
    trace_call(lib, "GUBitXor", 0xFF, 0x00)

    print("--- BitNot ---")
    trace_call(lib, "GUBitNot", 0)
    trace_call(lib, "GUBitNot", -1)

    print("--- BitShift ---")
    trace_call(lib, "GUBitShift", 1, 4)
    trace_call(lib, "GUBitShift", 256, -4)
    trace_call(lib, "GUBitShift", 42, 0)

    # --- Bit manipulation ---
    print("--- BitTst ---")
    trace_call(lib, "GUBitTst", 1, 0)
    trace_call(lib, "GUBitTst", 1, 1)
    trace_call(lib, "GUBitTst", 0xFF, 7)

    print("--- BitSet ---")
    trace_call(lib, "GUBitSet", 0, 0)
    trace_call(lib, "GUBitSet", 0, 3)
    trace_call(lib, "GUBitSet", 0xFF, 8)

    print("--- BitClr ---")
    trace_call(lib, "GUBitClr", 1, 0)
    trace_call(lib, "GUBitClr", 0xFF, 7)

    # --- 64-bit multiplication ---
    print("--- LongMul ---")
    trace_call(lib, "GULongMulHi", 3, 7)
    trace_call(lib, "GULongMulLo", 3, 7)
    trace_call(lib, "GULongMulHi", 100000, 100000)
    trace_call(lib, "GULongMulLo", 100000, 100000)

    # --- Fixed-point arithmetic ---
    print("--- FixMul ---")
    trace_call(lib, "GUFixMul", 65536, 65536)        # 1.0 * 1.0
    trace_call(lib, "GUFixMul", 2 * 65536, 3 * 65536)  # 2.0 * 3.0
    trace_call(lib, "GUFixMul", 32768, 32768)         # 0.5 * 0.5

    print("--- FixRatio ---")
    trace_call(lib, "GUFixRatio", 1, 1)
    trace_call(lib, "GUFixRatio", 1, 2)
    trace_call(lib, "GUFixRatio", 3, 4)
    trace_call(lib, "GUFixRatio", 1, 0)

    print("--- HiWord ---")
    trace_call(lib, "GUHiWord", 0x10000)
    trace_call(lib, "GUHiWord", 0x30000)
    trace_call(lib, "GUHiWord", -65536)

    print("--- LoWord ---")
    trace_call(lib, "GULoWord", 0x12345678)
    trace_call(lib, "GULoWord", 0xFFFF)
    trace_call(lib, "GULoWord", -1)

    print("--- FixRound ---")
    trace_call(lib, "GUFixRound", 65536)    # 1.0 -> 1
    trace_call(lib, "GUFixRound", 98304)    # 1.5 -> 2
    trace_call(lib, "GUFixRound", 32768)    # 0.5 -> 1
    trace_call(lib, "GUFixRound", 0)        # 0.0 -> 0
    trace_call(lib, "GUFixRound", -65536)   # -1.0 -> -1

    return 0


if __name__ == "__main__":
    sys.exit(main())
