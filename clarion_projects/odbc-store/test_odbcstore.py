"""
Tests for OdbcStore.dll — Clarion DLL using ODBC driver with SQL Server LocalDB.

Requires:
    - SQL Server LocalDB (sqllocaldb)
    - OdbcDemo database with SensorReadings table
    - 32-bit Python with pyodbc
    - User DSN 'OdbcDemo' pointing to (localdb)\MSSQLLocalDB

First-time setup:
    cd odbc-store
    ~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe setup_db.py

Usage:
    cd odbc-store
    ~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_odbcstore.py
"""

import ctypes
import os
import struct
import sys

BIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin")
DLL_PATH = os.path.join(BIN_DIR, "OdbcStore.dll")

# Reading struct: 5 LONGs = 20 bytes
READING_SIZE = 20


def unpack_reading(buf):
    """Unpack a 20-byte reading buffer into a dict."""
    rid, sid, val, wt, ts = struct.unpack("<iiiii", buf)
    return {"ReadingID": rid, "SensorID": sid, "Value": val, "Weight": wt, "Timestamp": ts}


def run_tests():
    lib = ctypes.CDLL(DLL_PATH)

    # Set return types
    lib.ODBCOpen.restype = ctypes.c_long
    lib.ODBCClose.restype = ctypes.c_long
    lib.ODBCAddReading.restype = ctypes.c_long
    lib.ODBCGetReading.restype = ctypes.c_long
    lib.ODBCCountReadings.restype = ctypes.c_long
    lib.ODBCDeleteAll.restype = ctypes.c_long

    # Set arg types
    lib.ODBCAddReading.argtypes = [ctypes.c_long, ctypes.c_long, ctypes.c_long]
    lib.ODBCGetReading.argtypes = [ctypes.c_long, ctypes.c_long]

    passed = 0
    failed = 0

    def check(name, condition, detail=""):
        nonlocal passed, failed
        if condition:
            print(f"  PASS: {name}")
            passed += 1
        else:
            print(f"  FAIL: {name} {detail}")
            failed += 1

    # --- Test 1: Open ---
    print("Test 1: ODBCOpen")
    rc = lib.ODBCOpen()
    check("open returns 0", rc == 0, f"got {rc}")
    if rc != 0:
        print("  Cannot continue without successful OPEN")
        print(f"\n{passed} passed, {failed} failed out of {passed + failed}")
        return False

    # --- Test 2: Clean slate via DeleteAll, then count ---
    print("Test 2: Clean slate")
    lib.ODBCDeleteAll()
    count = lib.ODBCCountReadings()
    check("count after cleanup is 0", count == 0, f"got {count}")

    # --- Test 3: Add readings ---
    print("Test 3: ODBCAddReading")
    id1 = lib.ODBCAddReading(1, 100, 10)
    check("first reading id >= 0", id1 >= 0, f"got {id1}")
    id2 = lib.ODBCAddReading(1, 200, 20)
    check("second reading id > first", id2 > id1, f"got {id2}")
    id3 = lib.ODBCAddReading(2, 300, 30)
    check("third reading id > second", id3 > id2, f"got {id3}")

    # --- Test 4: Count (3 readings) ---
    print("Test 4: ODBCCountReadings (3 readings)")
    count = lib.ODBCCountReadings()
    check("count is 3", count == 3, f"got {count}")

    # --- Test 5: Get reading ---
    print("Test 5: ODBCGetReading")
    buf = ctypes.create_string_buffer(READING_SIZE)
    rc = lib.ODBCGetReading(id1, ctypes.addressof(buf))
    check("get returns 0", rc == 0, f"got {rc}")
    r = unpack_reading(buf.raw)
    check("reading ID matches", r["ReadingID"] == id1, f"got {r['ReadingID']}")
    check("sensor ID is 1", r["SensorID"] == 1, f"got {r['SensorID']}")
    check("value is 100", r["Value"] == 100, f"got {r['Value']}")
    check("weight is 10", r["Weight"] == 10, f"got {r['Weight']}")

    # --- Test 6: Get nonexistent ---
    print("Test 6: ODBCGetReading (nonexistent)")
    rc = lib.ODBCGetReading(999, ctypes.addressof(buf))
    check("get nonexistent returns -1", rc == -1, f"got {rc}")

    # --- Test 7: Delete all ---
    print("Test 7: ODBCDeleteAll")
    rc = lib.ODBCDeleteAll()
    check("delete all returns 0", rc == 0, f"got {rc}")
    count = lib.ODBCCountReadings()
    check("count after delete is 0", count == 0, f"got {count}")

    # --- Test 8: Close ---
    print("Test 8: ODBCClose")
    rc = lib.ODBCClose()
    check("close returns 0", rc == 0, f"got {rc}")

    # --- Test 9: Verify persistence (reopen) ---
    print("Test 9: Persistence")
    lib.ODBCOpen()
    lib.ODBCAddReading(5, 555, 55)
    lib.ODBCClose()

    lib.ODBCOpen()
    count = lib.ODBCCountReadings()
    check("data persists after close/reopen", count == 1, f"got {count}")
    lib.ODBCDeleteAll()  # cleanup
    lib.ODBCClose()

    print(f"\n{passed} passed, {failed} failed out of {passed + failed}")
    return failed == 0


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
