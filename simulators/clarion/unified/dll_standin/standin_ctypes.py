"""A stand-in for ctypes: CDLL('.../X.dll') runs X.clw in the simulator.

Numbers only. Anything that needs memory (buffers, pointers, structures)
raises NotImplementedError. See run_dll_test.py.
"""
import atexit
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
project_dir = None      # folder of the running test, set by run_dll_test.py
keep_going = False
failed_calls = []


class SimulatorError(RuntimeError):
    pass


class _Simple:
    def __init__(self, value=0):
        self.value = value


for _name in ('c_long c_ulong c_int c_uint c_short c_ushort c_byte c_ubyte c_int8 c_uint8 '
              'c_int16 c_uint16 c_int32 c_uint32 c_int64 c_uint64 c_longlong c_ulonglong '
              'c_bool c_char c_float c_double c_char_p c_void_p').split():
    globals()[_name] = type(_name, (_Simple,), {})


class Structure:
    pass


def _no_memory(*_args, **_kwargs):
    raise NotImplementedError('the simulator stand-in has no memory, so no buffers or pointers')


create_string_buffer = addressof = byref = POINTER = sizeof = cast = pointer = string_at = memmove = _no_memory


class _Function:
    def __init__(self, dll, name):
        self.dll, self.name, self.restype, self.argtypes = dll, name, c_long, None

    def __call__(self, *args):
        values = [a.value if isinstance(a, _Simple) else a for a in args]
        result = self.dll._invoke(self.name, values)
        if self.restype in (c_double, c_float):
            return float(result)
        return int(result)


class CDLL:
    def __init__(self, path, *_args, **_kwargs):
        module = os.path.splitext(os.path.basename(path))[0]
        self._functions = {}
        self._process = subprocess.Popen(
            ['swipl', '-q', '-g', 'main', '-t', 'halt', os.path.join(HERE, 'server.pl'), '--', _source(module)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, cwd=tempfile.mkdtemp(prefix='clarion_sim_'))
        atexit.register(self._process.kill)
        ready = self._answer()
        if ready != '@@READY':
            raise SimulatorError(f'{module}: {ready}')

    def _answer(self):
        while True:
            line = self._process.stdout.readline()
            if not line:
                raise SimulatorError('the simulator stopped')
            if line.startswith('@@'):
                return line.strip()

    def _invoke(self, name, values):
        for value in values:
            if not isinstance(value, (int, float)):
                _no_memory()
        arguments = ','.join(repr(v + 0) for v in values)
        self._process.stdin.write(f"c('{name}',[{arguments}]).\n")
        self._process.stdin.flush()
        answer = self._answer()
        if answer.startswith('@@N '):
            text = answer[4:]
            return float(text) if '.' in text or 'e' in text else int(text)
        if answer.startswith('@@T none'):        # a procedure with no result
            return 0
        error = f'{name}({arguments}): {answer[4:]}'
        failed_calls.append(error)
        if keep_going:
            print(f'    SIMULATOR ERROR {error[:160]}')
            return 0
        raise SimulatorError(error)

    def __getattr__(self, name):
        if name.startswith('_'):
            raise AttributeError(name)
        return self._functions.setdefault(name, _Function(self, name))


WinDLL = CDLL


class _Loader:
    def LoadLibrary(self, path):
        return CDLL(path)


cdll = windll = _Loader()


def _source(module):
    """X.clw beside the test, else in a sibling project."""
    projects = os.path.dirname(project_dir)
    for folder in [project_dir] + sorted(os.path.join(projects, d) for d in os.listdir(projects)):
        candidate = os.path.join(folder, module + '.clw')
        if os.path.isfile(candidate):
            return candidate
    raise OSError(f'no {module}.clw under {projects}')
