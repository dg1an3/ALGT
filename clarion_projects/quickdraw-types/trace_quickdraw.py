"""trace_quickdraw.py — Run QuickDrawTypes DLL with procedure-level trace logging.

Usage: python trace_quickdraw.py

Outputs CALL ProcName(args) -> result format for each DLL call,
comparable with trace_quickdraw.pl (Prolog version).
"""
import ctypes
import os
import sys


class QDPoint(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("v", ctypes.c_int32),
        ("h", ctypes.c_int32),
    ]

    def __repr__(self):
        return f"point(v={self.v}, h={self.h})"


class QDRect(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("top", ctypes.c_int32),
        ("left", ctypes.c_int32),
        ("bottom", ctypes.c_int32),
        ("right", ctypes.c_int32),
    ]

    def __repr__(self):
        return f"rect(top={self.top}, left={self.left}, bottom={self.bottom}, right={self.right})"


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "QuickDrawTypes.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # --- SetPt ---
    print("--- SetPt ---")
    pt = QDPoint()
    trace_call(lib, "QDSetPt", ctypes.addressof(pt), 10, 20)
    print(f"  result: {pt}")

    # --- EqualPt ---
    print("--- EqualPt ---")
    a = QDPoint()
    b = QDPoint()
    lib.QDSetPt(ctypes.addressof(a), 10, 20)
    lib.QDSetPt(ctypes.addressof(b), 10, 20)
    trace_call(lib, "QDEqualPt", ctypes.addressof(a), ctypes.addressof(b))
    lib.QDSetPt(ctypes.addressof(b), 10, 21)
    trace_call(lib, "QDEqualPt", ctypes.addressof(a), ctypes.addressof(b))

    # --- AddPt ---
    print("--- AddPt ---")
    src = QDPoint()
    dst = QDPoint()
    lib.QDSetPt(ctypes.addressof(src), 3, 4)
    lib.QDSetPt(ctypes.addressof(dst), 10, 20)
    trace_call(lib, "QDAddPt", ctypes.addressof(src), ctypes.addressof(dst))
    print(f"  dst after AddPt: {dst}")

    # --- SubPt ---
    print("--- SubPt ---")
    lib.QDSetPt(ctypes.addressof(src), 3, 4)
    lib.QDSetPt(ctypes.addressof(dst), 10, 20)
    trace_call(lib, "QDSubPt", ctypes.addressof(src), ctypes.addressof(dst))
    print(f"  dst after SubPt: {dst}")

    # --- SetRect ---
    print("--- SetRect ---")
    r = QDRect()
    trace_call(lib, "QDSetRect", ctypes.addressof(r), 10, 20, 100, 200)
    print(f"  result: {r}")

    # --- EqualRect ---
    print("--- EqualRect ---")
    ra = QDRect()
    rb = QDRect()
    lib.QDSetRect(ctypes.addressof(ra), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(rb), 10, 20, 100, 200)
    trace_call(lib, "QDEqualRect", ctypes.addressof(ra), ctypes.addressof(rb))
    lib.QDSetRect(ctypes.addressof(rb), 10, 20, 101, 200)
    trace_call(lib, "QDEqualRect", ctypes.addressof(ra), ctypes.addressof(rb))

    # --- EmptyRect ---
    print("--- EmptyRect ---")
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    trace_call(lib, "QDEmptyRect", ctypes.addressof(r))
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 20)
    trace_call(lib, "QDEmptyRect", ctypes.addressof(r))

    # --- OffsetRect ---
    print("--- OffsetRect ---")
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    trace_call(lib, "QDOffsetRect", ctypes.addressof(r), 5, 10)
    print(f"  result: {r}")

    # --- InsetRect ---
    print("--- InsetRect ---")
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    trace_call(lib, "QDInsetRect", ctypes.addressof(r), 5, 10)
    print(f"  result: {r}")

    # --- SectRect ---
    print("--- SectRect ---")
    r1 = QDRect()
    r2 = QDRect()
    rd = QDRect()
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(r2), 50, 80, 150, 250)
    trace_call(lib, "QDSectRect",
               ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    print(f"  intersection: {rd}")

    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 50, 60)
    lib.QDSetRect(ctypes.addressof(r2), 60, 70, 100, 120)
    trace_call(lib, "QDSectRect",
               ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))

    # --- UnionRect ---
    print("--- UnionRect ---")
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(r2), 50, 80, 150, 250)
    trace_call(lib, "QDUnionRect",
               ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    print(f"  union: {rd}")

    # --- PtInRect ---
    print("--- PtInRect ---")
    pt = QDPoint()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)

    lib.QDSetPt(ctypes.addressof(pt), 50, 100)
    trace_call(lib, "QDPtInRect", ctypes.addressof(pt), ctypes.addressof(r))

    lib.QDSetPt(ctypes.addressof(pt), 100, 200)
    trace_call(lib, "QDPtInRect", ctypes.addressof(pt), ctypes.addressof(r))

    lib.QDSetPt(ctypes.addressof(pt), 10, 20)
    trace_call(lib, "QDPtInRect", ctypes.addressof(pt), ctypes.addressof(r))

    return 0


if __name__ == "__main__":
    sys.exit(main())
