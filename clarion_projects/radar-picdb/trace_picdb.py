"""trace_picdb.py -- Procedure-level trace for PicDB radar picture database DLL.

Usage: python trace_picdb.py

Outputs CALL ProcName(args) -> result format for comparison with Prolog interpreter.
"""
import ctypes
import os
import struct
import sys
import glob


PICBUF_FMT = '<hBBBBBBBi12s'
PICBUF_SIZE = struct.calcsize(PICBUF_FMT)

DECODEBUF_FMT = '<hBBBBBB'
DECODEBUF_SIZE = struct.calcsize(DECODEBUF_FMT)


def cleanup():
    for pat in ['PicDB.dat', 'PicDB.tmp']:
        for f in glob.glob(pat):
            try:
                os.remove(f)
            except OSError:
                pass


def trace_call(lib, name, *args):
    """Call a DLL function and print a trace line."""
    func = getattr(lib, name)
    result = func(*args)
    arg_str = ", ".join(str(a) for a in args)
    print(f"CALL {name}({arg_str}) -> {result}")
    return result


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "PicDB.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    cleanup()

    lib = ctypes.CDLL(dll_path)

    print("=== Procedure-level trace (comparable to Prolog) ===")

    # Open
    trace_call(lib, "PDOpen")

    # Add pictures out of chronological order
    # Picture C: 2024-03-15 16:00, tilt=0, range=0, gain=1, size=500
    trace_call(lib, "PDAddPicture", 2024, 3, 15, 16, 0, 0, 0, 1, 500)
    # Picture A: 2024-03-15 08:00, tilt=1, range=1, gain=2, size=600
    trace_call(lib, "PDAddPicture", 2024, 3, 15, 8, 0, 1, 1, 2, 600)
    # Picture B: 2024-03-15 12:30, tilt=2, range=2, gain=3, size=700
    trace_call(lib, "PDAddPicture", 2024, 3, 15, 12, 30, 2, 2, 3, 700)

    # Count
    trace_call(lib, "PDGetPictureCount")

    # Get each record (should be sorted: A, B, C)
    buf = (ctypes.c_ubyte * PICBUF_SIZE)()
    trace_call(lib, "PDGetPicture", 1, ctypes.addressof(buf))
    trace_call(lib, "PDGetPicture", 2, ctypes.addressof(buf))
    trace_call(lib, "PDGetPicture", 3, ctypes.addressof(buf))

    # FindByParams
    trace_call(lib, "PDFindByParams", 1, 1)
    trace_call(lib, "PDFindByParams", 5, 3)  # not found

    # EncodeFileName: hour=14, min=30, tilt=3, range=1, gain=5
    fname_buf = (ctypes.c_ubyte * 12)()
    trace_call(lib, "PDEncodeFileName", 14, 30, 3, 1, 5, ctypes.addressof(fname_buf))

    # DecodeFileName
    name_input = b'1430DBE.WX\x00\x00'
    name_cbuf = (ctypes.c_ubyte * 12)(*name_input)
    decode_buf = (ctypes.c_ubyte * DECODEBUF_SIZE)()
    trace_call(lib, "PDDecodeFileName", ctypes.addressof(name_cbuf), 10, ctypes.addressof(decode_buf))

    # Delete middle record
    trace_call(lib, "PDDeletePicture", 2)
    trace_call(lib, "PDGetPictureCount")

    # Invalid params
    trace_call(lib, "PDAddPicture", 2024, 1, 1, 0, 0, 12, 0, 1, 100)  # tilt=12

    # Close
    trace_call(lib, "PDClose")

    cleanup()
    return 0


if __name__ == "__main__":
    sys.exit(main())
