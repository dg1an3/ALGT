# ALGT MCP Server (Elixir)

A Model Context Protocol (MCP) server implementation in Elixir, provided as a reference alongside the SWI-Prolog and Erlang versions.

## Overview

This Elixir implementation showcases the language's strengths:

- **Clean, expressive syntax** with Ruby-like aesthetics
- **Pipe operator** (`|>`) for data transformation chains
- **Pattern matching** in function heads and case statements
- **OTP behaviours** with modern Elixir abstractions
- **First-class documentation** with `@moduledoc` and `@doc`

## Three-Way Comparison

| Feature | SWI-Prolog | Erlang | Elixir |
|---------|------------|--------|--------|
| **Syntax** | Logic-based | Functional, verbose | Functional, expressive |
| **Pattern Matching** | Unification | In function heads | In function heads + `with` |
| **State** | `assertz/retract` | gen_server + ETS | GenServer + ETS |
| **Pipelines** | N/A | Manual | `\|>` operator |
| **Metaprogramming** | Built-in | Parse transforms | Macros |
| **Documentation** | Comments | EDoc | ExDoc (first-class) |
| **Package Manager** | pack | rebar3/hex | mix/hex |
| **Concurrency** | Threads | BEAM processes | BEAM processes |

## Requirements

- Elixir 1.14 or later
- Erlang/OTP 24 or later

## Building

```bash
cd mcp_server_elixir
mix deps.get
mix compile

# Optional: build escript
mix escript.build
```

## Usage

### Starting the Server

```bash
# Using the startup script:
./mcp_server_elixir/start_server.sh

# Or with mix:
cd mcp_server_elixir
mix run --no-halt -e "McpServer.start()"

# Or with escript:
./mcp_server
```

### Configuration for Claude Desktop

```json
{
  "mcpServers": {
    "algt-elixir": {
      "command": "/path/to/ALGT/mcp_server_elixir/start_server.sh"
    }
  }
}
```

## Available Tools

### `elixir_eval`

Evaluate Elixir expressions at runtime.

**Example:**
```json
{
  "name": "elixir_eval",
  "arguments": {
    "expression": "Enum.map(1..5, &(&1 * 2))"
  }
}
```

### `module_info`

Get information about loaded modules.

**Example:**
```json
{
  "name": "module_info",
  "arguments": {
    "module": "Enum"
  }
}
```

### `process_list`

List running BEAM processes.

### `system_info`

Get Elixir/OTP system information.

### `apply_function`

Apply a function from a module.

**Example:**
```json
{
  "name": "apply_function",
  "arguments": {
    "module": "Enum",
    "function": "reverse",
    "args": "[[1, 2, 3, 4, 5]]"
  }
}
```

## Architecture

```
mcp_server_elixir/
├── lib/
│   ├── mcp_server.ex              # Main server (GenServer + message loop)
│   └── mcp_server/
│       ├── application.ex         # OTP Application
│       ├── protocol.ex            # JSON-RPC 2.0 protocol
│       ├── tools.ex               # Tool registry (GenServer)
│       ├── algt_tools.ex          # Elixir-specific tools
│       └── cli.ex                 # Escript entry point
├── mix.exs                        # Project configuration
├── start_server.sh                # Startup script
└── README.md
```

## Code Comparison

### Tool Registration

**Prolog:**
```prolog
register_tool(Name, Desc, Schema, Handler) :-
    assertz(registered_tool(Name, Desc, Schema, Handler)).
```

**Erlang:**
```erlang
register_tool(Name, Desc, Schema, Handler) ->
    gen_server:call(?SERVER, {register, Name, Desc, Schema, Handler}).
```

**Elixir:**
```elixir
def register(name, description, schema, handler) do
  GenServer.call(__MODULE__, {:register, name, description, schema, handler})
end
```

### Message Dispatch

**Prolog:**
```prolog
handle_message(Message, Out, _Options) :-
    get_dict(method, Message, Method),
    (   Method == "initialize" -> handle_initialize(Id, Params, Out)
    ;   Method == "tools/list" -> handle_tools_list(Id, Out)
    ;   ...
    ).
```

