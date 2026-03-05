"""trace_sensorlib.py — Run SensorLib DLL with procedure-level trace logging.

Usage: python trace_sensorlib.py

Outputs the same procedure-level trace format as trace_sensorlib.pl
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
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "SensorLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    # Clean up previous data
    dat_path = os.path.join(os.path.dirname(__file__), "Sensors.dat")
    if os.path.exists(dat_path):
        os.remove(dat_path)

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")
    trace_call(lib, "SSOpen")
    trace_call(lib, "SSAddReading", 1, 100, 50)
    trace_call(lib, "SSAddReading", 2, 200, 25)
    trace_call(lib, "SSAddReading", 3, 300, 10)
    trace_call(lib, "SSCalculateWeightedAverage")
    trace_call(lib, "SSCleanupLowReadings", 150)
    trace_call(lib, "SSCalculateWeightedAverage")
    trace_call(lib, "SSClose")
    return 0


if __name__ == "__main__":
    sys.exit(main())
