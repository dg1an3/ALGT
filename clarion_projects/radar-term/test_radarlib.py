import ctypes
import os
import struct
import sys

# Station buffer: LONG + STRING(30) + STRING(20) + BYTE + LONG + LONG
# Clarion packing: fields are packed sequentially with no padding for DOS driver records
# LONG=4, STRING(30)=30, STRING(20)=20, BYTE=1, LONG=4, LONG=4 = 63 bytes
STATION_BUF_SIZE = 4 + 30 + 20 + 1 + 4 + 4  # 63

# Picture buffer: STRING(12) + SHORT + BYTE*4 + BYTE*3
# STRING(12)=12, SHORT=2, BYTE=1 x4, BYTE=1 x3 = 21 bytes
PICTURE_BUF_SIZE = 12 + 2 + 1 + 1 + 1 + 1 + 1 + 1 + 1  # 20

# Param buffer: 3 LONGs = 12 bytes
PARAM_BUF_SIZE = 12


class StationBuf(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("number", ctypes.c_int32),
        ("name", ctypes.c_char * 30),
        ("phone", ctypes.c_char * 20),
        ("comm_port", ctypes.c_uint8),
        ("baud_rate", ctypes.c_int32),
        ("auto_interval", ctypes.c_int32),
    ]


class PictureBuf(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("file_name", ctypes.c_char * 12),
        ("year", ctypes.c_int16),
        ("month", ctypes.c_uint8),
        ("day", ctypes.c_uint8),
        ("hour", ctypes.c_uint8),
        ("minute", ctypes.c_uint8),
        ("tilt", ctypes.c_uint8),
        ("range_code", ctypes.c_uint8),
        ("gain", ctypes.c_uint8),
    ]


