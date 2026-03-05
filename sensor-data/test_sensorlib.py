import ctypes
import os

class SensorRecord(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("id", ctypes.c_int32),
        ("reading", ctypes.c_int32),
        ("weight", ctypes.c_int32),
        ("processed", ctypes.c_int32),
        ("status", ctypes.c_int32),
    ]

def main():
    dll_path = os.path.join(os.getcwd(), "bin", "SensorLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        return

    # Clean up previous data
    if os.path.exists("Sensors.dat"):
        os.remove("Sensors.dat")

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        return

    print("Opening sensor store...")
    if lib.SSOpen() != 0:
        print("Failed to open sensor store.")
        return

    # Add some readings
    # (100 * 50) / 100 = 50
    # (200 * 25) / 100 = 50
    # (300 * 10) / 100 = 30
    # Total Value = 50 + 50 + 30 = 130
    # Total Weight = 50 + 25 + 10 = 85
    # Expected Weighted Average: (130 * 100) / 85 = 152
    print("Adding readings...")
    lib.SSAddReading(1, 100, 50)
    lib.SSAddReading(2, 200, 25)
    lib.SSAddReading(3, 300, 10)

    # Calculate average
    avg = lib.SSCalculateWeightedAverage()
    print(f"Weighted Average (scaled by 100): {avg}")
    if avg == 152:
        print("SUCCESS: Average matches expectation (152).")
    else:
        print(f"FAILURE: Expected 152, got {avg}.")

    # Get a specific reading
    rec = SensorRecord()
    print("Getting reading for ID 2...")
    if lib.SSGetReading(2, ctypes.addressof(rec)) == 0:
        print(f"  Reading: {rec.reading}, Weight: {rec.weight}, Processed: {rec.processed}")
        if rec.processed == 50:
            print("  SUCCESS: Processed value matches (50).")
    else:
        print("  FAILURE: Could not get reading for ID 2.")

    # Cleanup low readings (threshold 150)
    # ID 1 (100) and ID 2 (200) are > 150? No, ID 1 is 100, ID 2 is 200.
    # Reading < 150: ID 1 (100).
    print("Cleaning up readings below 150...")
    removed = lib.SSCleanupLowReadings(150)
    print(f"  Removed: {removed}")
    if removed == 1:
        print("  SUCCESS: Removed 1 reading (ID 1).")
    else:
        print(f"  FAILURE: Expected 1 removed, got {removed}.")

    # Re-calculate average
    # Remaining: ID 2 (Processed=50, Weight=25), ID 3 (Processed=30, Weight=10)
    # Total Value = 50 + 30 = 80
    # Total Weight = 25 + 10 = 35
    # Expected Average: (80 * 100) / 35 = 228
    avg2 = lib.SSCalculateWeightedAverage()
    print(f"New Weighted Average: {avg2}")
    if avg2 == 228:
        print("SUCCESS: New average matches expectation (228).")
    else:
        print(f"FAILURE: Expected 228, got {avg2}.")

    lib.SSClose()
    print("Store closed.")

if __name__ == "__main__":
    main()
