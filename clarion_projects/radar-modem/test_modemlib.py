"""test_modemlib.py -- Tests for ModemLib.dll Hayes modem state machine simulator.

Translated from Modem.DEF/Modem.MOD (Derek Lane, 1986, E300DB).
Requires 32-bit Python (Clarion 11 produces 32-bit DLLs).

Usage:
    python test_modemlib.py
"""
import ctypes
import os
import sys

# Hayes result code constants (matching original Modula-2 ResultCode enum)
RC_OK = 0
RC_CONNECT300 = 1
RC_RING = 2
RC_NO_CARRIER = 3
RC_ERROR = 4
RC_CONNECT1200 = 5
RC_NO_DIALTONE = 6
RC_BUSY = 7
RC_NO_ANSWER = 8
RC_CONNECT2400 = 10
RC_NO_RESPONSE = 99

# Expected text for each result code
RESULT_TEXTS = {
    RC_OK:           "OK",
    RC_CONNECT300:   "CONNECT 300",
    RC_RING:         "RING",
    RC_NO_CARRIER:   "NO CARRIER",
    RC_ERROR:        "ERROR",
    RC_CONNECT1200:  "CONNECT 1200",
    RC_NO_DIALTONE:  "NO DIALTONE",
    RC_BUSY:         "BUSY",
    RC_NO_ANSWER:    "NO ANSWER",
    RC_CONNECT2400:  "CONNECT 2400",
    RC_NO_RESPONSE:  "NO RESPONSE",
}


