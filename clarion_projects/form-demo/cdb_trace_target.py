"""Target script for CDB debugging of FormLib.dll.

CDB attaches to this 32-bit Python process and sets breakpoints on
FormLib's exported functions. The script exercises the same event
sequence as calc_and_close.evt:
  set SensorID 42, set Reading 500, set Weight 80, set SensorType 2
  accepted CalcBtn -> Result = ((500*80)/100)*2 = 800
  then queries all variable values
  then ClearBtn, queries again
"""
import ctypes
import os
import sys


# Variable IDs matching FormLib.clw
VAR_SENSORID = 1
VAR_READING = 2
VAR_WEIGHT = 3
VAR_RESULT = 4
VAR_SENSORTYPE = 5


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "FormLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("DLL_LOADED", flush=True)

    # Initialize
    lib.FLInit()

    # Set fields (mirrors calc_and_close.evt)
    lib.FLSetField(VAR_SENSORID, 42)
    lib.FLSetField(VAR_READING, 500)
    lib.FLSetField(VAR_WEIGHT, 80)
    lib.FLSetField(VAR_SENSORTYPE, 2)

    # Calculate
    lib.FLCalcBtn()

    # Query all variable values after Calculate
    lib.FLGetVar(VAR_SENSORID)
    lib.FLGetVar(VAR_READING)
    lib.FLGetVar(VAR_WEIGHT)
    lib.FLGetVar(VAR_RESULT)
    lib.FLGetVar(VAR_SENSORTYPE)

    # Clear
    lib.FLClearBtn()

    # Query all variable values after Clear
    lib.FLGetVar(VAR_SENSORID)
    lib.FLGetVar(VAR_READING)
    lib.FLGetVar(VAR_WEIGHT)
    lib.FLGetVar(VAR_RESULT)
    lib.FLGetVar(VAR_SENSORTYPE)

    return 0


if __name__ == "__main__":
    sys.exit(main())
