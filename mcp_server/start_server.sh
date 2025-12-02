#!/bin/bash
#
# Start the ALGT MCP Server
#
# Usage:
#   ./mcp_server/start_server.sh
#
# The server communicates via stdio using the MCP protocol.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

exec swipl -g start -t halt "$SCRIPT_DIR/mcp_server.pl"
