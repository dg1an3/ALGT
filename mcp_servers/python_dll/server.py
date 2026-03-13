"""MCP server that wraps a Clarion DLL.

Implements JSON-RPC 2.0 over stdio (newline-delimited JSON) per the
Model Context Protocol specification. No external dependencies beyond
the Python standard library.

Usage:
    python server.py <path-to-dll>
    python server.py                  # defaults to MathLib.dll
"""

import json
import os
import sys

from dll_wrapper import ClarionDLL


# ---------------------------------------------------------------------------
# Signature metadata
# ---------------------------------------------------------------------------

def load_signatures(dll_path):
    """Load function signature metadata from a JSON file alongside the DLL.

    Searches for signatures/<DllName>.json in the server directory.
    Returns a dict mapping function names to their metadata, or {} if not found.
    """
    dll_name = os.path.splitext(os.path.basename(dll_path))[0]
    sig_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "signatures")
    sig_path = os.path.join(sig_dir, f"{dll_name}.json")
    if os.path.isfile(sig_path):
        with open(sig_path, "r") as f:
            data = json.load(f)
        return data.get("functions", {})
    return {}

# ---------------------------------------------------------------------------
# JSON-RPC 2.0 helpers
# ---------------------------------------------------------------------------

def read_message(stream):
    """Read one newline-delimited JSON message from stream."""
    while True:
        line = stream.readline()
        if not line:
            return None  # EOF
        line = line.strip()
        if line:
            return json.loads(line)


def write_message(obj, stream):
    """Write one newline-delimited JSON message to stream."""
    stream.write(json.dumps(obj) + "\n")
    stream.flush()


def make_response(id, result):
    return {"jsonrpc": "2.0", "id": id, "result": result}


def make_error(id, code, message, data=None):
    err = {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}
    if data is not None:
        err["error"]["data"] = data
    return err


def tool_result_text(text):
    return {"content": [{"type": "text", "text": text}]}


def tool_result_error(text):
    return {"isError": True, "content": [{"type": "text", "text": text}]}


