"""compare_cdb_unified.py — Compare CDB debugger trace with unified Prolog interpreter.

Runs three traces and compares them:
1. CDB attached to Python loading SensorLib.dll (compiled Clarion, ground truth)
2. Unified Prolog interpreter (simple parser + AST bridge + modular engine)
3. Original Prolog interpreter (prolog-interp/, for reference)

Usage: python compare_cdb_unified.py
"""
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SENSOR_DIR = os.path.join(SCRIPT_DIR, "..", "..", "clarion_projects", "sensor-data")
CDB = r"C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\cdb.exe"
PYTHON32 = os.path.expanduser(r"~\.pyenv\pyenv-win\versions\3.11.9-win32\python.exe")
ORIGINAL_DIR = os.path.join(SCRIPT_DIR, "..", "prolog-interp")


def clean_sensors_dat():
    dat = os.path.join(SENSOR_DIR, "Sensors.dat")
    if os.path.exists(dat):
        os.remove(dat)


def run_cdb_trace():
    """Run CDB and extract procedure-level trace from compiled DLL."""
    clean_sensors_dat()
    target = os.path.join(SENSOR_DIR, "cdb_trace_target.py")
    bp_script = os.path.join(SENSOR_DIR, "cdb_breakpoints.txt")

    result = subprocess.run(
        [CDB, "-G", "-o", "-cf", bp_script, PYTHON32, target],
        capture_output=True, text=True, timeout=60,
        cwd=SENSOR_DIR
    )

    lines = result.stdout.split("\n")
    trace = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("TRACE_ENTER "):
            proc = line[len("TRACE_ENTER "):]
            args = []
            i += 1
            while i < len(lines):
                l = lines[i].strip()
                if l.startswith("arg"):
                    i += 1
                    if i < len(lines):
                        val_match = re.search(r'([0-9a-f]{8})$', lines[i].strip())
                        if val_match:
                            args.append(int(val_match.group(1), 16))
                elif "TRACE_EXIT" in l:
                    while i < len(lines):
                        eax_match = re.match(r'eax=([0-9a-f]+)', lines[i].strip())
                        if eax_match:
                            ret = int(eax_match.group(1), 16)
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


def run_prolog_trace(label, cwd):
    """Run a Prolog interpreter trace and extract CALL lines."""
    clean_sensors_dat()
    result = subprocess.run(
        ["swipl", "-g", "main,halt", "-t", "halt(1)", "trace_sensorlib.pl"],
        capture_output=True, text=True, timeout=30,
        cwd=cwd
    )
    if result.returncode != 0:
        print(f"  WARNING: {label} exited with code {result.returncode}")
        if result.stderr:
            for line in result.stderr.strip().split("\n")[:5]:
                print(f"    {line}")
    trace = []
    for line in result.stdout.split("\n"):
        line = line.strip()
        if line.startswith("CALL ") and " -> " in line:
            trace.append(line)
    return trace


def compare(name_a, trace_a, name_b, trace_b):
    """Compare two traces and return (match_count, mismatch_count)."""
    max_len = max(len(trace_a), len(trace_b))
    matches = 0
    mismatches = 0
    for i in range(max_len):
        a = trace_a[i] if i < len(trace_a) else "<missing>"
        b = trace_b[i] if i < len(trace_b) else "<missing>"
        if a == b:
            print(f"  OK: {a}")
            matches += 1
        else:
            print(f"  MISMATCH:")
            print(f"    {name_a}: {a}")
            print(f"    {name_b}: {b}")
            mismatches += 1
    return matches, mismatches


def main():
    print("=" * 70)
    print("CDB vs Unified Interpreter vs Original Interpreter — Trace Comparison")
    print("=" * 70)

    print("\n[1/3] Running CDB trace (compiled SensorLib.dll) ...")
    cdb_trace = run_cdb_trace()
    for line in cdb_trace:
        print(f"  {line}")

    print(f"\n[2/3] Running unified interpreter trace ...")
    unified_trace = run_prolog_trace("unified", SCRIPT_DIR)
    for line in unified_trace:
        print(f"  {line}")

    print(f"\n[3/3] Running original interpreter trace ...")
    original_trace = run_prolog_trace("original", ORIGINAL_DIR)
    for line in original_trace:
        print(f"  {line}")

    # Compare CDB vs unified
    print(f"\n--- CDB vs Unified Interpreter ---")
    m1, mm1 = compare("CDB", cdb_trace, "Unified", unified_trace)

    # Compare CDB vs original
    print(f"\n--- CDB vs Original Interpreter ---")
    m2, mm2 = compare("CDB", cdb_trace, "Original", original_trace)

    # Compare unified vs original
    print(f"\n--- Unified vs Original Interpreter ---")
    m3, mm3 = compare("Unified", unified_trace, "Original", original_trace)

    # Summary
    print(f"\n{'=' * 70}")
    print(f"SUMMARY")
    print(f"  CDB (compiled):           {len(cdb_trace)} calls traced")
    print(f"  Unified interpreter:      {len(unified_trace)} calls traced")
    print(f"  Original interpreter:     {len(original_trace)} calls traced")
    print(f"  CDB vs Unified:           {m1} match, {mm1} mismatch")
    print(f"  CDB vs Original:          {m2} match, {mm2} mismatch")
    print(f"  Unified vs Original:      {m3} match, {mm3} mismatch")

    if mm1 == 0 and mm2 == 0 and mm3 == 0 and m1 > 0:
        print(f"\nRESULT: All three traces match ({m1} entries each)!")
        return 0
    else:
        print(f"\nRESULT: Mismatches detected")
        return 1


if __name__ == "__main__":
    sys.exit(main())
