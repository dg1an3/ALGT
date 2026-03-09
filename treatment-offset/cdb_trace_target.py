"""Target script for CDB debugging of OffsetLib.dll.

CDB attaches to this 32-bit Python process and sets breakpoints on
OffsetLib's exported functions. Tests the direction dropdown and
sign-flip logic:
  - Set APValue=-15 (should flip to 15, APDir 1->2 Posterior)
  - Set SIValue=20  (stays positive, SIDir stays 1 Superior)
  - Set LRValue=-10 (should flip to 10, LRDir 1->2 Right)
  - Calculate magnitude: sqrt(15^2 + 20^2 + 10^2) = sqrt(725) = 26
  - Query all variables including directions
  - Clear and verify reset
"""
import ctypes
import os
import sys

# Variable IDs matching OffsetLib.clw
VAR_APVALUE = 1
VAR_APDIR = 2
VAR_SIVALUE = 3
VAR_SIDIR = 4
VAR_LRVALUE = 5
VAR_LRDIR = 6
VAR_MAGNITUDE = 7
VAR_DATE = 8
VAR_TIME = 9
VAR_SOURCE = 10


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "OffsetLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("DLL_LOADED", flush=True)

    # Initialize
    lib.OLInit()

    # Set shift values — negative values trigger sign-flip
    lib.OLSetField(VAR_APVALUE, -15)   # -15 -> APValue=15, APDir flips 1->2
    lib.OLSetField(VAR_SIVALUE, 20)    # positive, SIDir stays 1
    lib.OLSetField(VAR_LRVALUE, -10)   # -10 -> LRValue=10, LRDir flips 1->2

    # Set date/time/source
    lib.OLSetField(VAR_DATE, 82252)
    lib.OLSetField(VAR_TIME, 4320000)
    lib.OLSetField(VAR_SOURCE, 2)

    # Calculate magnitude
    lib.OLCalcBtn()

    # Query all variable values after Calculate
    lib.OLGetVar(VAR_APVALUE)
    lib.OLGetVar(VAR_APDIR)
    lib.OLGetVar(VAR_SIVALUE)
    lib.OLGetVar(VAR_SIDIR)
    lib.OLGetVar(VAR_LRVALUE)
    lib.OLGetVar(VAR_LRDIR)
    lib.OLGetVar(VAR_MAGNITUDE)
    lib.OLGetVar(VAR_DATE)
    lib.OLGetVar(VAR_TIME)
    lib.OLGetVar(VAR_SOURCE)

    # Clear
    lib.OLClearBtn()

    # Query key variables after Clear
    lib.OLGetVar(VAR_APVALUE)
    lib.OLGetVar(VAR_APDIR)
    lib.OLGetVar(VAR_SIVALUE)
    lib.OLGetVar(VAR_SIDIR)
    lib.OLGetVar(VAR_LRVALUE)
    lib.OLGetVar(VAR_LRDIR)
    lib.OLGetVar(VAR_MAGNITUDE)
    lib.OLGetVar(VAR_SOURCE)

    return 0


if __name__ == "__main__":
    sys.exit(main())