def log(msg):
    """Log to stderr (doesn't interfere with stdio protocol)."""
    print(f"[python_dll_mcp] {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

def build_tools(dll, signatures):
    """Return MCP tool definitions based on the loaded DLL and signatures."""
    dll_name = os.path.basename(dll.dll_path)
    exports = dll.list_exports()

    # Build per-function description with parameter info
    func_details = []
    for name in exports:
        sig = signatures.get(name)
        if sig:
            params = sig.get("params", [])
            param_str = ", ".join(f"{p['name']}: {p['type']}" for p in params)
            desc = sig.get("description", "")
            func_details.append(f"  {name}({param_str}) -> {sig.get('returns', 'LONG')}: {desc}")
        else:
            func_details.append(f"  {name}(…) -> LONG: (no signature info)")
    func_help = "\n".join(func_details)

    tools = [
        {
            "name": "list_exports",
            "description": f"List all exported functions from {dll_name} with their signatures",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
        {
            "name": "call_function",
            "description": (
                f"Call an exported function in {dll_name}. "
                "All arguments and return values are 32-bit integers (LONG).\n"
                f"Functions:\n{func_help}"
            ),
            "inputSchema": {
                "type": "object",
                "properties": {
                    "function_name": {
                        "type": "string",
                        "description": "Name of the exported function to call",
                        "enum": exports,
                    },
                    "args": {
                        "type": "array",
                        "items": {"type": "integer"},
                        "description": "List of integer arguments to pass (order matters)",
                        "default": [],
                    },
                },
                "required": ["function_name"],
            },
        },
        {
            "name": "get_dll_info",
            "description": f"Get metadata about the loaded DLL ({dll_name})",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
    ]
    return tools


# ---------------------------------------------------------------------------
# Tool handlers
# ---------------------------------------------------------------------------

def handle_list_exports(dll, args):
    exports = dll.list_exports()
    sigs = _current_signatures  # set in main()
    text = f"Exported functions ({len(exports)}):\n"
    for name in exports:
        sig = sigs.get(name)
        if sig:
            params = sig.get("params", [])
            param_str = ", ".join(f"{p['name']}: {p['type']}" for p in params)
            desc = sig.get("description", "")
            text += f"  - {name}({param_str}) -> {sig.get('returns', 'LONG')}: {desc}\n"
        else:
            text += f"  - {name}(…) -> LONG\n"
    return tool_result_text(text)


def handle_call_function(dll, args):
    func_name = args.get("function_name")
    func_args = args.get("args", [])
    if not func_name:
        return tool_result_error("Missing required parameter: function_name")
    try:
        result = dll.call(func_name, func_args)
        return tool_result_text(
            f"{func_name}({', '.join(str(a) for a in func_args)}) = {result}"
        )
    except Exception as e:
        return tool_result_error(f"Error calling {func_name}: {e}")


def handle_get_dll_info(dll, args):
    exports = dll.list_exports()
    sigs = _current_signatures
    has_sigs = any(name in sigs for name in exports)
    info = (
        f"DLL: {dll.dll_path}\n"
        f"Exports: {len(exports)}\n"
        f"Functions: {', '.join(exports)}\n"
        f"Calling convention: C (cdecl)\n"
        f"Argument/return type: LONG (32-bit signed integer)\n"
        f"Signature metadata: {'loaded' if has_sigs else 'not available'}\n"
    )
    return tool_result_text(info)


_current_signatures = {}  # populated in main()

TOOL_HANDLERS = {
    "list_exports": handle_list_exports,
    "call_function": handle_call_function,
    "get_dll_info": handle_get_dll_info,
}


# ---------------------------------------------------------------------------
# MCP message loop
# ---------------------------------------------------------------------------

SERVER_NAME = "clarion-dll-mcp"
SERVER_VERSION = "0.1.0"
PROTOCOL_VERSION = "2024-11-05"


def handle_message(msg, dll, tools):
    """Handle a single JSON-RPC message and return a response (or None for notifications)."""
    method = msg.get("method", "")
    msg_id = msg.get("id")
    params = msg.get("params", {})

    if method == "initialize":
        return make_response(msg_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {
                "name": SERVER_NAME,
                "version": SERVER_VERSION,
            },
        })

    elif method == "notifications/initialized":
        # Client confirmation — no response needed
        return None

    elif method == "tools/list":
        return make_response(msg_id, {"tools": tools})

    elif method == "tools/call":
        tool_name = params.get("name", "")
        tool_args = params.get("arguments", {})
        handler = TOOL_HANDLERS.get(tool_name)
        if handler is None:
            return make_response(msg_id, tool_result_error(f"Unknown tool: {tool_name}"))
        try:
            result = handler(dll, tool_args)
        except Exception as e:
            result = tool_result_error(f"Internal error: {e}")
        return make_response(msg_id, result)

    elif method == "ping":
        return make_response(msg_id, {})

    elif method == "shutdown":
        return make_response(msg_id, {})

    else:
        return make_error(msg_id, -32601, f"Method not found: {method}")


def main():
    # Determine DLL path from argv or default
    if len(sys.argv) > 1:
        dll_path = sys.argv[1]
    else:
        # Default: MathLib.dll from the python-dll Clarion project
        script_dir = os.path.dirname(os.path.abspath(__file__))
        dll_path = os.path.join(
            script_dir, "..", "..", "clarion_projects", "python-dll", "bin", "MathLib.dll"
        )

    dll_path = os.path.abspath(dll_path)
    log(f"Loading DLL: {dll_path}")

    try:
        dll = ClarionDLL(dll_path)
    except Exception as e:
        log(f"Failed to load DLL: {e}")
        sys.exit(1)

    log(f"Loaded {len(dll.list_exports())} exports: {dll.list_exports()}")

    global _current_signatures
    _current_signatures = load_signatures(dll_path)
    if _current_signatures:
        log(f"Loaded signatures for: {', '.join(_current_signatures.keys())}")
    else:
        log("No signature metadata found (functions will have generic descriptions)")

    tools = build_tools(dll, _current_signatures)
    log(f"Server ready ({SERVER_NAME} v{SERVER_VERSION})")

    # Message loop
    shutdown = False
    while not shutdown:
        try:
            msg = read_message(sys.stdin)
        except json.JSONDecodeError as e:
            write_message(make_error(None, -32700, f"Parse error: {e}"), sys.stdout)
            continue

        if msg is None:
            log("EOF on stdin, shutting down")
            break

        log(f"<-- {msg.get('method', '???')} id={msg.get('id')}")

        if msg.get("method") == "shutdown":
            response = handle_message(msg, dll, tools)
            if response:
                write_message(response, sys.stdout)
            shutdown = True
            continue

        response = handle_message(msg, dll, tools)
        if response is not None:
            write_message(response, sys.stdout)


if __name__ == "__main__":
    main()
