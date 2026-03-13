"""Generic wrapper for Clarion DLLs using ctypes.

Loads a 32-bit Clarion DLL, discovers exported symbols via PE parsing,
and provides a call interface with LONG argument/return types (the Clarion default).
"""

import ctypes
import os
import struct


def _parse_pe_exports(dll_path):
    """Parse PE export table to discover exported function names.

    Returns a list of exported symbol names from the DLL.
    """
    exports = []
    with open(dll_path, "rb") as f:
        # DOS header
        magic = f.read(2)
        if magic != b"MZ":
            return exports
        f.seek(0x3C)
        pe_offset = struct.unpack("<I", f.read(4))[0]

        # PE signature
        f.seek(pe_offset)
        sig = f.read(4)
        if sig != b"PE\x00\x00":
            return exports

        # COFF header
        f.read(2)  # Machine
        num_sections = struct.unpack("<H", f.read(2))[0]
        f.read(12)  # skip timestamp, symbol table, num symbols
        optional_header_size = struct.unpack("<H", f.read(2))[0]
        f.read(2)  # Characteristics

        optional_header_start = f.tell()
        opt_magic = struct.unpack("<H", f.read(2))[0]
        if opt_magic == 0x10B:  # PE32
            export_dir_offset = 96
        elif opt_magic == 0x20B:  # PE32+
            export_dir_offset = 112
        else:
            return exports

        f.seek(optional_header_start + export_dir_offset)
        export_rva = struct.unpack("<I", f.read(4))[0]
        export_size = struct.unpack("<I", f.read(4))[0]
        if export_rva == 0:
            return exports

        # Read section headers to map RVA to file offset
        f.seek(optional_header_start + optional_header_size)
        sections = []
        for _ in range(num_sections):
            sec_data = f.read(40)
            virt_size = struct.unpack("<I", sec_data[8:12])[0]
            virt_addr = struct.unpack("<I", sec_data[12:16])[0]
            raw_size = struct.unpack("<I", sec_data[16:20])[0]
            raw_ptr = struct.unpack("<I", sec_data[20:24])[0]
            sections.append((virt_addr, virt_size, raw_ptr, raw_size))

        def rva_to_offset(rva):
            for va, vs, rp, rs in sections:
                if va <= rva < va + max(vs, rs):
                    return rp + (rva - va)
            return None

        # Export directory
        export_file_offset = rva_to_offset(export_rva)
        if export_file_offset is None:
            return exports
        f.seek(export_file_offset)
        f.read(12)  # Characteristics, TimeDateStamp, Version
        f.read(4)   # Name RVA
        f.read(4)   # OrdinalBase
        num_functions = struct.unpack("<I", f.read(4))[0]
        num_names = struct.unpack("<I", f.read(4))[0]
        f.read(4)   # AddressOfFunctions RVA
        names_rva = struct.unpack("<I", f.read(4))[0]

        # Read name pointers
        names_offset = rva_to_offset(names_rva)
        if names_offset is None:
            return exports
        f.seek(names_offset)
        name_rvas = [struct.unpack("<I", f.read(4))[0] for _ in range(num_names)]

        for name_rva in name_rvas:
            name_offset = rva_to_offset(name_rva)
            if name_offset is None:
                continue
            f.seek(name_offset)
            name_bytes = b""
            while True:
                ch = f.read(1)
                if ch == b"\x00" or ch == b"":
                    break
                name_bytes += ch
            exports.append(name_bytes.decode("ascii", errors="replace"))

    return exports


class ClarionDLL:
    """Wrapper around a Clarion DLL loaded via ctypes.

    Discovers exports via PE parsing and provides a generic call interface.
    All parameters and return values default to LONG (c_long) since that is
    the standard Clarion numeric type for C-convention exports.
    """

    def __init__(self, dll_path):
        self.dll_path = os.path.abspath(dll_path)
        if not os.path.isfile(self.dll_path):
            raise FileNotFoundError(f"DLL not found: {self.dll_path}")

        # Discover exports before loading (PE parsing doesn't need the DLL loaded)
        self._export_names = _parse_pe_exports(self.dll_path)

        # Load the DLL - add directory to search path for ClaRUN.dll
        dll_dir = os.path.dirname(self.dll_path)
        os.environ["PATH"] = dll_dir + os.pathsep + os.environ.get("PATH", "")
        self._lib = ctypes.CDLL(self.dll_path)

        # Build function metadata: map name -> {argtypes, restype}
        # By default assume all exports take/return LONG. Caller can override.
        self._functions = {}
        for name in self._export_names:
            try:
                func = getattr(self._lib, name)
                self._functions[name] = {
                    "argtypes": [],  # will be set per-call
                    "restype": ctypes.c_long,
                }
                func.restype = ctypes.c_long
            except AttributeError:
                pass  # skip symbols that ctypes can't resolve

    def list_exports(self):
        """Return list of exported function names."""
        return sorted(self._functions.keys())

    def set_signature(self, name, num_args, arg_type=ctypes.c_long, res_type=ctypes.c_long):
        """Set the signature for a function (number of LONG args and return type)."""
        if name not in self._functions:
            raise ValueError(f"Unknown export: {name}")
        func = getattr(self._lib, name)
        func.argtypes = [arg_type] * num_args
        func.restype = res_type
        self._functions[name]["argtypes"] = [arg_type] * num_args
        self._functions[name]["restype"] = res_type

    def call(self, name, args=None):
        """Call an exported function by name with optional list of integer args.

        Returns the integer result.
        """
        if name not in self._functions:
            raise ValueError(f"Unknown export: {name}")
        if args is None:
            args = []

        func = getattr(self._lib, name)
        # Set argtypes based on number of args provided (all LONG)
        func.argtypes = [ctypes.c_long] * len(args)
        func.restype = self._functions[name]["restype"]

        result = func(*[ctypes.c_long(a) for a in args])
        return int(result)
