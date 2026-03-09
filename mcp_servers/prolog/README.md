# ALGT MCP Server

A Model Context Protocol (MCP) server implementation in SWI-Prolog that exposes ALGT verification tools to AI assistants.

## Overview

This MCP server allows AI assistants (like Claude) to interact with the ALGT (Algorithm Logic Verification Tool) system through a standardized protocol. It provides tools for:

- Executing Prolog queries
- Loading Prolog files
- Validating concurrent operation models
- Analyzing execution pathways for race conditions

## Requirements

- SWI-Prolog 8.0 or later
- The `http/json` library (included with SWI-Prolog)

## Installation

No installation required. The server runs directly from the source files.

## Usage

### Starting the Server

```bash
# From the ALGT project root:
./mcp_server/start_server.sh

# Or directly with SWI-Prolog:
swipl -g start -t halt mcp_server/mcp_server.pl
```

### Configuration for Claude Desktop

Add to your Claude Desktop configuration (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "algt": {
      "command": "/path/to/ALGT/mcp_server/start_server.sh"
    }
  }
}
```

Or with explicit SWI-Prolog path:

```json
{
  "mcpServers": {
    "algt": {
      "command": "swipl",
      "args": ["-g", "start", "-t", "halt", "/path/to/ALGT/mcp_server/mcp_server.pl"]
    }
  }
}
```

## Available Tools

### `prolog_query`

Execute arbitrary Prolog queries and return solutions.

**Parameters:**
- `query` (string, required): The Prolog query to execute
- `max_solutions` (integer, optional): Maximum solutions to return (default: 10)

**Example:**
```json
{
  "name": "prolog_query",
  "arguments": {
    "query": "member(X, [1, 2, 3])",
    "max_solutions": 5
  }
}
```

### `consult_file`

Load a Prolog file into the current session.

**Parameters:**
- `file_path` (string, required): Path to the Prolog file

**Example:**
```json
{
  "name": "consult_file",
  "arguments": {
    "file_path": "model_checker/model_checker.pl"
  }
}
```

### `list_predicates`

List all predicates defined in a module.

**Parameters:**
- `module` (string, optional): Module name (default: "user")

**Example:**
```json
{
  "name": "list_predicates",
  "arguments": {
    "module": "model_checker"
  }
}
```

### `model_checker_validate`

Validate a concurrent operation model structure.

**Parameters:**
- `model` (string, required): The model as a Prolog term

**Example:**
```json
{
  "name": "model_checker_validate",
  "arguments": {
    "model": "fork([sequence(['A' -> X, X * 2 -> 'A']), sequence([])])"
  }
}
```

### `analyze_pathways`

Analyze all possible execution pathways of a concurrent model.

**Parameters:**
- `model` (string, required): The concurrent model as a Prolog term
- `initial_state` (string, required): Initial state as a Prolog dict

**Example:**
```json
{
  "name": "analyze_pathways",
  "arguments": {
    "model": "fork([sequence([startHours -> S, S + 4 -> startHours]), sequence([endHours -> E, startHours -> S2, E + S2 -> endHours])])",
    "initial_state": "dict{startHours: 5, endHours: -6}"
  }
}
```

## Protocol Details

The server implements [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) version 2024-11-05 over stdio transport.

### Message Format

Messages use HTTP-style headers with JSON-RPC 2.0 body:

```
Content-Length: <length>\r\n
\r\n
<json-rpc-message>
```

### Supported Methods

| Method | Description |
|--------|-------------|
| `initialize` | Handshake and capability negotiation |
| `initialized` | Client confirms initialization |
| `tools/list` | List available tools |
| `tools/call` | Execute a tool |
| `ping` | Health check |
| `shutdown` | Request server shutdown |

## Architecture

```
mcp_server/
├── mcp_server.pl       # Main entry point and message loop
├── mcp_protocol.pl     # JSON-RPC 2.0 protocol handling
├── mcp_tools.pl        # Tool registry and base definitions
├── mcp_algt_tools.pl   # ALGT-specific tool implementations
├── start_server.sh     # Startup script
└── README.md           # This file
```

## Extending the Server

### Adding a New Tool

1. Edit `mcp_algt_tools.pl`
2. Create a registration predicate:

```prolog
register_my_tool :-
    register_tool(
        "my_tool_name",
        "Description of what the tool does",
        _{
            type: "object",
            properties: _{
                param1: _{type: "string", description: "..."}
            },
            required: ["param1"]
        },
        mcp_algt_tools:handle_my_tool
    ).
```

3. Implement the handler:

```prolog
handle_my_tool(Args, Result) :-
    get_dict(param1, Args, Param1),
    % ... do something ...
    Result = _{
        content: [_{
            type: "text",
            text: "Result text"
        }]
    }.
```

4. Add to `register_algt_tools/0`:

```prolog
register_algt_tools :-
    % ... existing registrations ...
    register_my_tool.
```

## Debugging

The server logs to stderr, which doesn't interfere with the stdio protocol:

```bash
./mcp_server/start_server.sh 2>server.log
```

## License

Copyright (C) 2024 ALGT Project
