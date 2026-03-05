#!/bin/bash
#
# Start the ALGT MCP Server (Elixir version)
#
# Usage:
#   ./mcp_server_elixir/start_server.sh
#
# The server communicates via stdio using the MCP protocol.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

# Build if needed
if [ ! -d "_build" ]; then
    echo "Building MCP server..." >&2
    mix deps.get >&2
    mix compile >&2
fi

exec elixir --no-halt -e "McpServer.start()"