**Erlang:**
```erlang
process_message(Message, State) ->
    Method = maps:get(<<"method">>, Message, <<>>),
    case Method of
        <<"initialize">> -> handle_initialize(Id, Params, State);
        <<"tools/list">> -> handle_tools_list(Id, State);
        ...
    end.
```

**Elixir:**
```elixir
defp process_message(message, state) do
  method = Map.get(message, "method", "")

  case method do
    "initialize" -> handle_initialize(id, params, state)
    "tools/list" -> handle_tools_list(id, state)
    ...
  end
end
```

### Data Transformation

**Prolog:**
```prolog
format_predicates(Module, Predicates, ResultText) :-
    maplist(format_predicate, Predicates, PredStrs),
    atomics_to_string([Header | PredStrs], "\n", ResultText).
```

**Erlang:**
```erlang
format_predicates(Module, Predicates) ->
    PredStrs = lists:map(fun format_predicate/1, Predicates),
    iolist_to_binary(lists:join("\n", [Header | PredStrs])).
```

**Elixir (with pipe operator):**
```elixir
defp format_predicates(module, predicates) do
  predicates
  |> Enum.map(&format_predicate/1)
  |> Enum.join("\n")
  |> then(&"#{header}\n#{&1}")
end
```

### Error Handling

**Prolog:**
```prolog
handle_eval(Args, Result) :-
    catch(
        (   term_string(Query, QueryStr),
            findall(Query, Query, Solutions),
            format_solutions(Solutions, ResultText),
            Result = ...
        ),
        Error,
        Result = error_result(Error)
    ).
```

**Erlang:**
```erlang
handle_eval(Args) ->
    try
        {ok, Tokens, _} = erl_scan:string(ExprStr),
        {ok, Parsed} = erl_parse:parse_exprs(Tokens),
        {value, Result, _} = erl_eval:exprs(Parsed, []),
        format_result(Result)
    catch
        Class:Error -> format_error({Class, Error})
    end.
```

**Elixir:**
```elixir
defp handle_eval(args) do
  expression = Map.get(args, "expression", "")

  try do
    {result, _bindings} = Code.eval_string(expression)
    Tools.format_result(inspect(result, pretty: true))
  rescue
    error -> Tools.format_error("Evaluation error: #{inspect(error)}")
  end
end
```

## Elixir-Specific Features

### Pipe Operator

The `|>` operator enables clear data transformation chains:

```elixir
args
|> Map.get("module")
|> parse_module_name()
|> get_exports()
|> Enum.reject(&internal_function?/1)
|> Enum.sort()
|> format_exports()
```

### Pattern Matching in Function Heads

```elixir
# Match on specific argument patterns
def format_result(text) when is_binary(text), do: ...
def format_result(value), do: format_result(inspect(value))

# Match in case statements
case {Map.get(params, "name"), Map.get(params, "arguments")} do
  {nil, _} -> error_response("Missing name")
  {_, nil} -> error_response("Missing arguments")
  {name, args} -> call_tool(name, args)
end
```

### With Statement

```elixir
with {:ok, module} <- parse_module(module_name),
     {:ok, exports} <- get_exports(module),
     {:ok, formatted} <- format_exports(exports) do
  Tools.format_result(formatted)
else
  {:error, reason} -> Tools.format_error(reason)
end
```

## Testing

```bash
# Run tests
mix test

# Interactive shell
iex -S mix

# Test in IEx
iex> McpServer.AlgtTools.register_all()
:ok
iex> McpServer.Tools.list()
[%{"name" => "elixir_eval", ...}, ...]
iex> McpServer.Tools.call("elixir_eval", %{"expression" => "1 + 1"})
%{"content" => [%{"text" => "2", "type" => "text"}]}
```

## Adding Tests

Create `test/mcp_server_test.exs`:

```elixir
defmodule McpServerTest do
  use ExUnit.Case

  setup do
    {:ok, _} = McpServer.Tools.start_link()
    McpServer.AlgtTools.register_all()
    :ok
  end

  test "lists registered tools" do
    tools = McpServer.Tools.list()
    assert length(tools) >= 5
  end

  test "evaluates expressions" do
    result = McpServer.Tools.call("elixir_eval", %{"expression" => "1 + 1"})
    assert result["content"]
    refute result["isError"]
  end
end
```

## License

Copyright (C) 2024 ALGT Project
