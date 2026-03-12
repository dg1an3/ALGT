"""trace_fuel.py — Run FuelLib DLL with procedure-level trace logging.

Usage: python trace_fuel.py

Outputs the same procedure-level trace format as trace_fuel.pl
so the two can be compared with diff.

Note: FLAddTransaction uses descPtr/descLen for the description string.
In the Prolog trace, we pass 0/0 (no MemCopy available in simulator).
Here we pass real pointers, but trace output uses 0/0 for comparability.
FLGetTransaction and FLDeleteTransaction are included here but omitted
from the Prolog trace (MemCopy and REMOVE/RENAME not in simulator).
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


def trace_call_desc(lib, name, args_for_call, args_for_display):
    """Call with real args but display different args (for MemCopy params)."""
    func = getattr(lib, name)
    result = func(*args_for_call)
    arg_str = ", ".join(str(a) for a in args_for_display)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "FuelLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    # Clean up previous data files
    base_dir = os.path.dirname(os.path.abspath(__file__))
    for f in ('FuelTrans.dat', 'FuelPrice.dat', 'FuelTemp.dat'):
        dat = os.path.join(base_dir, f)
        if os.path.exists(dat):
            os.remove(dat)

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # Open
    trace_call(lib, "FLOpen")

    # Set prices
    trace_call(lib, "FLSetPrice", 1, 359)
    trace_call(lib, "FLSetPrice", 2, 389)
    trace_call(lib, "FLSetPrice", 3, 419)
    trace_call(lib, "FLSetPrice", 4, 399)
    trace_call(lib, "FLSetPrice", 5, 100)   # invalid

    # Get prices
    trace_call(lib, "FLGetPrice", 1)
    trace_call(lib, "FLGetPrice", 3)
    trace_call(lib, "FLGetPrice", 5)         # invalid

    # Add transactions — pass real pointers but display 0/0 for Prolog compat
    def add_trans_traced(month, day, year, hour, minute, desc, amount):
        desc_bytes = desc.encode('ascii')
        desc_buf = ctypes.create_string_buffer(desc_bytes)
        real_args = (month, day, year, hour, minute,
                     ctypes.addressof(desc_buf), len(desc_bytes), amount)
        display_args = (month, day, year, hour, minute, 0, 0, amount)
        return trace_call_desc(lib, "FLAddTransaction",
                               real_args, display_args)

    add_trans_traced(3, 1, 2026, 8, 0, "Fuel delivery - Regular", 50000)
    add_trans_traced(3, 1, 2026, 10, 30, "Sale - 4.06 gal Regular", -1500)
    add_trans_traced(3, 2, 2026, 14, 15, "Sale - 6.78 gal Regular", -2500)

    # Count and balance
    trace_call(lib, "FLGetTransactionCount")
    trace_call(lib, "FLGetBalance")

    # Recalc
    trace_call(lib, "FLRecalcBalances")

    # Close
    trace_call(lib, "FLClose")

    return 0


if __name__ == "__main__":
    sys.exit(main())
