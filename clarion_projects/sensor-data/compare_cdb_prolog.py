"""compare_cdb_prolog.py — Compare CDB debugger trace with Prolog interpreter trace.

Runs both:
1. CDB attached to Python loading SensorLib.dll (compiled Clarion)
2. SWI-Prolog interpreter executing SensorLib.clw source

Extracts procedure ENTER/EXIT events with arguments and return values,
then compares them line by line.

Usage: python compare_cdb_prolog.py
"""
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CDB = r"C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\cdb.exe"
PYTHON32 = os.path.expanduser(r"~\.pyenv\pyenv-win\versions\3.11.9-win32\python.exe")
PROLOG_DIR = os.path.join(SCRIPT_DIR, "..", "..", "clarion_simulators", "unified")


def run_cdb_trace():
    """Run CDB and extract procedure-level trace."""
    # Clean up previous data
    dat = os.path.join(SCRIPT_DIR, "Sensors.dat")
    if os.path.exists(dat):
        os.remove(dat)

    target = os.path.join(SCRIPT_DIR, "cdb_trace_target.py")
    bp_script = os.path.join(SCRIPT_DIR, "cdb_breakpoints.txt")

    result = subprocess.run(
        [CDB, "-G", "-o", "-cf", bp_script, PYTHON32, target],
        capture_output=True, text=True, timeout=60
    )
    output = result.stdout

    # Parse TRACE_ENTER / TRACE_EXIT pairs with args and return values
    lines = output.split("\n")
    trace = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("TRACE_ENTER "):
            proc = line[len("TRACE_ENTER "):]
            args = []
            i += 1
            # Collect arg lines until we hit TRACE_EXIT
            while i < len(lines):
                l = lines[i].strip()
                if l.startswith("arg"):
                    # Next line has the hex value
                    i += 1
                    if i < len(lines):
                        val_match = re.search(r'([0-9a-f]{8})$', lines[i].strip())
                        if val_match:
                            args.append(int(val_match.group(1), 16))
                elif "TRACE_EXIT" in l:
                    # Find eax value
                    while i < len(lines):
                        eax_match = re.match(r'eax=([0-9a-f]+)', lines[i].strip())
                        if eax_match:
                            ret = int(eax_match.group(1), 16)
                            # Handle signed 32-bit return values
                            if ret >= 0x80000000:
                                ret -= 0x100000000
                            arg_str = ", ".join(str(a) for a in args)
                            trace.append(f"CALL {proc}({arg_str}) -> {ret}")
                            break
                        i += 1
                    break
                i += 1
        i += 1
    return trace


def run_prolog_trace():
    """Run Prolog interpreter and extract procedure-level trace."""
    # Clean up previous data
    dat = os.path.join(SCRIPT_DIR, "Sensors.dat")
    if os.path.exists(dat):
        os.remove(dat)

    result = subprocess.run(
        ["swipl", "-g", "main,halt", "-t", "halt(1)", "trace_sensorlib.pl"],
        capture_output=True, text=True, timeout=30,
        cwd=PROLOG_DIR
    )
    trace = []
    for line in result.stdout.split("\n"):
        line = line.strip()
        if line.startswith("CALL ") and " -> " in line:
            trace.append(line)
    return trace


def main():
    print("=" * 60)
    print("CDB Debugger vs Prolog Interpreter Trace Comparison")
    print("=" * 60)

    print("\n--- Running CDB trace (compiled DLL) ---")
    cdb_trace = run_cdb_trace()
    for line in cdb_trace:
        print(f"  {line}")

    print("\n--- Running Prolog trace (interpreter) ---")
    prolog_trace = run_prolog_trace()
    for line in prolog_trace:
        print(f"  {line}")

    print("\n--- Comparison ---")
    max_len = max(len(cdb_trace), len(prolog_trace))
    all_match = True
    for i in range(max_len):
        cdb_line = cdb_trace[i] if i < len(cdb_trace) else "<missing>"
        prolog_line = prolog_trace[i] if i < len(prolog_trace) else "<missing>"
        if cdb_line == prolog_line:
            print(f"  OK: {cdb_line}")
        else:
            print(f"  MISMATCH:")
            print(f"    CDB:    {cdb_line}")
            print(f"    Prolog: {prolog_line}")
            all_match = False

    print()
    if all_match and len(cdb_trace) == len(prolog_trace) and len(cdb_trace) > 0:
        print(f"RESULT: All {len(cdb_trace)} trace entries match!")
        return 0
    else:
        print(f"RESULT: Traces differ (CDB: {len(cdb_trace)}, Prolog: {len(prolog_trace)})")
        return 1


if __name__ == "__main__":
    sys.exit(main())
