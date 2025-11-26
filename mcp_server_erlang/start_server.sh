#!/bin/bash
#
# Start the ALGT MCP Server (Erlang version)
#
# Usage:
#   ./mcp_server_erlang/start_server.sh
#
# The server communicates via stdio using the MCP protocol.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

# Build if needed
if [ ! -d "_build" ]; then
    echo "Building MCP server..." >&2
    rebar3 compile >&2
fi

exec erl -pa _build/default/lib/*/ebin \
    -noshell \
    -s mcp_server start
