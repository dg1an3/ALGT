"""Test client for the Clarion DLL MCP server.

Launches the server as a subprocess, sends JSON-RPC messages over stdio,
and validates responses.
"""

import json
import os
import subprocess
import sys

PYTHON = os.environ.get(
    "PYTHON32",
    os.path.expanduser("~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe"),
)
SERVER_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server.py")


def send(proc, msg):
    """Send a JSON-RPC message and return the response."""
    line = json.dumps(msg) + "\n"
    proc.stdin.write(line)
    proc.stdin.flush()

    # Read response (skip empty lines)
    while True:
        resp_line = proc.stdout.readline()
        if not resp_line:
            return None
        resp_line = resp_line.strip()
        if resp_line:
            return json.loads(resp_line)


def send_notification(proc, msg):
    """Send a JSON-RPC notification (no response expected)."""
    line = json.dumps(msg) + "\n"
    proc.stdin.write(line)
    proc.stdin.flush()


def main():
    print(f"Starting server: {PYTHON} {SERVER_SCRIPT}")
    proc = subprocess.Popen(
        [PYTHON, SERVER_SCRIPT],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=os.path.dirname(SERVER_SCRIPT),
    )

    try:
        # 1. Initialize
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test_client", "version": "0.1.0"},
            },
        })
        assert resp["result"]["protocolVersion"] == "2024-11-05", f"Bad protocol: {resp}"
        assert resp["result"]["serverInfo"]["name"] == "clarion-dll-mcp"
        print("PASS: initialize")

        # 2. Initialized notification
        send_notification(proc, {
            "jsonrpc": "2.0", "method": "notifications/initialized",
        })
        print("PASS: initialized notification sent")

        # 3. List tools
        resp = send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools = resp["result"]["tools"]
        tool_names = [t["name"] for t in tools]
        assert "list_exports" in tool_names, f"Missing list_exports: {tool_names}"
        assert "call_function" in tool_names, f"Missing call_function: {tool_names}"
        assert "get_dll_info" in tool_names, f"Missing get_dll_info: {tool_names}"
        print(f"PASS: tools/list returned {len(tools)} tools: {tool_names}")

        # 4. Call list_exports tool
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 3, "method": "tools/call",
            "params": {"name": "list_exports", "arguments": {}},
        })
        text = resp["result"]["content"][0]["text"]
        assert "MathAdd" in text, f"Missing MathAdd in exports: {text}"
        assert "Multiply" in text, f"Missing Multiply in exports: {text}"
        print(f"PASS: list_exports\n  {text.strip()}")

        # 5. Call MathAdd(3, 4) -> 7
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 4, "method": "tools/call",
            "params": {"name": "call_function", "arguments": {"function_name": "MathAdd", "args": [3, 4]}},
        })
        text = resp["result"]["content"][0]["text"]
        assert "= 7" in text, f"Expected 7: {text}"
        print(f"PASS: {text.strip()}")

        # 6. Call Multiply(5, 6) -> 30
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 5, "method": "tools/call",
            "params": {"name": "call_function", "arguments": {"function_name": "Multiply", "args": [5, 6]}},
        })
        text = resp["result"]["content"][0]["text"]
        assert "= 30" in text, f"Expected 30: {text}"
        print(f"PASS: {text.strip()}")

        # 7. Edge case: MathAdd(-10, 10) -> 0
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 6, "method": "tools/call",
            "params": {"name": "call_function", "arguments": {"function_name": "MathAdd", "args": [-10, 10]}},
        })
        text = resp["result"]["content"][0]["text"]
        assert "= 0" in text, f"Expected 0: {text}"
        print(f"PASS: {text.strip()}")

        # 8. get_dll_info
        resp = send(proc, {
            "jsonrpc": "2.0", "id": 7, "method": "tools/call",
            "params": {"name": "get_dll_info", "arguments": {}},
        })
        text = resp["result"]["content"][0]["text"]
        assert "MathLib.dll" in text, f"Missing DLL name: {text}"
        print(f"PASS: get_dll_info")

        # 9. Ping
        resp = send(proc, {"jsonrpc": "2.0", "id": 8, "method": "ping", "params": {}})
        assert resp["id"] == 8
        print("PASS: ping")

        # 10. Shutdown
        resp = send(proc, {"jsonrpc": "2.0", "id": 9, "method": "shutdown", "params": {}})
        assert resp["id"] == 9
        print("PASS: shutdown")

        print("\nAll tests passed!")

    finally:
        proc.terminate()
        stderr_output = proc.stderr.read()
        if stderr_output:
            print(f"\n--- Server stderr ---\n{stderr_output}", file=sys.stderr)


if __name__ == "__main__":
    main()
