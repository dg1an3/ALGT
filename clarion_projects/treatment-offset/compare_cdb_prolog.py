"""compare_cdb_prolog.py — Compare CDB debugger trace with Prolog interpreter trace
for OffsetLib (treatment offset variable comparison with direction sign-flip).

Runs both:
1. CDB attached to Python loading OffsetLib.dll (compiled Clarion)
2. SWI-Prolog interpreter computing the same operations

Compares function calls, arguments, return values, and internal variable
values — including sign-flip normalization and direction toggles.

Usage: python compare_cdb_prolog.py
"""
import datetime
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(SCRIPT_DIR, "comparison.log")
CDB = r"C:\Program Files (x86)\Windows Kits\10\Debuggers\x86\cdb.exe"
PYTHON32 = os.path.expanduser(r"~\.pyenv\pyenv-win\versions\3.11.9-win32\python.exe")

# Variable ID -> name mapping
VAR_NAMES = {
    1: "APValue", 2: "APDir", 3: "SIValue", 4: "SIDir",
    5: "LRValue", 6: "LRDir", 7: "Magnitude",
    8: "OffsetDate", 9: "OffsetTime", 10: "DataSource"
}

# Direction labels for readable output
DIR_LABELS = {
    2: {1: "Anterior", 2: "Posterior"},
    4: {1: "Superior", 2: "Inferior"},
    6: {1: "Left", 2: "Right"},
}


def run_cdb_trace():
    """Run CDB and extract procedure-level trace with variable values."""
    target = os.path.join(SCRIPT_DIR, "cdb_trace_target.py")
    bp_script = os.path.join(SCRIPT_DIR, "cdb_breakpoints.txt")

    result = subprocess.run(
        [CDB, "-G", "-o", "-cf", bp_script, PYTHON32, target],
        capture_output=True, text=True, timeout=60
    )
    output = result.stdout

    lines = output.split("\n")
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
                            val = int(val_match.group(1), 16)
                            if val >= 0x80000000:
                                val -= 0x100000000
                            args.append(val)
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


def run_prolog_trace():
    """Run Prolog interpreter and extract the same trace format."""
    result = subprocess.run(
        ["swipl", "-g", "main,halt", "-t", "halt(1)", "trace_offsetlib.pl"],
        capture_output=True, text=True, timeout=30,
        cwd=SCRIPT_DIR
    )
    trace = []
    for line in result.stdout.split("\n"):
        line = line.strip()
        if line.startswith("CALL ") and " -> " in line:
            trace.append(line)
    if result.returncode != 0 and not trace:
        print(f"Prolog stderr: {result.stderr}", file=sys.stderr)
    return trace


def annotate_line(line):
    """Add human-readable annotation for OLGetVar calls."""
    m = re.match(r'CALL OLGetVar\((\d+)\) -> (-?\d+)', line)
    if m:
        var_id = int(m.group(1))
        val = int(m.group(2))
        name = VAR_NAMES.get(var_id, f"?{var_id}")
        annotation = f"{name}={val}"
        # Add direction label for direction variables
        if var_id in DIR_LABELS:
            label = DIR_LABELS[var_id].get(val, "?")
            annotation += f" ({label})"
        return f"{line}  ({annotation})"
    return line


def log_and_print(line, log_lines):
    print(line)
    log_lines.append(line)


def main():
    log_lines = []
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    log_and_print("=" * 70, log_lines)
    log_and_print("OffsetLib: CDB vs Prolog — Direction Sign-Flip Comparison", log_lines)
    log_and_print(f"Run: {timestamp}", log_lines)
    log_and_print("=" * 70, log_lines)

    log_and_print("\n--- Running CDB trace (compiled OffsetLib.dll) ---", log_lines)
    cdb_trace = run_cdb_trace()
    for line in cdb_trace:
        log_and_print(f"  {annotate_line(line)}", log_lines)

    log_and_print("\n--- Running Prolog trace (interpreter) ---", log_lines)
    prolog_trace = run_prolog_trace()
    for line in prolog_trace:
        log_and_print(f"  {annotate_line(line)}", log_lines)

    log_and_print("\n--- Comparison ---", log_lines)
    max_len = max(len(cdb_trace), len(prolog_trace))
    all_match = True
    for i in range(max_len):
        cdb_line = cdb_trace[i] if i < len(cdb_trace) else "<missing>"
        prolog_line = prolog_trace[i] if i < len(prolog_trace) else "<missing>"
        if cdb_line == prolog_line:
            log_and_print(f"  OK: {annotate_line(cdb_line)}", log_lines)
        else:
            log_and_print(f"  MISMATCH:", log_lines)
            log_and_print(f"    CDB:    {annotate_line(cdb_line)}", log_lines)
            log_and_print(f"    Prolog: {annotate_line(prolog_line)}", log_lines)
            all_match = False

    log_and_print("", log_lines)
    if all_match and len(cdb_trace) == len(prolog_trace) and len(cdb_trace) > 0:
        log_and_print(f"RESULT: All {len(cdb_trace)} trace entries match!", log_lines)
        var_checks = sum(1 for l in cdb_trace if 'OLGetVar' in l)
        log_and_print(f"  (including {var_checks} variable value checks)", log_lines)
        result = 0
    else:
        log_and_print(f"RESULT: Traces differ (CDB: {len(cdb_trace)}, Prolog: {len(prolog_trace)})", log_lines)
        result = 1

    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write("\n".join(log_lines) + "\n\n")
    print(f"\nLog appended to: {LOG_FILE}")

    return result


if __name__ == "__main__":
    sys.exit(main())
