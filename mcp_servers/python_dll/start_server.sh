#!/bin/bash
# Start the Clarion DLL MCP server.
# Requires 32-bit Python (Clarion 11 produces 32-bit DLLs).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON32="${PYTHON32:-$HOME/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe}"

exec "$PYTHON32" "$SCRIPT_DIR/server.py" "$@"
