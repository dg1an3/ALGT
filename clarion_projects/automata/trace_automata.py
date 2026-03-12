"""trace_automata.py — Run AutomataLib DLL with procedure-level trace logging.

Usage: python trace_automata.py

Outputs the same procedure-level trace format as trace_automata.pl
so the two can be compared with diff.
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


def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "AutomataLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    # Set up argtypes/restypes for clean calling
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
    lib.CAGetCellCount.restype = ctypes.c_int32
    lib.CAGetCellCount.argtypes = [ctypes.c_int32]

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # Initialize
    trace_call(lib, "CAInit")

    # Set up identity rule: rule[i] = min(i, 15) for i in 0..3
    trace_call(lib, "CASetRule", 0, 0)
    trace_call(lib, "CASetRule", 1, 1)
    trace_call(lib, "CASetRule", 2, 2)
    trace_call(lib, "CASetRule", 3, 3)

    # Verify rules
    trace_call(lib, "CAGetRule", 1)
    trace_call(lib, "CAGetRule", 3)

    # Out-of-range rule access
    trace_call(lib, "CAGetRule", 50)

    # Set a seed cell
    trace_call(lib, "CASetCell", 320, 1)

    # Read back the cell
    trace_call(lib, "CAGetCell", 320)

    # Out-of-range cell access
    trace_call(lib, "CAGetCell", -1)

    # Step the automaton
    trace_call(lib, "CAStep")

    # Check cells after step
    trace_call(lib, "CAGetCell", 319)
    trace_call(lib, "CAGetCell", 320)
    trace_call(lib, "CAGetCell", 321)

    # Spatial entropy
    trace_call(lib, "CASpatialEntropy")

    # Cell count
    trace_call(lib, "CAGetCellCount", 0)
    trace_call(lib, "CAGetCellCount", 1)

    return 0


if __name__ == "__main__":
    sys.exit(main())
