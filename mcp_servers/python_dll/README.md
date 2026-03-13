# Clarion DLL MCP Server (Python)

A Python-based [Model Context Protocol](https://modelcontextprotocol.io/) server that wraps a Clarion DLL, exposing its exported functions as MCP tools. This allows Claude Code (or any MCP client) to introspect and call functions in compiled Clarion DLLs.

## How It Works

1. **PE export parsing** — `dll_wrapper.py` reads the DLL's PE export table to discover exported function names, with no manual configuration needed.
2. **ctypes interop** — Functions are called via Python's `ctypes` module using the C calling convention (`cdecl`), matching Clarion's `,C` export attribute.
3. **MCP protocol** — `server.py` implements JSON-RPC 2.0 over stdio (newline-delimited JSON), the standard MCP transport.

## Prerequisites

- **32-bit Python 3.11+** — Clarion 11 produces 32-bit DLLs, so a 32-bit Python interpreter is required. The default path is `~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe`.
- **Built Clarion DLL** — By default uses `MathLib.dll` from `clarion_projects/python-dll/bin/`. Build it with:
  ```bash
  cd clarion_projects/python-dll
  "C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe" MathLib.cwproj //p:Configuration=Release
  ```
- **ClaRUN.dll** — Must be alongside the target DLL (copy from `C:\Clarion11.1\bin\ClaRUN.dll`).

## Tools

The server exposes three MCP tools:

| Tool | Description |
|------|-------------|
| `list_exports` | List all exported functions from the DLL |
| `call_function` | Call a function by name with integer arguments |
| `get_dll_info` | Get metadata (path, exports, calling convention) |

### call_function

Parameters:
- `function_name` (string, required) — Name of the exported function
- `args` (array of integers, optional) — Arguments to pass (all LONG / 32-bit signed)

Returns the integer result as text, e.g. `MathAdd(3, 4) = 7`.

## Usage

### With Claude Code

The `.mcp.json` in the repository root configures this server automatically:

```json
{
  "mcpServers": {
    "clarion-dll": {
      "type": "stdio",
      "command": "C:\\Users\\Derek\\.pyenv\\pyenv-win\\versions\\3.11.9-win32\\python.exe",
      "args": ["D:\\MUSIQ\\ALGT\\mcp_servers\\python_dll\\server.py"]
    }
  }
}
```

### Standalone

```bash
# Default (MathLib.dll)
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe server.py

# Custom DLL
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe server.py /path/to/MyLib.dll
```

### Using a Different DLL

Pass the DLL path as the first argument. The server will auto-discover all exports:

```bash
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe server.py ../../clarion_projects/sensor-data/bin/SensorLib.dll
```

## Testing

```bash
cd mcp_servers/python_dll
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_client.py
```

Expected output:
```
PASS: initialize
PASS: initialized notification sent
PASS: tools/list returned 3 tools: ['list_exports', 'call_function', 'get_dll_info']
PASS: list_exports
PASS: MathAdd(3, 4) = 7
PASS: Multiply(5, 6) = 30
PASS: MathAdd(-10, 10) = 0
PASS: get_dll_info
PASS: ping
PASS: shutdown

All tests passed!
```

## Files

| File | Description |
|------|-------------|
| `server.py` | MCP server — JSON-RPC 2.0 message loop and tool handlers |
| `dll_wrapper.py` | Generic Clarion DLL wrapper — PE parsing + ctypes calls |
| `test_client.py` | End-to-end test client |
| `start_server.sh` | Bash launch script |

## Architecture

```
Claude Code ──stdio──> server.py ──ctypes──> MathLib.dll (Clarion)
                          │                       │
                     JSON-RPC 2.0            C calling convention
                     (MCP protocol)          (32-bit LONG args/return)
```

## Limitations

- All function arguments and return values are assumed to be `LONG` (32-bit signed integer). String parameters and struct pointers are not yet supported through MCP tools (use `dll_wrapper.py` directly for those).
- Requires 32-bit Python due to Clarion's 32-bit output.
- Windows only (Clarion DLLs are Windows PE binaries).
