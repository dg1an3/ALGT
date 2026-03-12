"""trace_modemlib.py -- Procedure-level trace for ModemLib.dll.

Outputs CALL ProcName(args) -> result format for comparison
with the Prolog interpreter trace.

Translated from Modem.DEF/Modem.MOD (Derek Lane, 1986, E300DB).

Usage: python trace_modemlib.py
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


def trace_call_str(lib, name, text):
    """Call a function that takes (ptr, len) string args, with trace."""
    buf = ctypes.create_string_buffer(text.encode("ascii"))
    ptr = ctypes.addressof(buf)
    length = len(text)
    func = getattr(lib, name)
    result = func(ptr, length)
    print(f"CALL {name}(\"{text}\") -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "ModemLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # Initialize
    trace_call(lib, "MLInit")

    # Set response to Connect2400, dial, check state
    trace_call(lib, "MLSetResponse", 10)
    trace_call_str(lib, "MLCall", "5551234")
    trace_call(lib, "MLGetState")
    trace_call(lib, "MLGetBaud")

    # Hang up
    trace_call(lib, "MLHangUp")
    trace_call(lib, "MLGetState")

    # Set response to Busy, dial
    trace_call(lib, "MLSetResponse", 7)
    trace_call_str(lib, "MLCall", "5559999")
    trace_call(lib, "MLGetState")

    # Re-init, set Connect1200, dial
    trace_call(lib, "MLInit")
    trace_call(lib, "MLSetResponse", 5)
    trace_call_str(lib, "MLCall", "5552222")
    trace_call(lib, "MLGetState")
    trace_call(lib, "MLGetBaud")

    # Send ATH command (hangup via command)
    trace_call_str(lib, "MLCommand", "ATH")
    trace_call(lib, "MLGetState")
    trace_call(lib, "MLGetBaud")

    # Result code lookups
    trace_call(lib, "MLGetLastResult")

    return 0


if __name__ == "__main__":
    sys.exit(main())
