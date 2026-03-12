"""test_picdb.py -- Test the PicDB radar picture database DLL.

Uses 32-bit Python + ctypes to exercise all exported functions.
"""
import ctypes
import os
import struct
import sys
import glob


# PicBuf struct layout: SHORT(2) + BYTE*7(7) + LONG(4) + STRING(12) = 25 bytes
# With natural packing in Clarion:
#   Year:     SHORT  (2 bytes, offset 0)
#   Month:    BYTE   (1 byte,  offset 2)
#   Day:      BYTE   (1 byte,  offset 3)
#   Hour:     BYTE   (1 byte,  offset 4)
#   Minute:   BYTE   (1 byte,  offset 5)
#   Tilt:     BYTE   (1 byte,  offset 6)
#   Range:    BYTE   (1 byte,  offset 7)
#   Gain:     BYTE   (1 byte,  offset 8)
#   DataSize: LONG   (4 bytes, offset 9)  -- but may be padded
#   FileName: STRING(12) (12 bytes)
#
# Clarion packs structs tightly (no padding), so use '<' little-endian
PICBUF_FMT = '<hBBBBBBBi12s'
PICBUF_SIZE = struct.calcsize(PICBUF_FMT)

# DecodeBuf: SHORT(2) + BYTE*6(6) = 8 bytes
DECODEBUF_FMT = '<hBBBBBB'
DECODEBUF_SIZE = struct.calcsize(DECODEBUF_FMT)


def cleanup_dat_files():
    """Remove any .dat and .tmp files from tests."""
    for pat in ['PicDB.dat', 'PicDB.tmp']:
        for f in glob.glob(pat):
            try:
                os.remove(f)
            except OSError:
                pass


def unpack_picbuf(buf):
    """Unpack a PicBuf bytes object into a dict."""
    vals = struct.unpack(PICBUF_FMT, bytes(buf))
    return {
        'year': vals[0], 'month': vals[1], 'day': vals[2],
        'hour': vals[3], 'minute': vals[4],
        'tilt': vals[5], 'range': vals[6], 'gain': vals[7],
        'dataSize': vals[8],
        'fileName': vals[9].rstrip(b'\x00').rstrip(b' ').decode('ascii', errors='replace'),
    }


