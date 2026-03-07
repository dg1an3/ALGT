"""Target script for CDB debugging of SensorLib.dll.

CDB will attach to this process and set breakpoints on DLL exports.
This script is identical to trace_sensorlib.py but without its own tracing,
since CDB provides the trace.
"""
import ctypes
import os
import sys


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "SensorLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    # Clean up previous data
    dat_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensors.dat")
    if os.path.exists(dat_path):
        os.remove(dat_path)

    lib = ctypes.CDLL(dll_path)

    # Marker so CDB knows DLL is loaded - set breakpoint after this
    print("DLL_LOADED", flush=True)

    r = lib.SSOpen()
    print(f"SSOpen -> {r}", flush=True)

    r = lib.SSAddReading(1, 100, 50)
    print(f"SSAddReading(1,100,50) -> {r}", flush=True)

    r = lib.SSAddReading(2, 200, 25)
    print(f"SSAddReading(2,200,25) -> {r}", flush=True)

    r = lib.SSAddReading(3, 300, 10)
    print(f"SSAddReading(3,300,10) -> {r}", flush=True)

    r = lib.SSCalculateWeightedAverage()
    print(f"SSCalculateWeightedAverage -> {r}", flush=True)

    r = lib.SSCleanupLowReadings(150)
    print(f"SSCleanupLowReadings(150) -> {r}", flush=True)

    r = lib.SSCalculateWeightedAverage()
    print(f"SSCalculateWeightedAverage -> {r}", flush=True)

    r = lib.SSClose()
    print(f"SSClose -> {r}", flush=True)

    return 0


if __name__ == "__main__":
    sys.exit(main())
