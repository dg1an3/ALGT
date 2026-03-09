"""Launch the Treatment Offset form from OffsetForm.dll.

The GUI window opens when OFRunForm() is called and blocks until the
user clicks Close. After it returns, we query all variable values
via OFGetVar().

Can be run standalone or under CDB for live breakpoint tracing:
  cdb -G -o -cf cdb_form_breakpoints.txt python run_form_dll.py
"""
import ctypes
import os
import sys

VAR_NAMES = {
    1: "APValue", 2: "APDir", 3: "SIValue", 4: "SIDir",
    5: "LRValue", 6: "LRDir", 7: "Magnitude",
    8: "OffsetDate", 9: "OffsetTime", 10: "DataSource"
}

DIR_LABELS = {
    2: {1: "Anterior", 2: "Posterior"},
    4: {1: "Superior", 2: "Inferior"},
    6: {1: "Left", 2: "Right"},
}


def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "bin", "OffsetForm.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.", file=sys.stderr)
        return 1

    lib = ctypes.CDLL(dll_path)

    print("=== OffsetForm.dll loaded ===")
    print("Opening form window... (interact with the GUI, then click Close)")
    print()

    # This call blocks until the user closes the form
    magnitude = lib.OFRunForm()
    print(f"\nOFRunForm returned: Magnitude = {magnitude} mm")

    # Query all variable values after the form closes
    print("\n--- Final variable values ---")
    for var_id in range(1, 11):
        val = lib.OFGetVar(var_id)
        name = VAR_NAMES.get(var_id, f"?{var_id}")
        extra = ""
        if var_id in DIR_LABELS:
            label = DIR_LABELS[var_id].get(val, "?")
            extra = f" ({label})"
        print(f"  {name} = {val}{extra}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
