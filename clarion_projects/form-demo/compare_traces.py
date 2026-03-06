"""
End-to-end trace comparison: GUI (pywinauto) vs Prolog interpreter.

1. Launches FormDemo_trace.exe via pywinauto, enters values, clicks buttons
2. Runs trace_formdemo.pl for the Prolog interpreter trace
3. Compares the two trace outputs line-by-line

Usage:
    cd form-demo
    ~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe compare_traces.py
"""

import os
import subprocess
import time

from pywinauto import Application

BIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin")
EXE_PATH = os.path.join(BIN_DIR, "FormDemo_trace.exe")
TRACE_LOG = os.path.join(BIN_DIR, "form_trace.log")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def run_gui_trace():
    """Run the Clarion GUI and return trace lines."""
    if os.path.exists(TRACE_LOG):
        os.remove(TRACE_LOG)

    app = Application(backend="win32").start(EXE_PATH, work_dir=BIN_DIR)
    dlg = app.window(title="Sensor Entry")
    dlg.wait("visible", timeout=10)
    time.sleep(0.5)

    # Enter values: SensorID=42, Reading=500, Weight=20
    dlg["Edit0"].set_edit_text("42")
    dlg["Edit2"].set_edit_text("500")
    dlg["Edit3"].set_edit_text("20")
    time.sleep(0.2)

    # Click Calculate, then Close
    dlg["Calculate"].click()
    time.sleep(0.3)
    dlg["Close"].click()
    app.wait_for_process_exit(timeout=5)

    with open(TRACE_LOG, "r", encoding="utf-8") as f:
        return [line.rstrip() for line in f.readlines()]


def run_prolog_trace():
    """Run the Prolog interpreter trace and return trace lines."""
    result = subprocess.run(
        ["swipl", "-g", "main,halt", "-t", "halt(1)", "trace_formdemo.pl"],
        capture_output=True, text=True, cwd=SCRIPT_DIR
    )
    lines = [l.rstrip() for l in result.stdout.strip().splitlines()]
    # Filter out 'return' lines (Clarion doesn't trace post-accept RETURN)
    return [l for l in lines if ": return" not in l]


def main():
    print("=== FormDemo Trace Comparison ===\n")

    print("1. Running GUI (pywinauto + FormDemo_trace.exe)...")
    gui_lines = run_gui_trace()
    print(f"   {len(gui_lines)} trace lines\n")

    print("2. Running Prolog interpreter (trace_formdemo.pl)...")
    prolog_lines = run_prolog_trace()
    print(f"   {len(prolog_lines)} trace lines\n")

    print("3. Comparing traces...")
    max_len = max(len(gui_lines), len(prolog_lines))
    mismatches = 0
    for i in range(max_len):
        gl = gui_lines[i] if i < len(gui_lines) else "<missing>"
        pl = prolog_lines[i] if i < len(prolog_lines) else "<missing>"
        if gl == pl:
            print(f"   {i+1:2d}  {gl}")
        else:
            print(f"   {i+1:2d}  GUI:    {gl}")
            print(f"       Prolog: {pl}")
            mismatches += 1

    print()
    if mismatches == 0 and len(gui_lines) == len(prolog_lines):
        print(f"RESULT: MATCH ({len(gui_lines)} lines identical)")
    else:
        print(f"RESULT: MISMATCH ({mismatches} differences, "
              f"GUI={len(gui_lines)} lines, Prolog={len(prolog_lines)} lines)")


if __name__ == "__main__":
    main()
