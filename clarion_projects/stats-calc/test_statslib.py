import ctypes
from ctypes import wintypes
import os

# Define the StatsGroup structure to match Clarion GROUP
class StatsGroup(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("mean", ctypes.c_int32),
        ("median", ctypes.c_int32),
        ("classification", ctypes.c_int32),
    ]

def main():
    dll_path = os.path.join(os.getcwd(), "bin", "StatsLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return

    # Load the DLL
    try:
        # Clarion DLLs often need ClaRUN.dll in the same directory
        # We copied it earlier to bin/
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return

    # Call CalculateStats(3)
    # 10 + 20 + 30 = 60. 60 / 3 = 20.
    # Classify(20) should return 2 (Medium).
    print("Calling CalculateStats(3)...")
    res = lib.CalculateStats(3)
    print(f"CalculateStats returned: {res}")

    if res == 0:
        # Get the results
        stats = StatsGroup()
        lib.GetStats(ctypes.addressof(stats))
        
        print("\nResults:")
        print(f"  Mean: {stats.mean}")
        print(f"  Median: {stats.median}")
        
        class_map = {1: "Low", 2: "Medium", 3: "High"}
        class_str = class_map.get(stats.classification, "Unknown")
        print(f"  Classification: {stats.classification} ({class_str})")
        
        # Verify expectations
        if stats.mean == 20 and stats.classification == 2:
            print("\nSUCCESS: Results match expectations.")
        else:
            print("\nFAILURE: Results do not match expectations.")
    else:
        print("CalculateStats failed.")

if __name__ == "__main__":
    main()
