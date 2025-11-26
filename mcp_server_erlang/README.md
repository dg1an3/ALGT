# ALGT MCP Server (Erlang)

A Model Context Protocol (MCP) server implementation in Erlang/OTP, provided as a reference implementation alongside the SWI-Prolog version.

## Overview

This Erlang implementation demonstrates how to build an MCP server using OTP patterns:

- **gen_server** for tool registry and state management
- **supervisor** for fault tolerance
- Pattern matching for JSON-RPC message dispatch
- ETS tables for tool storage

## Comparison with Prolog Version

| Feature | SWI-Prolog | Erlang |
|---------|------------|--------|
| Pattern Matching | Native, first-class | Native, first-class |
| Concurrency | Threads | Lightweight processes (BEAM) |
| JSON Library | `library(http/json)` | `jsx` |
| State Management | `assertz/retract` | gen_server + ETS |
| Tool Registry | Dynamic predicates | ETS table |
| Supervision | Manual | OTP supervisor |

## Requirements

- Erlang/OTP 24 or later
- rebar3 (Erlang build tool)

## Building

```bash
cd mcp_server_erlang
rebar3 compile
```

## Usage

### Starting the Server

```bash
# Using the startup script:
./mcp_server_erlang/start_server.sh

# Or manually:
cd mcp_server_erlang
rebar3 compile
erl -pa _build/default/lib/*/ebin -noshell -s mcp_server start
```

### Configuration for Claude Desktop

```json
{
  "mcpServers": {
    "algt-erlang": {
      "command": "/path/to/ALGT/mcp_server_erlang/start_server.sh"
    }
  }
}
```

## Available Tools

### `erlang_eval`

Evaluate Erlang expressions at runtime.

**Parameters:**
- `expression` (string, required): Erlang expression to evaluate

**Example:**
```json
{
  "name": "erlang_eval",
  "arguments": {
    "expression": "lists:seq(1, 10)."
  }
}
```

### `module_info`

Get information about loaded Erlang modules.

**Parameters:**
- `module` (string, required): Module name

**Example:**
```json
{
  "name": "module_info",
  "arguments": {
    "module": "lists"
  }
}
```

### `process_list`

List running Erlang processes.

**Parameters:**
- `limit` (integer, optional): Maximum processes to list (default: 20)

### `system_info`

Get Erlang/OTP system information including version, schedulers, and memory.

### `apply_function`

Apply a function from a module with arguments.

**Parameters:**
- `module` (string, required): Module name
- `function` (string, required): Function name
- `args` (string, required): Arguments as Erlang list

**Example:**
```json
{
  "name": "apply_function",
  "arguments": {
    "module": "lists",
    "function": "reverse",
    "args": "[[1, 2, 3]]"
  }
}
```

## Architecture

```
mcp_server_erlang/
├── src/
│   ├── mcp_server.erl       # Main server and message loop
│   ├── mcp_server_app.erl   # OTP application behaviour
│   ├── mcp_server_sup.erl   # Supervisor
│   ├── mcp_protocol.erl     # JSON-RPC 2.0 protocol
│   ├── mcp_tools.erl        # Tool registry (gen_server)
│   ├── mcp_algt_tools.erl   # Erlang-specific tools
│   └── mcp_server.app.src   # Application resource file
├── rebar.config             # Build configuration
├── start_server.sh          # Startup script
└── README.md
```

## Code Comparison

### Pattern Matching for Message Dispatch

**Prolog:**
```prolog
handle_message(Message, Out, _Options) :-
    get_dict(method, Message, Method),
    (   Method == "initialize"
    ->  handle_initialize(Id, Params, Out)
    ;   Method == "tools/list"
    ->  handle_tools_list(Id, Out)
    ;   ...
    ).
```

**Erlang:**
```erlang
process_message(Message, State) ->
    Method = maps:get(<<"method">>, Message, <<>>),
    case Method of
        <<"initialize">> ->
            handle_initialize(Id, Params, State);
        <<"tools/list">> ->
            handle_tools_list(Id, State);
        ...
    end.
```

### Tool Registration

**Prolog (dynamic predicates):**
```prolog
:- dynamic registered_tool/4.

register_tool(Name, Description, Schema, Handler) :-
    assertz(registered_tool(Name, Description, Schema, Handler)).
```

**Erlang (ETS + gen_server):**
```erlang
register_tool(Name, Description, Schema, Handler) ->
    gen_server:call(?SERVER, {register, Name, Description, Schema, Handler}).

handle_call({register, Name, Desc, Schema, Handler}, _From, State) ->
    ets:insert(?TOOLS_TABLE, {Name, #{...}}),
    {reply, ok, State}.
```

## Extending the Server

### Adding a New Tool

1. Edit `mcp_algt_tools.erl`
2. Create a registration function:

```erlang
register_my_tool() ->
    mcp_tools:register_tool(
        <<"my_tool">>,
        <<"Description">>,
        #{<<"type">> => <<"object">>, ...},
        {?MODULE, handle_my_tool}
    ).
```

3. Implement the handler:

```erlang
handle_my_tool(Args) ->
    %% Process arguments
    Param = maps:get(<<"param">>, Args),
    %% Do work
    Result = do_something(Param),
    %% Return MCP-formatted result
    mcp_tools:format_result(Result).
```

4. Add to `register_all/0`:

```erlang
register_all() ->
    %% ...existing registrations...
    register_my_tool(),
    ok.
```

## Testing

```bash
# Run the Erlang shell with the application loaded
rebar3 shell

# Test tool registration
1> mcp_algt_tools:register_all().
ok

# List registered tools
2> mcp_tools:list_tools().
[#{<<"name">> => <<"erlang_eval">>, ...}, ...]

# Test a tool
3> mcp_tools:call_tool(<<"erlang_eval">>, #{<<"expression">> => <<"1 + 1.">>}).
#{<<"content">> => [#{<<"text">> => <<"2">>, <<"type">> => <<"text">>}]}
```

## License

Copyright (C) 2024 ALGT Project