def unpack_decodebuf(buf):
    """Unpack a DecodeBuf bytes object into a dict."""
    vals = struct.unpack(DECODEBUF_FMT, bytes(buf))
    return {
        'year': vals[0], 'month': vals[1], 'day': vals[2],
        'hour': vals[3], 'minute': vals[4],
        'tilt': vals[5], 'range': vals[6], 'gain': vals[7],
    }


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "PicDB.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return 1

    cleanup_dat_files()

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return 1

    passed = 0
    failed = 0

    def check(label, condition):
        nonlocal passed, failed
        if condition:
            print(f"  PASS: {label}")
            passed += 1
        else:
            print(f"  FAIL: {label}")
            failed += 1

    # ---- Test 1: Open/Close ----
    print("Test 1: Open and Close")
    rc = lib.PDOpen()
    check("PDOpen returns 0", rc == 0)
    rc = lib.PDClose()
    check("PDClose returns 0", rc == 0)

    # ---- Test 2: Add picture with valid params, verify count ----
    print("\nTest 2: Add picture and verify count")
    cleanup_dat_files()
    lib.PDOpen()
    rc = lib.PDAddPicture(2024, 3, 15, 14, 30, 3, 1, 5, 1024)
    check("PDAddPicture returns insert pos 1", rc == 1)
    count = lib.PDGetPictureCount()
    check("PDGetPictureCount returns 1", count == 1)

    # ---- Test 3: GetPicture and verify fields ----
    print("\nTest 3: Get picture and verify fields")
    buf = (ctypes.c_ubyte * PICBUF_SIZE)()
    rc = lib.PDGetPicture(1, ctypes.addressof(buf))
    check("PDGetPicture returns 0", rc == 0)
    rec = unpack_picbuf(buf)
    check(f"year={rec['year']}", rec['year'] == 2024)
    check(f"month={rec['month']}", rec['month'] == 3)
    check(f"day={rec['day']}", rec['day'] == 15)
    check(f"hour={rec['hour']}", rec['hour'] == 14)
    check(f"minute={rec['minute']}", rec['minute'] == 30)
    check(f"tilt={rec['tilt']}", rec['tilt'] == 3)
    check(f"range={rec['range']}", rec['range'] == 1)
    check(f"gain={rec['gain']}", rec['gain'] == 5)
    check(f"dataSize={rec['dataSize']}", rec['dataSize'] == 1024)
    # Filename: hour=14,min=30 -> "1430", tilt=3->'D', range=1->'B', gain=5->'E' -> "1430DBE.WX"
    check(f"fileName='{rec['fileName']}'", rec['fileName'] == '1430DBE.WX')

    # ---- Test 4: Add multiple pictures out of order, verify sorted by timestamp ----
    print("\nTest 4: Sorted insertion by timestamp")
    lib.PDClose()
    cleanup_dat_files()
    lib.PDOpen()

    # Add pictures in non-chronological order
    # Picture C: 2024-03-15 16:00 (latest)
    rc = lib.PDAddPicture(2024, 3, 15, 16, 0, 0, 0, 1, 500)
    check("Add pic C (16:00) returns pos 1", rc == 1)

    # Picture A: 2024-03-15 08:00 (earliest) -- should insert before C
    rc = lib.PDAddPicture(2024, 3, 15, 8, 0, 1, 1, 2, 600)
    check("Add pic A (08:00) returns pos 1 (inserted before C)", rc == 1)

    # Picture B: 2024-03-15 12:30 (middle) -- should insert between A and C
    rc = lib.PDAddPicture(2024, 3, 15, 12, 30, 2, 2, 3, 700)
    check("Add pic B (12:30) returns pos 2 (inserted between A,C)", rc == 2)

    count = lib.PDGetPictureCount()
    check("Count is 3", count == 3)

    # Verify order: A(08:00), B(12:30), C(16:00)
    buf1 = (ctypes.c_ubyte * PICBUF_SIZE)()
    buf2 = (ctypes.c_ubyte * PICBUF_SIZE)()
    buf3 = (ctypes.c_ubyte * PICBUF_SIZE)()
    lib.PDGetPicture(1, ctypes.addressof(buf1))
    lib.PDGetPicture(2, ctypes.addressof(buf2))
    lib.PDGetPicture(3, ctypes.addressof(buf3))
    r1 = unpack_picbuf(buf1)
    r2 = unpack_picbuf(buf2)
    r3 = unpack_picbuf(buf3)
    check(f"Record 1 hour={r1['hour']} (expect 8)", r1['hour'] == 8)
    check(f"Record 2 hour={r2['hour']} (expect 12)", r2['hour'] == 12)
    check(f"Record 3 hour={r3['hour']} (expect 16)", r3['hour'] == 16)
    check(f"Record 2 minute={r2['minute']} (expect 30)", r2['minute'] == 30)

    # ---- Test 5: DeletePicture and verify count, reindexing ----
    print("\nTest 5: Delete picture")
    rc = lib.PDDeletePicture(2)  # Delete middle record (12:30)
    check("PDDeletePicture(2) returns 0", rc == 0)
    count = lib.PDGetPictureCount()
    check("Count is 2 after delete", count == 2)

    # Verify remaining records: A(08:00), C(16:00)
    buf_a = (ctypes.c_ubyte * PICBUF_SIZE)()
    buf_c = (ctypes.c_ubyte * PICBUF_SIZE)()
    lib.PDGetPicture(1, ctypes.addressof(buf_a))
    lib.PDGetPicture(2, ctypes.addressof(buf_c))
    ra = unpack_picbuf(buf_a)
    rc_rec = unpack_picbuf(buf_c)
    check(f"After delete, rec 1 hour={ra['hour']} (expect 8)", ra['hour'] == 8)
    check(f"After delete, rec 2 hour={rc_rec['hour']} (expect 16)", rc_rec['hour'] == 16)

    # ---- Test 6: EncodeFileName ----
    print("\nTest 6: EncodeFileName")
    fname_buf = (ctypes.c_ubyte * 12)()
    rc = lib.PDEncodeFileName(14, 30, 3, 1, 5, ctypes.addressof(fname_buf))
    fname = bytes(fname_buf).rstrip(b'\x00').rstrip(b' ').decode('ascii')
    check(f"EncodeFileName returns len (expect 10), got {rc}", rc == 10)
    check(f"Filename='{fname}' (expect '1430DBE.WX')", fname == '1430DBE.WX')

    # Edge case: hour=0, min=5, tilt=0, range=0, gain=1
    fname_buf2 = (ctypes.c_ubyte * 12)()
    rc = lib.PDEncodeFileName(0, 5, 0, 0, 1, ctypes.addressof(fname_buf2))
    fname2 = bytes(fname_buf2).rstrip(b'\x00').rstrip(b' ').decode('ascii')
    check(f"Edge filename='{fname2}' (expect '0005AAA.WX')", fname2 == '0005AAA.WX')

    # Max values: hour=23, min=59, tilt=11, range=4, gain=17
    fname_buf3 = (ctypes.c_ubyte * 12)()
    rc = lib.PDEncodeFileName(23, 59, 11, 4, 17, ctypes.addressof(fname_buf3))
    fname3 = bytes(fname_buf3).rstrip(b'\x00').rstrip(b' ').decode('ascii')
    check(f"Max filename='{fname3}' (expect '2359LEQ.WX')", fname3 == '2359LEQ.WX')

    # ---- Test 7: DecodeFileName roundtrip ----
    print("\nTest 7: DecodeFileName roundtrip")
    name_input = b'1430DBE.WX\x00\x00'
    name_cbuf = (ctypes.c_ubyte * 12)(*name_input)
    decode_buf = (ctypes.c_ubyte * DECODEBUF_SIZE)()
    rc = lib.PDDecodeFileName(ctypes.addressof(name_cbuf), 10, ctypes.addressof(decode_buf))
    check("PDDecodeFileName returns 0", rc == 0)
    dec = unpack_decodebuf(decode_buf)
    check(f"Decoded hour={dec['hour']} (expect 14)", dec['hour'] == 14)
    check(f"Decoded minute={dec['minute']} (expect 30)", dec['minute'] == 30)
    check(f"Decoded tilt={dec['tilt']} (expect 3)", dec['tilt'] == 3)
    check(f"Decoded range={dec['range']} (expect 1)", dec['range'] == 1)
    check(f"Decoded gain={dec['gain']} (expect 5)", dec['gain'] == 5)

    # ---- Test 8: FindByParams ----
    print("\nTest 8: FindByParams")
    # DB still has: rec1(tilt=1,range=1), rec2(tilt=0,range=0)
    idx = lib.PDFindByParams(1, 1)
    check(f"FindByParams(1,1) returns index (expect 1), got {idx}", idx == 1)
    idx = lib.PDFindByParams(0, 0)
    check(f"FindByParams(0,0) returns index (expect 2), got {idx}", idx == 2)
    idx = lib.PDFindByParams(5, 3)
    check(f"FindByParams(5,3) returns -1 (not found), got {idx}", idx == -1)

    # ---- Test 9: Invalid params ----
    print("\nTest 9: Invalid parameters")
    rc = lib.PDAddPicture(2024, 1, 1, 0, 0, 12, 0, 1, 100)  # tilt=12 > 11
    check("tilt=12 rejected (returns -1)", rc == -1)
    rc = lib.PDAddPicture(2024, 1, 1, 0, 0, 0, 5, 1, 100)   # range=5 > 4
    check("range=5 rejected (returns -1)", rc == -1)
    rc = lib.PDAddPicture(2024, 1, 1, 0, 0, 0, 0, 0, 100)   # gain=0 < 1
    check("gain=0 rejected (returns -1)", rc == -1)
    rc = lib.PDAddPicture(2024, 1, 1, 0, 0, 0, 0, 18, 100)  # gain=18 > 17
    check("gain=18 rejected (returns -1)", rc == -1)
    rc = lib.PDEncodeFileName(14, 30, 12, 0, 1, ctypes.addressof(fname_buf))
    check("EncodeFileName tilt=12 rejected", rc == -1)
    rc = lib.PDEncodeFileName(14, 30, 0, 5, 1, ctypes.addressof(fname_buf))
    check("EncodeFileName range=5 rejected", rc == -1)
    rc = lib.PDEncodeFileName(14, 30, 0, 0, 0, ctypes.addressof(fname_buf))
    check("EncodeFileName gain=0 rejected", rc == -1)

    # ---- Cleanup ----
    lib.PDClose()
    cleanup_dat_files()

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed}")
    if failed > 0:
        print("SOME TESTS FAILED")
        return 1
    else:
        print("ALL TESTS PASSED")
        return 0


if __name__ == "__main__":
    sys.exit(main())
