"""Test calling Clarion DLL from Python using ctypes."""

import ctypes
import os

# Load the DLL from bin/ relative to this script
dll_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin")
dll_path = os.path.join(dll_dir, "MathLib.dll")

print(f"Loading DLL from: {dll_path}")
lib = ctypes.CDLL(dll_path)

# Declare function signatures
lib.MathAdd.argtypes = [ctypes.c_long, ctypes.c_long]
lib.MathAdd.restype = ctypes.c_long

lib.Multiply.argtypes = [ctypes.c_long, ctypes.c_long]
lib.Multiply.restype = ctypes.c_long

# Test MathAdd
result = lib.MathAdd(3, 4)
print(f"MathAdd(3, 4) = {result}")
assert result == 7, f"Expected 7, got {result}"

# Test Multiply
result = lib.Multiply(5, 6)
print(f"Multiply(5, 6) = {result}")
assert result == 30, f"Expected 30, got {result}"

# Edge cases
result = lib.MathAdd(-10, 10)
print(f"MathAdd(-10, 10) = {result}")
assert result == 0, f"Expected 0, got {result}"

result = lib.Multiply(0, 999)
print(f"Multiply(0, 999) = {result}")
assert result == 0, f"Expected 0, got {result}"

print("\nAll tests passed!")