class ParamBuf(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("tilt", ctypes.c_int32),
        ("range_code", ctypes.c_int32),
        ("gain", ctypes.c_int32),
    ]


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "RadarLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return 1

    # Clean up previous data files
    for f in ["Stations.dat", "Pictures.dat"]:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), f)
        if os.path.exists(p):
            os.remove(p)

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return 1

    passed = 0
    failed = 0

    def check(desc, condition):
        nonlocal passed, failed
        if condition:
            print(f"  OK: {desc}")
            passed += 1
        else:
            print(f"  FAIL: {desc}")
            failed += 1

    # --- Open ---
    print("Test: Open")
    ret = lib.RLOpen()
    check("RLOpen returns 0", ret == 0)

    # --- Station count starts at 0 ---
    print("Test: Initial station count")
    check("StationCount == 0", lib.RLGetStationCount() == 0)

    # --- Add stations ---
    print("Test: Add stations")
    name1 = b"Weather Station Alpha"
    phone1 = b"555-0101"
    ret = lib.RLAddStation(1001, ctypes.c_char_p(name1), len(name1),
                           ctypes.c_char_p(phone1), len(phone1), 1, 9600, 5)
    check("AddStation #1 returns 0", ret == 0)

    name2 = b"Coastal Radar Beta"
    phone2 = b"555-0202"
    ret = lib.RLAddStation(1002, ctypes.c_char_p(name2), len(name2),
                           ctypes.c_char_p(phone2), len(phone2), 2, 19200, 10)
    check("AddStation #2 returns 0", ret == 0)

    name3 = b"Mountain Peak Gamma"
    phone3 = b"555-0303"
    ret = lib.RLAddStation(1003, ctypes.c_char_p(name3), len(name3),
                           ctypes.c_char_p(phone3), len(phone3), 1, 38400, 0)
    check("AddStation #3 returns 0", ret == 0)

    check("StationCount == 3", lib.RLGetStationCount() == 3)

    # --- Get station ---
    print("Test: Get station")
    sbuf = StationBuf()
    ret = lib.RLGetStation(1, ctypes.addressof(sbuf))
    check("GetStation(1) returns 0", ret == 0)
    check("Station 1 number == 1001", sbuf.number == 1001)
    check("Station 1 name starts with 'Weather'",
          sbuf.name[:7] == b"Weather")
    check("Station 1 baud_rate == 9600", sbuf.baud_rate == 9600)

    ret = lib.RLGetStation(2, ctypes.addressof(sbuf))
    check("GetStation(2) returns 0", ret == 0)
    check("Station 2 number == 1002", sbuf.number == 1002)

    # Out of range
    ret = lib.RLGetStation(99, ctypes.addressof(sbuf))
    check("GetStation(99) returns -1", ret == -1)

    # --- Select station ---
    print("Test: Select station")
    check("SelectStation(2) returns 0", lib.RLSelectStation(2) == 0)
    check("SelectStation(0) returns -1 (out of range)", lib.RLSelectStation(0) == -1)
    check("SelectStation(99) returns -1 (out of range)", lib.RLSelectStation(99) == -1)

    # --- Set/Get params ---
    print("Test: Set/Get params")
    ret = lib.RLSetParams(5, 2, 10)
    check("SetParams(5,2,10) returns 0", ret == 0)

    pbuf = ParamBuf()
    lib.RLGetParams(ctypes.addressof(pbuf))
    check("Tilt == 5", pbuf.tilt == 5)
    check("Range == 2", pbuf.range_code == 2)
    check("Gain == 10", pbuf.gain == 10)

    # Validation: tilt out of range
    ret = lib.RLSetParams(12, 2, 10)
    check("SetParams tilt=12 rejected", ret == -1)

    # Validation: range out of range
    ret = lib.RLSetParams(5, 5, 10)
    check("SetParams range=5 rejected", ret == -1)

    # Validation: gain out of range
    ret = lib.RLSetParams(5, 2, 0)
    check("SetParams gain=0 rejected", ret == -1)
    ret = lib.RLSetParams(5, 2, 18)
    check("SetParams gain=18 rejected", ret == -1)

    # Params unchanged after invalid set
    lib.RLGetParams(ctypes.addressof(pbuf))
    check("Params unchanged after invalid set (tilt still 5)", pbuf.tilt == 5)

    # --- Mode ---
    print("Test: Mode switching")
    check("Initial mode == 0 (Idle)", lib.RLGetMode() == 0)
    check("SetMode(1) returns 0", lib.RLSetMode(1) == 0)
    check("GetMode == 1 (Modem)", lib.RLGetMode() == 1)
    check("SetMode(3) returns 0", lib.RLSetMode(3) == 0)
    check("GetMode == 3 (RxPic)", lib.RLGetMode() == 3)
    check("SetMode(4) returns -1 (invalid)", lib.RLSetMode(4) == -1)
    check("Mode unchanged after invalid set", lib.RLGetMode() == 3)

    # --- Range conversion ---
    print("Test: Range code to km conversion")
    check("Range 0 -> 25 km", lib.RLRangeToKm(0) == 25)
    check("Range 1 -> 50 km", lib.RLRangeToKm(1) == 50)
    check("Range 2 -> 100 km", lib.RLRangeToKm(2) == 100)
    check("Range 3 -> 200 km", lib.RLRangeToKm(3) == 200)
    check("Range 4 -> 400 km", lib.RLRangeToKm(4) == 400)
    check("Range 5 -> -1 (invalid)", lib.RLRangeToKm(5) == -1)

    # --- Pictures ---
    print("Test: Add pictures")
    check("Initial PicCount == 0", lib.RLGetPictureCount() == 0)

    pname1 = b"radar001.rle"
    ret = lib.RLAddPicture(ctypes.c_char_p(pname1), len(pname1),
                           2026, 3, 11, 14, 30, 5, 2, 10)
    check("AddPicture #1 returns 1 (new count)", ret == 1)

    pname2 = b"radar002.rle"
    ret = lib.RLAddPicture(ctypes.c_char_p(pname2), len(pname2),
                           2026, 3, 11, 15, 0, 3, 1, 8)
    check("AddPicture #2 returns 2", ret == 2)

    pname3 = b"radar003.rle"
    ret = lib.RLAddPicture(ctypes.c_char_p(pname3), len(pname3),
                           2026, 3, 11, 15, 30, 0, 4, 17)
    check("AddPicture #3 returns 3", ret == 3)

    check("PicCount == 3", lib.RLGetPictureCount() == 3)

    # --- Get picture ---
    print("Test: Get picture")
    picbuf = PictureBuf()
    ret = lib.RLGetPicture(1, ctypes.addressof(picbuf))
    check("GetPicture(1) returns 0", ret == 0)
    check("Pic 1 name starts with 'radar001'",
          picbuf.file_name[:8] == b"radar001")
    check("Pic 1 year == 2026", picbuf.year == 2026)
    check("Pic 1 month == 3", picbuf.month == 3)
    check("Pic 1 hour == 14", picbuf.hour == 14)
    check("Pic 1 tilt == 5", picbuf.tilt == 5)
    check("Pic 1 range == 2", picbuf.range_code == 2)
    check("Pic 1 gain == 10", picbuf.gain == 10)

    ret = lib.RLGetPicture(2, ctypes.addressof(picbuf))
    check("GetPicture(2) returns 0", ret == 0)
    check("Pic 2 gain == 8", picbuf.gain == 8)

    ret = lib.RLGetPicture(99, ctypes.addressof(picbuf))
    check("GetPicture(99) returns -1", ret == -1)

    # --- Delete picture ---
    print("Test: Delete picture")
    ret = lib.RLDeletePicture(2)
    check("DeletePicture(2) returns 0", ret == 0)
    check("PicCount == 2 after delete", lib.RLGetPictureCount() == 2)

    # Verify remaining pictures
    ret = lib.RLGetPicture(1, ctypes.addressof(picbuf))
    check("After delete, pic 1 still radar001",
          picbuf.file_name[:8] == b"radar001")

    ret = lib.RLGetPicture(2, ctypes.addressof(picbuf))
    check("After delete, pic 2 is now radar003",
          picbuf.file_name[:8] == b"radar003")

    # Delete out of range
    ret = lib.RLDeletePicture(0)
    check("DeletePicture(0) returns -1", ret == -1)
    ret = lib.RLDeletePicture(99)
    check("DeletePicture(99) returns -1", ret == -1)

    # --- Close ---
    print("Test: Close")
    ret = lib.RLClose()
    check("RLClose returns 0", ret == 0)

    # --- Summary ---
    total = passed + failed
    print(f"\nResults: {passed}/{total} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
