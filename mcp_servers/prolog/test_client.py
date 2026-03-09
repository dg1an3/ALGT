#!/usr/bin/env python3
"""
Simple test client for the ALGT MCP Server.

Usage:
    python3 test_client.py

This script starts the MCP server and sends test requests to verify it works.
"""

import json
import subprocess
import sys
import os

def send_message(proc, message):
    """Send a JSON-RPC message to the server."""
    json_str = json.dumps(message)
    content = f"Content-Length: {len(json_str)}\r\n\r\n{json_str}"
    proc.stdin.write(content)
    proc.stdin.flush()

def read_message(proc):
    """Read a JSON-RPC message from the server."""
    # Read headers
    headers = {}
    while True:
        line = proc.stdout.readline()
        if line in ('', '\r\n', '\n'):
            break
        if ':' in line:
            key, value = line.split(':', 1)
            headers[key.strip().lower()] = value.strip()

    # Read body
    content_length = int(headers.get('content-length', 0))
    if content_length > 0:
        body = proc.stdout.read(content_length)
        return json.loads(body)
    return None

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    server_script = os.path.join(script_dir, 'mcp_server.pl')

    print("Starting ALGT MCP Server...")
    proc = subprocess.Popen(
        ['swipl', '-g', 'start', '-t', 'halt', server_script],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )

    try:
        # Test 1: Initialize
        print("\n=== Test 1: Initialize ===")
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        })
        response = read_message(proc)
        print(f"Response: {json.dumps(response, indent=2)}")

        # Send initialized notification
        send_message(proc, {
            "jsonrpc": "2.0",
            "method": "initialized"
        })

        # Test 2: List tools
        print("\n=== Test 2: List Tools ===")
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        })
        response = read_message(proc)
        print(f"Response: {json.dumps(response, indent=2)}")

        # Test 3: Call prolog_query tool
        print("\n=== Test 3: Prolog Query ===")
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "prolog_query",
                "arguments": {
                    "query": "member(X, [1, 2, 3])"
                }
            }
        })
        response = read_message(proc)
        print(f"Response: {json.dumps(response, indent=2)}")

        # Test 4: Ping
        print("\n=== Test 4: Ping ===")
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "ping",
            "params": {}
        })
        response = read_message(proc)
        print(f"Response: {json.dumps(response, indent=2)}")

        # Test 5: Shutdown
        print("\n=== Test 5: Shutdown ===")
        send_message(proc, {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "shutdown",
            "params": {}
        })
        response = read_message(proc)
        print(f"Response: {json.dumps(response, indent=2)}")

        print("\n=== All tests completed ===")

    except Exception as e:
        print(f"Error: {e}")
        # Print stderr for debugging
        stderr = proc.stderr.read()
        if stderr:
            print(f"Server stderr:\n{stderr}")
    finally:
        proc.terminate()
        proc.wait()

if __name__ == '__main__':
    main()
