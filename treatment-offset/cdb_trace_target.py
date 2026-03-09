"""Target script for CDB debugging of OffsetLib.dll.

CDB attaches to this 32-bit Python process and sets breakpoints on
OffsetLib's exported functions. The script exercises a treatment offset
entry scenario:
  - Set Anterior=15mm, Superior=20mm, Lateral=10mm
  - Set date=80001 (2026-03-09 in Clarion), time=4320000 (12:00:00)
  - Set DataSource=2 (kV Imaging)
  - Calculate magnitude: sqrt(15^2 + 20^2 + 10^2) = sqrt(725) = 26 (truncated)
  - Query all variables
  - Clear and query again
"""
import ctypes
import os
import sys

# Variable IDs matching OffsetLib.clw
VAR_ANTERIOR = 1
VAR_SUPERIOR = 2
VAR_LATERAL = 3
VAR_MAGNITUDE = 4
VAR_DATE = 5
VAR_TIME = 6
VAR_SOURCE = 7


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "OffsetLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("DLL_LOADED", flush=True)

    # Initialize
    lib.OLInit()

    # Set shift values (mm)
    lib.OLSetField(VAR_ANTERIOR, 15)    # 1.5 cm
    lib.OLSetField(VAR_SUPERIOR, 20)    # 2.0 cm
    lib.OLSetField(VAR_LATERAL, 10)     # 1.0 cm

    # Set date/time (Clarion format: days since 1800-12-28)
    # 2026-03-09 = 82252 in Clarion date
    lib.OLSetField(VAR_DATE, 82252)
    # 12:00:00 = 4320000 centiseconds from midnight
    lib.OLSetField(VAR_TIME, 4320000)

    # Set data source (2 = kV Imaging)
    lib.OLSetField(VAR_SOURCE, 2)

    # Calculate magnitude
    lib.OLCalcBtn()

    # Query all variable values after Calculate
    lib.OLGetVar(VAR_ANTERIOR)
    lib.OLGetVar(VAR_SUPERIOR)
    lib.OLGetVar(VAR_LATERAL)
    lib.OLGetVar(VAR_MAGNITUDE)
    lib.OLGetVar(VAR_DATE)
    lib.OLGetVar(VAR_TIME)
    lib.OLGetVar(VAR_SOURCE)

    # Clear
    lib.OLClearBtn()

    # Query all after Clear
    lib.OLGetVar(VAR_ANTERIOR)
    lib.OLGetVar(VAR_SUPERIOR)
    lib.OLGetVar(VAR_LATERAL)
    lib.OLGetVar(VAR_MAGNITUDE)
    lib.OLGetVar(VAR_SOURCE)

    return 0


if __name__ == "__main__":
    sys.exit(main())
