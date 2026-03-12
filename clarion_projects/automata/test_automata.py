"""Tests for AutomataLib — 1D cellular automaton DLL."""

import ctypes
import os
import sys

SIZE = 640  # cell indices 0..640

def load_lib():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "AutomataLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        sys.exit(1)
    lib = ctypes.CDLL(dll_path)
    # Set up argtypes / restypes
    lib.CAInit.restype = ctypes.c_int32
    lib.CAInit.argtypes = []
    lib.CASetRule.restype = ctypes.c_int32
    lib.CASetRule.argtypes = [ctypes.c_int32, ctypes.c_int32]
    lib.CAGetRule.restype = ctypes.c_int32
    lib.CAGetRule.argtypes = [ctypes.c_int32]
    lib.CASetCell.restype = ctypes.c_int32
    lib.CASetCell.argtypes = [ctypes.c_int32, ctypes.c_int32]
    lib.CAGetCell.restype = ctypes.c_int32
    lib.CAGetCell.argtypes = [ctypes.c_int32]
    lib.CAStep.restype = ctypes.c_int32
    lib.CAStep.argtypes = []
    lib.CASpatialEntropy.restype = ctypes.c_int32
    lib.CASpatialEntropy.argtypes = []
    lib.CATemporalEntropy.restype = ctypes.c_int32
    lib.CATemporalEntropy.argtypes = [ctypes.c_int32]
    lib.CASetRuleFromHex.restype = ctypes.c_int32
    lib.CASetRuleFromHex.argtypes = [ctypes.c_int32, ctypes.c_int32]
    lib.CAGetCellCount.restype = ctypes.c_int32
    lib.CAGetCellCount.argtypes = [ctypes.c_int32]
    return lib


def test_init_and_get_set(lib):
    """Test basic init, set/get for cells and rules."""
    print("=== Test: Init and Get/Set ===")
    assert lib.CAInit() == 0, "CAInit failed"

    # All cells should be 0
    for i in [0, 1, 320, SIZE]:
        assert lib.CAGetCell(i) == 0, f"Cell {i} not zero after init"

    # Set and get a cell
    assert lib.CASetCell(320, 5) == 0
    assert lib.CAGetCell(320) == 5, f"Expected 5, got {lib.CAGetCell(320)}"

    # Set and get a rule
    assert lib.CASetRule(10, 3) == 0
    assert lib.CAGetRule(10) == 3, f"Expected 3, got {lib.CAGetRule(10)}"

    # Out of range
    assert lib.CASetRule(50, 0) == -1, "Expected -1 for rule index 50"
    assert lib.CASetCell(-1, 0) == -1, "Expected -1 for cell index -1"

    print("  PASSED")


def test_identity_rule(lib):
    """Identity rule: rule[sum] = sum (clamped). With a single seed cell=1,
    the automaton should spread the values according to sum logic."""
    print("=== Test: Identity Rule (single step, single seed) ===")
    lib.CAInit()

    # Identity rule: rule[i] = i for i in 0..15, then i for 16..48 clamped to 15
    for i in range(49):
        lib.CASetRule(i, min(i, 15))

    # Set a single seed at center
    lib.CASetCell(320, 1)

    # Before step: cell 320 = 1, neighbors are 0
    lib.CAStep()

    # After one step:
    # cell 319: sum = cells[318]+cells[319]+cells[320] = 0+0+1 = 1 -> rule[1] = 1
    # cell 320: sum = cells[319]+cells[320]+cells[321] = 0+1+0 = 1 -> rule[1] = 1
    # cell 321: sum = cells[320]+cells[321]+cells[322] = 1+0+0 = 1 -> rule[1] = 1
    # cell 0: sum = 0 -> rule[0] = 0
    assert lib.CAGetCell(319) == 1, f"Expected 1 at 319, got {lib.CAGetCell(319)}"
    assert lib.CAGetCell(320) == 1, f"Expected 1 at 320, got {lib.CAGetCell(320)}"
    assert lib.CAGetCell(321) == 1, f"Expected 1 at 321, got {lib.CAGetCell(321)}"
    assert lib.CAGetCell(318) == 0, f"Expected 0 at 318, got {lib.CAGetCell(318)}"
    assert lib.CAGetCell(322) == 0, f"Expected 0 at 322, got {lib.CAGetCell(322)}"

    print("  PASSED")


def test_multi_step(lib):
    """Run multiple steps with identity rule and verify spread pattern."""
    print("=== Test: Multi-step spread ===")
    lib.CAInit()

    for i in range(49):
        lib.CASetRule(i, min(i, 15))

    lib.CASetCell(320, 1)

    # Step 1: cells 319,320,321 = 1
    lib.CAStep()
    # Step 2: cell 318: sum=0+0+1=1->1, cell 319: sum=0+1+1=2->2,
    #          cell 320: sum=1+1+1=3->3, cell 321: sum=1+1+0=2->2, cell 322: sum=1+0+0=1->1
    lib.CAStep()

    assert lib.CAGetCell(318) == 1, f"Expected 1 at 318, got {lib.CAGetCell(318)}"
    assert lib.CAGetCell(319) == 2, f"Expected 2 at 319, got {lib.CAGetCell(319)}"
    assert lib.CAGetCell(320) == 3, f"Expected 3 at 320, got {lib.CAGetCell(320)}"
    assert lib.CAGetCell(321) == 2, f"Expected 2 at 321, got {lib.CAGetCell(321)}"
    assert lib.CAGetCell(322) == 1, f"Expected 1 at 322, got {lib.CAGetCell(322)}"
    assert lib.CAGetCell(317) == 0

    print("  PASSED")


