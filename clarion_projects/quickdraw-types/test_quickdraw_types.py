import ctypes
import os
import sys


class QDPoint(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("v", ctypes.c_int32),  # vertical (y)
        ("h", ctypes.c_int32),  # horizontal (x)
    ]

    def __repr__(self):
        return f"QDPoint(v={self.v}, h={self.h})"


class QDRect(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("top", ctypes.c_int32),
        ("left", ctypes.c_int32),
        ("bottom", ctypes.c_int32),
        ("right", ctypes.c_int32),
    ]

    def __repr__(self):
        return f"QDRect(top={self.top}, left={self.left}, bottom={self.bottom}, right={self.right})"


def main():
    dll_path = os.path.join(os.getcwd(), "bin", "QuickDrawTypes.dll")
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

    def check(name, actual, expected):
        nonlocal passed, failed
        if actual == expected:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name} - expected {expected}, got {actual}")
            failed += 1

    # ---- QDSetPt ----
    print("=== QDSetPt ===")
    pt = QDPoint()
    lib.QDSetPt(ctypes.addressof(pt), 10, 20)
    check("SetPt(10,20).h", pt.h, 10)
    check("SetPt(10,20).v", pt.v, 20)

    pt2 = QDPoint()
    lib.QDSetPt(ctypes.addressof(pt2), -5, 100)
    check("SetPt(-5,100).h", pt2.h, -5)
    check("SetPt(-5,100).v", pt2.v, 100)

    # ---- QDEqualPt ----
    print("=== QDEqualPt ===")
    a = QDPoint()
    b = QDPoint()
    lib.QDSetPt(ctypes.addressof(a), 10, 20)
    lib.QDSetPt(ctypes.addressof(b), 10, 20)
    check("EqualPt same", lib.QDEqualPt(ctypes.addressof(a), ctypes.addressof(b)), 1)

    lib.QDSetPt(ctypes.addressof(b), 10, 21)
    check("EqualPt diff v", lib.QDEqualPt(ctypes.addressof(a), ctypes.addressof(b)), 0)

    lib.QDSetPt(ctypes.addressof(b), 11, 20)
    check("EqualPt diff h", lib.QDEqualPt(ctypes.addressof(a), ctypes.addressof(b)), 0)

    # ---- QDAddPt ----
    print("=== QDAddPt ===")
    src = QDPoint()
    dst = QDPoint()
    lib.QDSetPt(ctypes.addressof(src), 3, 4)
    lib.QDSetPt(ctypes.addressof(dst), 10, 20)
    lib.QDAddPt(ctypes.addressof(src), ctypes.addressof(dst))
    check("AddPt dst.h", dst.h, 13)
    check("AddPt dst.v", dst.v, 24)
    # src unchanged
    check("AddPt src.h unchanged", src.h, 3)
    check("AddPt src.v unchanged", src.v, 4)

    # Negative values
    lib.QDSetPt(ctypes.addressof(src), -5, -10)
    lib.QDSetPt(ctypes.addressof(dst), 20, 30)
    lib.QDAddPt(ctypes.addressof(src), ctypes.addressof(dst))
    check("AddPt neg dst.h", dst.h, 15)
    check("AddPt neg dst.v", dst.v, 20)

    # ---- QDSubPt ----
    print("=== QDSubPt ===")
    lib.QDSetPt(ctypes.addressof(src), 3, 4)
    lib.QDSetPt(ctypes.addressof(dst), 10, 20)
    lib.QDSubPt(ctypes.addressof(src), ctypes.addressof(dst))
    check("SubPt dst.h", dst.h, 7)
    check("SubPt dst.v", dst.v, 16)

    # ---- QDSetRect ----
    print("=== QDSetRect ===")
    r = QDRect()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    check("SetRect left", r.left, 10)
    check("SetRect top", r.top, 20)
    check("SetRect right", r.right, 100)
    check("SetRect bottom", r.bottom, 200)

    # Zero rect
    r2 = QDRect()
    lib.QDSetRect(ctypes.addressof(r2), 0, 0, 0, 0)
    check("SetRect zero left", r2.left, 0)
    check("SetRect zero top", r2.top, 0)

    # ---- QDEqualRect ----
    print("=== QDEqualRect ===")
    ra = QDRect()
    rb = QDRect()
    lib.QDSetRect(ctypes.addressof(ra), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(rb), 10, 20, 100, 200)
    check("EqualRect same", lib.QDEqualRect(ctypes.addressof(ra), ctypes.addressof(rb)), 1)

    lib.QDSetRect(ctypes.addressof(rb), 10, 20, 101, 200)
    check("EqualRect diff right", lib.QDEqualRect(ctypes.addressof(ra), ctypes.addressof(rb)), 0)

    # ---- QDEmptyRect ----
    print("=== QDEmptyRect ===")
    r = QDRect()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    check("EmptyRect normal", lib.QDEmptyRect(ctypes.addressof(r)), 0)

    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 20)  # bottom == top
    check("EmptyRect bottom==top", lib.QDEmptyRect(ctypes.addressof(r)), 1)

    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 10)  # bottom < top
    check("EmptyRect bottom<top", lib.QDEmptyRect(ctypes.addressof(r)), 1)

    lib.QDSetRect(ctypes.addressof(r), 10, 20, 10, 200)  # right == left
    check("EmptyRect right==left", lib.QDEmptyRect(ctypes.addressof(r)), 1)

    lib.QDSetRect(ctypes.addressof(r), 10, 20, 5, 200)  # right < left
    check("EmptyRect right<left", lib.QDEmptyRect(ctypes.addressof(r)), 1)

    # ---- QDOffsetRect ----
    print("=== QDOffsetRect ===")
    r = QDRect()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    lib.QDOffsetRect(ctypes.addressof(r), 5, 10)
    check("OffsetRect left", r.left, 15)
    check("OffsetRect top", r.top, 30)
    check("OffsetRect right", r.right, 105)
    check("OffsetRect bottom", r.bottom, 210)

    # Negative offset
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    lib.QDOffsetRect(ctypes.addressof(r), -3, -7)
    check("OffsetRect neg left", r.left, 7)
    check("OffsetRect neg top", r.top, 13)
    check("OffsetRect neg right", r.right, 97)
    check("OffsetRect neg bottom", r.bottom, 193)

    # ---- QDInsetRect ----
    print("=== QDInsetRect ===")
    r = QDRect()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    lib.QDInsetRect(ctypes.addressof(r), 5, 10)
    check("InsetRect left", r.left, 15)
    check("InsetRect top", r.top, 30)
    check("InsetRect right", r.right, 95)
    check("InsetRect bottom", r.bottom, 190)

    # Negative inset (grow)
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)
    lib.QDInsetRect(ctypes.addressof(r), -5, -10)
    check("InsetRect grow left", r.left, 5)
    check("InsetRect grow top", r.top, 10)
    check("InsetRect grow right", r.right, 105)
    check("InsetRect grow bottom", r.bottom, 210)

    # ---- QDSectRect (intersection) ----
    print("=== QDSectRect ===")
    r1 = QDRect()
    r2 = QDRect()
    rd = QDRect()

    # Overlapping rects
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(r2), 50, 80, 150, 250)
    result = lib.QDSectRect(ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    check("SectRect overlapping result", result, 1)
    check("SectRect left", rd.left, 50)
    check("SectRect top", rd.top, 80)
    check("SectRect right", rd.right, 100)
    check("SectRect bottom", rd.bottom, 200)

    # Non-overlapping rects
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 50, 60)
    lib.QDSetRect(ctypes.addressof(r2), 60, 70, 100, 120)
    result = lib.QDSectRect(ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    check("SectRect non-overlapping result", result, 0)

    # One rect inside another
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 200, 300)
    lib.QDSetRect(ctypes.addressof(r2), 50, 80, 100, 150)
    result = lib.QDSectRect(ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    check("SectRect contained result", result, 1)
    check("SectRect contained left", rd.left, 50)
    check("SectRect contained top", rd.top, 80)
    check("SectRect contained right", rd.right, 100)
    check("SectRect contained bottom", rd.bottom, 150)

    # ---- QDUnionRect ----
    print("=== QDUnionRect ===")
    lib.QDSetRect(ctypes.addressof(r1), 10, 20, 100, 200)
    lib.QDSetRect(ctypes.addressof(r2), 50, 80, 150, 250)
    lib.QDUnionRect(ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    check("UnionRect left", rd.left, 10)
    check("UnionRect top", rd.top, 20)
    check("UnionRect right", rd.right, 150)
    check("UnionRect bottom", rd.bottom, 250)

    # Disjoint rects
    lib.QDSetRect(ctypes.addressof(r1), 0, 0, 10, 10)
    lib.QDSetRect(ctypes.addressof(r2), 100, 100, 200, 200)
    lib.QDUnionRect(ctypes.addressof(r1), ctypes.addressof(r2), ctypes.addressof(rd))
    check("UnionRect disjoint left", rd.left, 0)
    check("UnionRect disjoint top", rd.top, 0)
    check("UnionRect disjoint right", rd.right, 200)
    check("UnionRect disjoint bottom", rd.bottom, 200)

    # ---- QDPtInRect ----
    print("=== QDPtInRect ===")
    pt = QDPoint()
    r = QDRect()
    lib.QDSetRect(ctypes.addressof(r), 10, 20, 100, 200)

    # Inside
    lib.QDSetPt(ctypes.addressof(pt), 50, 100)
    check("PtInRect inside", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 1)

    # On top-left corner (inclusive)
    lib.QDSetPt(ctypes.addressof(pt), 10, 20)
    check("PtInRect top-left", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 1)

    # On bottom-right corner (exclusive per QuickDraw convention)
    lib.QDSetPt(ctypes.addressof(pt), 100, 200)
    check("PtInRect bottom-right excl", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 0)

    # On right edge (exclusive)
    lib.QDSetPt(ctypes.addressof(pt), 50, 200)
    check("PtInRect right edge excl", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 0)

    # On bottom edge (exclusive)
    lib.QDSetPt(ctypes.addressof(pt), 100, 100)
    check("PtInRect bottom edge excl", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 0)

    # Outside
    lib.QDSetPt(ctypes.addressof(pt), 5, 300)
    check("PtInRect outside", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 0)

    # Just inside bottom-right
    lib.QDSetPt(ctypes.addressof(pt), 99, 199)
    check("PtInRect just inside", lib.QDPtInRect(ctypes.addressof(pt), ctypes.addressof(r)), 1)

    # ---- Summary ----
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    if failed == 0:
        print("ALL TESTS PASSED")
    return 1 if failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