def load_dll():
    dll_path = os.path.join(os.path.dirname(__file__), "bin", "ModemLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        sys.exit(1)
    return ctypes.CDLL(dll_path)


def call_with_string(lib, func, text):
    """Call a function that takes (LONG ptr, LONG len) for a string argument."""
    buf = ctypes.create_string_buffer(text.encode("ascii"))
    return func(ctypes.addressof(buf), len(text))


def get_result_text(lib, code):
    """Call MLResultToText and return the string."""
    buf = ctypes.create_string_buffer(32)
    length = lib.MLResultToText(code, ctypes.addressof(buf))
    return buf.raw[:length].decode("ascii")


def main():
    lib = load_dll()
    passed = 0
    failed = 0

    def check(desc, actual, expected):
        nonlocal passed, failed
        if actual == expected:
            print(f"  PASS: {desc} (got {actual})")
            passed += 1
        else:
            print(f"  FAIL: {desc} — expected {expected}, got {actual}")
            failed += 1

    # --- Test 1: Init ---
    print("Test 1: Init")
    check("MLInit returns 0", lib.MLInit(), 0)
    check("state is idle", lib.MLGetState(), 0)
    check("baud is 0", lib.MLGetBaud(), 0)
    check("lastResult is 0", lib.MLGetLastResult(), 0)

    # --- Test 2: SetResponse + Call with Connect2400 ---
    print("Test 2: Call with Connect2400")
    lib.MLInit()
    check("SetResponse(10) returns 0", lib.MLSetResponse(RC_CONNECT2400), 0)
    result = call_with_string(lib, lib.MLCall, "5551234")
    check("MLCall returns 10 (Connect2400)", result, RC_CONNECT2400)
    check("connected = 1", lib.MLGetState(), 1)
    check("baud = 2400", lib.MLGetBaud(), 2400)
    check("lastResult = 10", lib.MLGetLastResult(), RC_CONNECT2400)

    # --- Test 3: HangUp ---
    print("Test 3: HangUp")
    check("MLHangUp returns 0", lib.MLHangUp(), 0)
    check("disconnected", lib.MLGetState(), 0)
    check("baud = 0", lib.MLGetBaud(), 0)
    check("lastResult = 0 (Ok)", lib.MLGetLastResult(), RC_OK)

    # --- Test 4: Call with Busy ---
    print("Test 4: Call with Busy")
    lib.MLInit()
    lib.MLSetResponse(RC_BUSY)
    result = call_with_string(lib, lib.MLCall, "5559999")
    check("MLCall returns 7 (Busy)", result, RC_BUSY)
    check("not connected", lib.MLGetState(), 0)
    check("baud = 0", lib.MLGetBaud(), 0)

    # --- Test 5: Call with NoCarrier ---
    print("Test 5: Call with NoCarrier")
    lib.MLInit()
    lib.MLSetResponse(RC_NO_CARRIER)
    result = call_with_string(lib, lib.MLCall, "5550000")
    check("MLCall returns 3 (NoCarrier)", result, RC_NO_CARRIER)
    check("not connected", lib.MLGetState(), 0)

    # --- Test 6: Connect300 sets baud 300 ---
    print("Test 6: Connect300")
    lib.MLInit()
    lib.MLSetResponse(RC_CONNECT300)
    call_with_string(lib, lib.MLCall, "5551111")
    check("connected = 1", lib.MLGetState(), 1)
    check("baud = 300", lib.MLGetBaud(), 300)

    # --- Test 7: Connect1200 sets baud 1200 ---
    print("Test 7: Connect1200")
    lib.MLInit()
    lib.MLSetResponse(RC_CONNECT1200)
    call_with_string(lib, lib.MLCall, "5552222")
    check("connected = 1", lib.MLGetState(), 1)
    check("baud = 1200", lib.MLGetBaud(), 1200)

    # --- Test 8: Command with ATH does hangup ---
    print("Test 8: ATH command (hangup)")
    lib.MLInit()
    lib.MLSetResponse(RC_CONNECT2400)
    call_with_string(lib, lib.MLCall, "5551234")
    check("connected before ATH", lib.MLGetState(), 1)
    result = call_with_string(lib, lib.MLCommand, "ATH")
    check("ATH returns 0 (Ok)", result, RC_OK)
    check("disconnected after ATH", lib.MLGetState(), 0)
    check("baud = 0 after ATH", lib.MLGetBaud(), 0)

    # --- Test 9: Command with non-ATH returns preset ---
    print("Test 9: Non-ATH command")
    lib.MLInit()
    lib.MLSetResponse(RC_OK)
    result = call_with_string(lib, lib.MLCommand, "ATE1")
    check("ATE1 returns 0 (Ok)", result, RC_OK)

    # --- Test 10: ResultToText for each code ---
    print("Test 10: ResultToText")
    for code, expected_text in RESULT_TEXTS.items():
        actual = get_result_text(lib, code)
        check(f"ResultToText({code})", actual, expected_text)

    # --- Test 11: Invalid SetResponse returns -1 ---
    print("Test 11: Invalid SetResponse")
    # ctypes returns unsigned LONG by default; force signed
    lib.MLSetResponse.restype = ctypes.c_int32
    check("SetResponse(9) returns -1", lib.MLSetResponse(9), -1)
    check("SetResponse(42) returns -1", lib.MLSetResponse(42), -1)
    check("SetResponse(-1) returns -1", lib.MLSetResponse(-1), -1)
    # Valid codes still work
    check("SetResponse(0) returns 0", lib.MLSetResponse(0), 0)
    check("SetResponse(10) returns 0", lib.MLSetResponse(10), 0)
    check("SetResponse(99) returns 0", lib.MLSetResponse(99), 0)

    # --- Test 12: Multiple calls sequence ---
    print("Test 12: Multiple calls sequence")
    lib.MLInit()
    # First call: busy
    lib.MLSetResponse(RC_BUSY)
    call_with_string(lib, lib.MLCall, "5551234")
    check("first call busy, not connected", lib.MLGetState(), 0)
    # Second call: connect
    lib.MLSetResponse(RC_CONNECT1200)
    call_with_string(lib, lib.MLCall, "5551234")
    check("second call connected", lib.MLGetState(), 1)
    check("baud = 1200", lib.MLGetBaud(), 1200)
    # Hangup
    lib.MLHangUp()
    check("hung up", lib.MLGetState(), 0)
    # Third call: no dialtone
    lib.MLSetResponse(RC_NO_DIALTONE)
    call_with_string(lib, lib.MLCall, "5551234")
    check("third call no dialtone, not connected", lib.MLGetState(), 0)
    check("lastResult = 6", lib.MLGetLastResult(), RC_NO_DIALTONE)

    # --- Test 13: HangUp when not connected ---
    print("Test 13: HangUp when not connected")
    lib.MLInit()
    check("MLHangUp returns 0 even when idle", lib.MLHangUp(), 0)
    check("still idle", lib.MLGetState(), 0)

    # --- Summary ---
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    if failed:
        print("SOME TESTS FAILED")
        sys.exit(1)
    else:
        print("ALL TESTS PASSED")


if __name__ == "__main__":
    main()