def test_constant_rule(lib):
    """Rule that maps everything to 0 — all cells become 0 after one step."""
    print("=== Test: Constant zero rule ===")
    lib.CAInit()
    # All rules map to 0 (default after init)
    lib.CASetCell(100, 5)
    lib.CASetCell(200, 10)
    lib.CAStep()

    for i in [0, 100, 200, 320, SIZE]:
        assert lib.CAGetCell(i) == 0, f"Expected 0 at {i}, got {lib.CAGetCell(i)}"

    print("  PASSED")


def test_spatial_entropy(lib):
    """Spatial entropy counts cells matching their left neighbor."""
    print("=== Test: Spatial entropy ===")
    lib.CAInit()
    # All zeros: every cell matches its left neighbor
    # Cells 1..640 are compared with cells 0..639 -> 640 matches
    se = lib.CASpatialEntropy()
    assert se == SIZE, f"Expected {SIZE} (all same), got {se}"

    # Set one cell different
    lib.CASetCell(320, 1)
    se = lib.CASpatialEntropy()
    # Cell 320 != cell 319 (0 vs 1) -> lost one match
    # Cell 321 != cell 320 (0 vs 1) -> lost another match (if 321 is 0)
    # So 640 - 2 = 638
    assert se == SIZE - 2, f"Expected {SIZE - 2}, got {se}"

    print("  PASSED")


def test_temporal_entropy(lib):
    """Temporal entropy counts cells unchanged from a previous state."""
    print("=== Test: Temporal entropy ===")
    lib.CAInit()

    # Save current state (all zeros)
    PrevArray = (ctypes.c_int32 * 641)()
    for i in range(641):
        PrevArray[i] = 0

    # Still all zeros -> all 641 match
    te = lib.CATemporalEntropy(ctypes.addressof(PrevArray))
    assert te == 641, f"Expected 641, got {te}"

    # Change one cell
    lib.CASetCell(100, 7)
    te = lib.CATemporalEntropy(ctypes.addressof(PrevArray))
    assert te == 640, f"Expected 640, got {te}"

    print("  PASSED")


def test_hex_rule(lib):
    """Load rules from a hex string."""
    print("=== Test: Hex rule loading ===")
    lib.CAInit()

    # Hex string "0123456789ABCDEF" -> rules[0..15] = 0,1,2,...,15
    hex_str = b"0123456789ABCDEF"
    buf = ctypes.create_string_buffer(hex_str)
    rc = lib.CASetRuleFromHex(ctypes.addressof(buf), len(hex_str))
    assert rc == 0, f"CASetRuleFromHex returned {rc}"

    for i in range(16):
        val = lib.CAGetRule(i)
        assert val == i, f"Rule[{i}] expected {i}, got {val}"

    # Test lowercase
    lib.CAInit()
    hex_str2 = b"abcdef"
    buf2 = ctypes.create_string_buffer(hex_str2)
    rc2 = lib.CASetRuleFromHex(ctypes.addressof(buf2), len(hex_str2))
    assert rc2 == 0
    for i in range(6):
        val = lib.CAGetRule(i)
        assert val == 10 + i, f"Rule[{i}] expected {10+i}, got {val}"

    print("  PASSED")


def test_cell_count(lib):
    """Count cells with a given state."""
    print("=== Test: Cell count ===")
    lib.CAInit()

    # All zeros
    assert lib.CAGetCellCount(0) == 641, f"Expected 641 zeros"
    assert lib.CAGetCellCount(1) == 0

    lib.CASetCell(10, 3)
    lib.CASetCell(20, 3)
    lib.CASetCell(30, 3)
    assert lib.CAGetCellCount(3) == 3, f"Expected 3 threes"
    assert lib.CAGetCellCount(0) == 638

    print("  PASSED")


def test_wraparound(lib):
    """Verify wraparound at boundaries."""
    print("=== Test: Wraparound ===")
    lib.CAInit()
    for i in range(49):
        lib.CASetRule(i, min(i, 15))

    # Set cell 0 and cell 640 (they are neighbors via wraparound)
    lib.CASetCell(0, 1)
    lib.CASetCell(SIZE, 2)  # cell 640

    lib.CAStep()

    # Cell 0: left=cell[640]=2, self=1, right=cell[1]=0 -> sum=3 -> rule[3]=3
    assert lib.CAGetCell(0) == 3, f"Expected 3 at 0, got {lib.CAGetCell(0)}"
    # Cell 640: left=cell[639]=0, self=2, right=cell[0]=1 -> sum=3 -> rule[3]=3
    assert lib.CAGetCell(SIZE) == 3, f"Expected 3 at {SIZE}, got {lib.CAGetCell(SIZE)}"

    print("  PASSED")


def main():
    lib = load_lib()
    passed = 0
    failed = 0
    tests = [
        test_init_and_get_set,
        test_identity_rule,
        test_multi_step,
        test_constant_rule,
        test_spatial_entropy,
        test_temporal_entropy,
        test_hex_rule,
        test_cell_count,
        test_wraparound,
    ]
    for t in tests:
        try:
            t(lib)
            passed += 1
        except AssertionError as e:
            print(f"  FAILED: {e}")
            failed += 1
        except Exception as e:
            print(f"  ERROR: {e}")
            failed += 1

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {len(tests)}")
    if failed == 0:
        print("All tests passed!")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
