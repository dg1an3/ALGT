"""Run a project's DLL test (or trace) against the simulator, without the DLL.

    python3 run_dll_test.py [--keep-going] ../../../../clarion_projects/dh-mtl/test_mtllib.py

The first call the simulator cannot run stops the test. With --keep-going such
calls return 0 and the run goes on, but always ends with exit code 1: a check
may pass by accident on that 0, so its PASS lines are not evidence.
"""
import os
import runpy
import sys

sys.dont_write_bytecode = True
import standin_ctypes


def main():
    args = sys.argv[1:]
    if '--keep-going' in args:
        args.remove('--keep-going')
        standin_ctypes.keep_going = True
    if len(args) != 1:
        print(__doc__)
        return 2
    test = os.path.abspath(args[0])
    standin_ctypes.project_dir = os.path.dirname(test)
    sys.modules['ctypes'] = standin_ctypes
    sys.path.insert(0, os.path.dirname(test))
    real_exists = os.path.exists
    os.path.exists = lambda p: str(p).lower().endswith('.dll') or real_exists(p)
    if not hasattr(os, 'add_dll_directory'):
        os.add_dll_directory = lambda p: None
    sys.argv = [test]
    code = 0
    try:
        runpy.run_path(test, run_name='__main__')
    except SystemExit as e:
        code = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
    except standin_ctypes.SimulatorError as e:
        print(f'SIMULATOR ERROR {e}')
        return 1
    if standin_ctypes.failed_calls:
        print(f'{len(standin_ctypes.failed_calls)} calls failed in the simulator')
        return 1
    return code


if __name__ == '__main__':
    sys.exit(main())
