---
title: MCP servers
layout: default
parent: Components
nav_order: 6
---

# MCP servers

Model Context Protocol server implementations that expose ALGT's capabilities as
tools for AI-assistant integration (e.g. Claude Code).

**Location:** [`mcp_servers/`](https://github.com/DLaneAtElekta/ALGT/tree/main/mcp_servers)

| Server | Language | Role |
|---|---|---|
| `prolog/` | SWI-Prolog | Prolog MCP server |
| `erlang/` | Erlang | Erlang MCP server |
| `elixir/` | Elixir | Elixir MCP server — the **MUZAQ host** skeleton |
| `python_dll/` | Python | Wraps a Clarion DLL, exposing its exports as MCP tools |

---

## Python DLL MCP server

A Python MCP server that wraps a Clarion DLL and exposes its exported functions
as MCP tools, using `ctypes` for interop and PE parsing for export discovery. No
external dependencies beyond the Python standard library.

**Location:** [`mcp_servers/python_dll/`](https://github.com/DLaneAtElekta/ALGT/tree/main/mcp_servers/python_dll)

**Key files**

- `server.py` — JSON-RPC 2.0 over stdio (newline-delimited JSON)
- `dll_wrapper.py` — generic Clarion DLL wrapper with PE export parsing
- `test_client.py` — end-to-end test client
- `start_server.sh` — launch script (uses 32-bit Python)

**Tools exposed**

- `list_exports` — list all exported functions from the DLL
- `call_function` — call an exported function by name with integer arguments
- `get_dll_info` — metadata about the loaded DLL

**Configuration:** `.mcp.json` in the project root configures the server for
Claude Code. Requires 32-bit Python (`3.11.9-win32`) since Clarion 11 produces
32-bit DLLs. The default DLL is `MathLib.dll`; pass a different DLL path as
`argv[1]` to wrap any Clarion DLL.

**Run the tests**

```bash
cd mcp_servers/python_dll
~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe test_client.py
```

---

## Elixir MCP server (MUZAQ host)

The Elixir server is the skeleton host for **Stage 2** of the MUZAQ
modernization, where each Lazarus form becomes a GenServer and the SQL
transaction log becomes a PubSub pipeline. See
[Architecture → Stage 2]({{ site.baseurl }}/architecture.html#stage-2--prolog-lts-to-elixir-actors).

## Related

- [Clarion projects]({{ site.baseurl }}/components/clarion-projects.html) — the DLLs the Python server wraps.
