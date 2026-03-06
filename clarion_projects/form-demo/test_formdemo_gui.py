"""
GUI automation test for FormDemo_trace.exe using pywinauto.

Launches the instrumented Clarion form, enters values, clicks buttons,
and produces a trace log for comparison with the Prolog interpreter's
event simulation.

Usage:
    cd form-demo
    ~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_formdemo_gui.py
"""

import os
import time

from pywinauto import Application

BIN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin")
EXE_PATH = os.path.join(BIN_DIR, "FormDemo_trace.exe")
TRACE_LOG = os.path.join(BIN_DIR, "form_trace.log")


def run_gui_test():
    # Clean up old trace log
    if os.path.exists(TRACE_LOG):
        os.remove(TRACE_LOG)

    # Launch the app
    app = Application(backend="win32").start(EXE_PATH, work_dir=BIN_DIR)
    dlg = app.window(title="Sensor Entry")
    dlg.wait("visible", timeout=10)
    time.sleep(0.5)

    # Enter values: SensorID=42, Reading=500, Weight=20
    dlg["Edit0"].set_edit_text("42")
    dlg["Edit2"].set_edit_text("500")
    dlg["Edit3"].set_edit_text("20")
    time.sleep(0.2)

    # Using default list selection: Standard (index 1)
    # Clarion custom ClaDrop controls don't respond to standard
    # Win32 keyboard/selection APIs from pywinauto

    # Click Calculate
    dlg["Calculate"].click()
    time.sleep(0.3)

    # Read the Result from the ClaString control
    result_ctrl = dlg.child_window(class_name_re="ClaString_.*")
    result_text = result_ctrl.window_text().strip()
    print(f"Result after Calculate: '{result_text}'")

    # Verify: ((500 * 20) / 100) * 1 = 100  (Standard = index 1)
    expected = 100
    try:
        actual = int(result_text)
        status = "PASS" if actual == expected else "FAIL"
        print(f"  Calculate (Standard type): {actual} == {expected}? [{status}]")
    except ValueError:
        print(f"  Could not parse result '{result_text}' [FAIL]")

    # Click Close
    dlg["Close"].click()
    app.wait_for_process_exit(timeout=5)

    # Read the trace log
    if os.path.exists(TRACE_LOG):
        with open(TRACE_LOG, "r", encoding="utf-8") as f:
            trace_lines = [l.rstrip() for l in f.readlines()]
        print(f"\n--- GUI trace ({len(trace_lines)} lines) ---")
        for line in trace_lines:
            print(line)
        return trace_lines
    else:
        print("\n[WARN] No trace log produced")
        return []


if __name__ == "__main__":
    run_gui_test()
