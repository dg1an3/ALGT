"""test_grafutil.py — Comprehensive tests for GrafUtil.dll (Apple GrafUtil.p in Clarion).

Tests bitwise operations, bit manipulation, 64-bit multiplication,
and 16.16 fixed-point arithmetic.

Usage:
    python test_grafutil.py
    (requires 32-bit Python for 32-bit Clarion DLL)
"""
import ctypes
import os
import sys


def to_signed32(val):
    """Convert an unsigned 32-bit value to signed 32-bit."""
    val = val & 0xFFFFFFFF
    if val >= 0x80000000:
        return val - 0x100000000
    return val


def to_fixed(f):
    """Convert a float to 16.16 fixed-point (signed 32-bit)."""
    return to_signed32(int(round(f * 65536)))


def from_fixed(x):
    """Convert 16.16 fixed-point to float."""
    return x / 65536.0


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "GrafUtil.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return 1

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return 1

    # Set up all function signatures (all return c_int32, params c_int32)
    for name in ["GUBitAnd", "GUBitOr", "GUBitXor", "GUBitNot",
                  "GUBitShift", "GUBitTst", "GUBitSet", "GUBitClr",
                  "GULongMulHi", "GULongMulLo",
                  "GUFixMul", "GUFixRatio", "GUHiWord", "GULoWord", "GUFixRound"]:
        func = getattr(lib, name)
        func.restype = ctypes.c_int32

    passed = 0
    failed = 0

    def check(name, actual, expected):
        nonlocal passed, failed
        if actual == expected:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name} - expected {expected} (0x{expected & 0xFFFFFFFF:08X}), "
                  f"got {actual} (0x{actual & 0xFFFFFFFF:08X})")
            failed += 1

    def check_approx(name, actual, expected, tolerance=1):
        """Check with tolerance for fixed-point rounding."""
        nonlocal passed, failed
        if abs(actual - expected) <= tolerance:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name} - expected {expected}, got {actual} (diff={actual-expected})")
            failed += 1

    # ==== BitAnd ====
    print("=== GUBitAnd ===")
    check("BitAnd(0xFF00, 0x0F0F)", lib.GUBitAnd(0xFF00, 0x0F0F), to_signed32(0x0F00))
    check("BitAnd(0xFFFFFFFF, 0x0)", lib.GUBitAnd(-1, 0), 0)
    check("BitAnd(0xFFFFFFFF, 0xFFFFFFFF)", lib.GUBitAnd(-1, -1), -1)
    check("BitAnd(0x12345678, 0xF0F0F0F0)",
          lib.GUBitAnd(0x12345678, to_signed32(0xF0F0F0F0)),
          to_signed32(0x10305070))
    check("BitAnd(0, 0)", lib.GUBitAnd(0, 0), 0)

    # ==== BitOr ====
    print("=== GUBitOr ===")
    check("BitOr(0xFF00, 0x00FF)", lib.GUBitOr(to_signed32(0xFF00), 0x00FF), to_signed32(0xFFFF))
    check("BitOr(0, 0)", lib.GUBitOr(0, 0), 0)
    check("BitOr(0xA0, 0x05)", lib.GUBitOr(0xA0, 0x05), to_signed32(0xA5))
    check("BitOr(0, -1)", lib.GUBitOr(0, -1), -1)

    # ==== BitXor ====
    print("=== GUBitXor ===")
    check("BitXor(0xFF, 0xFF)", lib.GUBitXor(0xFF, 0xFF), 0)
    check("BitXor(0xFF, 0x00)", lib.GUBitXor(0xFF, 0x00), 0xFF)
    check("BitXor(0xAAAA, 0x5555)", lib.GUBitXor(0xAAAA, 0x5555), to_signed32(0xFFFF))
    check("BitXor(-1, -1)", lib.GUBitXor(-1, -1), 0)
    check("BitXor(-1, 0)", lib.GUBitXor(-1, 0), -1)

    # ==== BitNot ====
    print("=== GUBitNot ===")
    check("BitNot(0)", lib.GUBitNot(0), -1)
    check("BitNot(-1)", lib.GUBitNot(-1), 0)
    check("BitNot(0x0F0F0F0F)", lib.GUBitNot(0x0F0F0F0F), to_signed32(0xF0F0F0F0))
    check("BitNot(1)", lib.GUBitNot(1), to_signed32(0xFFFFFFFE))

    # ==== BitShift ====
    print("=== GUBitShift ===")
    # Shift left (positive count)
    check("BitShift(1, 0)", lib.GUBitShift(1, 0), 1)
    check("BitShift(1, 1)", lib.GUBitShift(1, 1), 2)
    check("BitShift(1, 4)", lib.GUBitShift(1, 4), 16)
    check("BitShift(1, 31)", lib.GUBitShift(1, 31), to_signed32(0x80000000))
    check("BitShift(0xFF, 8)", lib.GUBitShift(0xFF, 8), to_signed32(0xFF00))
    # Shift right (negative count)
    check("BitShift(256, -4)", lib.GUBitShift(256, -4), 16)
    check("BitShift(0xFF00, -8)", lib.GUBitShift(to_signed32(0xFF00), -8), 0xFF)
    check("BitShift(16, -4)", lib.GUBitShift(16, -4), 1)
    # Shift by 0 is identity
    check("BitShift(42, 0)", lib.GUBitShift(42, 0), 42)

    # ==== BitTst ====
    print("=== GUBitTst ===")
    check("BitTst(1, 0)", lib.GUBitTst(1, 0), 1)
    check("BitTst(1, 1)", lib.GUBitTst(1, 1), 0)
    check("BitTst(0xFF, 7)", lib.GUBitTst(0xFF, 7), 1)
    check("BitTst(0x80, 7)", lib.GUBitTst(0x80, 7), 1)
    check("BitTst(0x80, 6)", lib.GUBitTst(0x80, 6), 0)
    check("BitTst(0, 0)", lib.GUBitTst(0, 0), 0)
    check("BitTst(0, 31)", lib.GUBitTst(0, 31), 0)
    check("BitTst(-1, 31)", lib.GUBitTst(-1, 31), 1)

    # ==== BitSet ====
    print("=== GUBitSet ===")
    check("BitSet(0, 0)", lib.GUBitSet(0, 0), 1)
    check("BitSet(0, 3)", lib.GUBitSet(0, 3), 8)
    check("BitSet(0xFF, 8)", lib.GUBitSet(0xFF, 8), to_signed32(0x1FF))
    check("BitSet(1, 0)", lib.GUBitSet(1, 0), 1)  # already set
    check("BitSet(0, 31)", lib.GUBitSet(0, 31), to_signed32(0x80000000))

    # ==== BitClr ====
    print("=== GUBitClr ===")
    check("BitClr(1, 0)", lib.GUBitClr(1, 0), 0)
    check("BitClr(0xFF, 0)", lib.GUBitClr(0xFF, 0), to_signed32(0xFE))
    check("BitClr(0xFF, 7)", lib.GUBitClr(0xFF, 7), 0x7F)
    check("BitClr(0, 0)", lib.GUBitClr(0, 0), 0)  # already clear
    check("BitClr(-1, 31)", lib.GUBitClr(-1, 31), to_signed32(0x7FFFFFFF))

    # ==== LongMulHi / LongMulLo ====
    print("=== GULongMulHi / GULongMulLo ===")
    # Simple: 3 * 7 = 21, fits in low word, high = 0
    check("LongMulHi(3, 7)", lib.GULongMulHi(3, 7), 0)
    check("LongMulLo(3, 7)", lib.GULongMulLo(3, 7), 21)

    # Multiply by 0
    check("LongMulHi(12345, 0)", lib.GULongMulHi(12345, 0), 0)
    check("LongMulLo(12345, 0)", lib.GULongMulLo(12345, 0), 0)

    # Multiply by 1
    check("LongMulHi(12345, 1)", lib.GULongMulHi(12345, 1), 0)
    check("LongMulLo(12345, 1)", lib.GULongMulLo(12345, 1), 12345)

    # Larger product: 100000 * 100000 = 10,000,000,000 (0x2_540BE400)
    check("LongMulHi(100000, 100000)", lib.GULongMulHi(100000, 100000), 2)
    check("LongMulLo(100000, 100000)", lib.GULongMulLo(100000, 100000),
          to_signed32(0x540BE400))

    # ==== FixMul ====
    print("=== GUFixMul ===")
    # 1.0 * 1.0 = 1.0  (65536 * 65536 / 65536 = 65536)
    check("FixMul(1.0, 1.0)", lib.GUFixMul(65536, 65536), 65536)

    # 2.0 * 3.0 = 6.0
    check("FixMul(2.0, 3.0)", lib.GUFixMul(2 * 65536, 3 * 65536), 6 * 65536)

    # 1.5 * 2.0 = 3.0  (1.5 = 98304 in 16.16)
    check("FixMul(1.5, 2.0)", lib.GUFixMul(98304, 2 * 65536), 3 * 65536)

    # 0.5 * 0.5 = 0.25  (32768 * 32768 / 65536 = 16384)
    check("FixMul(0.5, 0.5)", lib.GUFixMul(32768, 32768), 16384)

    # Multiply by 0
    check("FixMul(42.0, 0)", lib.GUFixMul(42 * 65536, 0), 0)

    # Negative: -1.0 * 2.0 = -2.0
    check("FixMul(-1.0, 2.0)", lib.GUFixMul(-65536, 2 * 65536), -2 * 65536)

    # ==== FixRatio ====
    print("=== GUFixRatio ===")
    # 1/1 = 1.0 = 65536
    check("FixRatio(1, 1)", lib.GUFixRatio(1, 1), 65536)

    # 1/2 = 0.5 = 32768
    check("FixRatio(1, 2)", lib.GUFixRatio(1, 2), 32768)

    # 3/4 = 0.75 = 49152
    check("FixRatio(3, 4)", lib.GUFixRatio(3, 4), 49152)

    # 10/1 = 10.0
    check("FixRatio(10, 1)", lib.GUFixRatio(10, 1), 10 * 65536)

    # -1/2 = -0.5 = -32768
    check("FixRatio(-1, 2)", lib.GUFixRatio(-1, 2), -32768)

    # 1/3 ~ 0.333... = 21845 (truncated)
    check_approx("FixRatio(1, 3)", lib.GUFixRatio(1, 3), 21845, tolerance=1)

    # Division by 0 -> max positive
    check("FixRatio(1, 0)", lib.GUFixRatio(1, 0), to_signed32(0x7FFFFFFF))

    # Division by 0 with negative numer -> max negative
    check("FixRatio(-1, 0)", lib.GUFixRatio(-1, 0), to_signed32(0x80000001))

    # ==== HiWord ====
    print("=== GUHiWord ===")
    # HiWord(0x00010000) = 1 (1.0 in fixed-point)
    check("HiWord(0x10000)", lib.GUHiWord(0x10000), 1)

    # HiWord(0x00030000) = 3
    check("HiWord(0x30000)", lib.GUHiWord(0x30000), 3)

    # HiWord(0x00008000) = 0 (0.5 in fixed-point, integer part is 0)
    check("HiWord(0x8000)", lib.GUHiWord(0x8000), 0)

    # HiWord(0) = 0
    check("HiWord(0)", lib.GUHiWord(0), 0)

    # HiWord of negative: -1.0 = 0xFFFF0000 -> HiWord = -1 (arithmetic shift)
    check("HiWord(-65536)", lib.GUHiWord(-65536), -1)

    # ==== LoWord ====
    print("=== GULoWord ===")
    # LoWord(0x12345678) = 0x5678
    check("LoWord(0x12345678)", lib.GULoWord(0x12345678), 0x5678)

    # LoWord(0x10000) = 0
    check("LoWord(0x10000)", lib.GULoWord(0x10000), 0)

    # LoWord(0x0000FFFF) = 0xFFFF = 65535
    check("LoWord(0xFFFF)", lib.GULoWord(0xFFFF), 0xFFFF)

    # LoWord(0) = 0
    check("LoWord(0)", lib.GULoWord(0), 0)

    # LoWord(-1) = 0xFFFF = 65535
    check("LoWord(-1)", lib.GULoWord(-1), 0xFFFF)

    # ==== FixRound ====
    print("=== GUFixRound ===")
    # 1.0 -> 1
    check("FixRound(1.0)", lib.GUFixRound(65536), 1)

    # 1.5 -> 2 (rounds up)
    check("FixRound(1.5)", lib.GUFixRound(98304), 2)

    # 1.4999 -> 1 (rounds down)
    check("FixRound(1.4999)", lib.GUFixRound(98302), 1)

    # 0.5 -> 1
    check("FixRound(0.5)", lib.GUFixRound(32768), 1)

    # 0.0 -> 0
    check("FixRound(0)", lib.GUFixRound(0), 0)

    # 0.25 -> 0
    check("FixRound(0.25)", lib.GUFixRound(16384), 0)

    # -1.0 -> -1
    check("FixRound(-1.0)", lib.GUFixRound(-65536), -1)

    # ---- Summary ----
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    if failed == 0:
        print("ALL TESTS PASSED")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
