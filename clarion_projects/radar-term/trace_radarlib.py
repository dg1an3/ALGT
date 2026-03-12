"""trace_radarlib.py — Run RadarLib DLL with procedure-level trace logging.

Usage: python trace_radarlib.py

Outputs the same procedure-level trace format as trace_radar.pl
so the two can be compared with diff.
"""
import ctypes
import os
import struct
import sys


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "RadarLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    # Clean up previous data files
    for dat in ("Stations.dat", "Pictures.dat", "PicTemp.dat"):
        dat_path = os.path.join(os.path.dirname(__file__), dat)
        if os.path.exists(dat_path):
            os.remove(dat_path)

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # Open files
    trace_call(lib, "RLOpen")

    # Add a station: number=1, name="TestStn", phone="5551234",
    #   commPort=2, baudRate=9600, autoInterval=60
    name = b"TestStn"
    phone = b"5551234"
    name_buf = ctypes.create_string_buffer(name)
    phone_buf = ctypes.create_string_buffer(phone)
    trace_call(lib, "RLAddStation",
               1,
               ctypes.cast(name_buf, ctypes.c_void_p).value, len(name),
               ctypes.cast(phone_buf, ctypes.c_void_p).value, len(phone),
               2, 9600, 60)

    # Get station count
    trace_call(lib, "RLGetStationCount")

    # Select station 1
    trace_call(lib, "RLSelectStation", 1)

    # Set radar parameters: tilt=3, range=2 (100km), gain=10
    trace_call(lib, "RLSetParams", 3, 2, 10)

    # Set mode to 1 (Interactive)
    trace_call(lib, "RLSetMode", 1)

    # Get mode
    trace_call(lib, "RLGetMode")

    # Add a picture: name="IMG001.BMP", 2026-03-12 14:30, tilt=3, range=2, gain=10
    pic_name = b"IMG001.BMP"
    pic_buf = ctypes.create_string_buffer(pic_name)
    trace_call(lib, "RLAddPicture",
               ctypes.cast(pic_buf, ctypes.c_void_p).value, len(pic_name),
               2026, 3, 12, 14, 30, 3, 2, 10)

    # Get picture count
    trace_call(lib, "RLGetPictureCount")

    # Range conversion: code 2 -> 100 km
    trace_call(lib, "RLRangeToKm", 2)

    # Range conversion: code 4 -> 400 km
    trace_call(lib, "RLRangeToKm", 4)

    # Invalid range code -> -1
    trace_call(lib, "RLRangeToKm", 5)

    # Delete picture 1
    trace_call(lib, "RLDeletePicture", 1)

    # Picture count after delete
    trace_call(lib, "RLGetPictureCount")

    # Close files
    trace_call(lib, "RLClose")

    return 0


if __name__ == "__main__":
    sys.exit(main())
