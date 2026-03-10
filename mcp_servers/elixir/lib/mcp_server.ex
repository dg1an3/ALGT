defmodule McpServer do
  @moduledoc """
  Main MCP (Model Context Protocol) server implementation for Elixir.

  Communicates via stdio using JSON-RPC 2.0.

  ## Usage

      # Start from command line:
      mix run --no-halt -e "McpServer.start()"

      # Or use the escript:
      ./mcp_server
  """

  use GenServer

  alias McpServer.Protocol
  alias McpServer.Tools
  alias McpServer.AlgtTools

  @protocol_version "2024-11-05"
  @server_name "algt-mcp-server-elixir"
  @server_version "0.1.0"

  defstruct initialized: false

  # Public API

  @doc """
  Start the MCP server (entry point for command line).
  """
  def start do
    # Start the tools registry
    {:ok, _} = Tools.start_link()

    # Register ALGT tools
    AlgtTools.register_all()

    # Start the server
    {:ok, pid} = start_link()

    log_info("ALGT MCP Server (Elixir) starting...")

    # Enter the message loop
    message_loop(pid)
  end

  @doc """
  Start the server as a GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:handle_message, message}, _from, state) do
    {response, new_state} = process_message(message, state)
    {:reply, response, new_state}
  end

  # Message Loop

  defp message_loop(pid) do
    case Protocol.read_message() do
      :eof ->
        log_info("End of input, shutting down")
        :ok

      {:error, reason} ->
        log_error("Read error: #{inspect(reason)}")
        :ok

      {:ok, message} ->
        case GenServer.call(pid, {:handle_message, message}) do
          {:response, response} ->
            Protocol.write_response(response)

          :no_response ->
            :ok

          :shutdown ->
            :ok
        end

        message_loop(pid)
    end
  end

  # Message Processing

  defp process_message(message, state) do
    id = Map.get(message, "id")
    method = Map.get(message, "method", "")
    params = Map.get(message, "params", %{})

    log_info("Received: #{method} (id=#{inspect(id)})")

    case method do
      "initialize" ->
        handle_initialize(id, params, state)

      "initialized" ->
        handle_initialized(state)

      "shutdown" ->
        handle_shutdown(id, state)

      "tools/list" ->
        handle_tools_list(id, state)

      "tools/call" ->
        handle_tools_call(id, params, state)

      "ping" ->
        handle_ping(id, state)

      _ when not is_nil(id) ->
        # Unknown method with id -> error response
        response =
          Protocol.error_response(
            id,
            Protocol.method_not_found(),
            "Unknown method: #{method}"
          )

        {{:response, response}, state}

      _ ->
        # Unknown notification -> ignore
        log_info("Ignoring unknown notification: #{method}")
        {:no_response, state}
    end
  end

  # Handler Functions

  defp handle_initialize(id, params, state) do
    # Log client info if present
    case Map.get(params, "clientInfo") do
      nil -> :ok
      client_info -> log_info("Client: #{inspect(client_info)}")
    end

    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{
        "protocolVersion" => @protocol_version,
        "capabilities" => %{
          "tools" => %{
            "listChanged" => false
          }
        },
        "serverInfo" => %{
          "name" => @server_name,
          "version" => @server_version
        }
      }
    }

    {{:response, response}, %{state | initialized: true}}
  end

  defp handle_initialized(state) do
    log_info("Client initialized successfully")
    {:no_response, state}
  end

  defp handle_shutdown(id, state) do
    log_info("Shutdown requested")

    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => nil
    }

    {{:response, response}, state}
  end

  defp handle_ping(id, state) do
    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{}
    }

    {{:response, response}, state}
  end

  defp handle_tools_list(id, state) do
    tools = Tools.list()

    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => %{
        "tools" => tools
      }
    }

    {{:response, response}, state}
  end

  defp handle_tools_call(id, params, state) do
    response =
      case {Map.get(params, "name"), Map.get(params, "arguments")} do
        {nil, _} ->
          Protocol.error_response(
            id,
            Protocol.invalid_params(),
            "Missing required parameter: name"
          )

        {_, nil} ->
          Protocol.error_response(
            id,
            Protocol.invalid_params(),
            "Missing required parameter: arguments"
          )

        {tool_name, arguments} ->
          log_info("Calling tool: #{tool_name}")
          tool_result = Tools.call(tool_name, arguments)

          %{
            "jsonrpc" => "2.0",
            "id" => id,
            "result" => tool_result
          }
      end

    {{:response, response}, state}
  end

  # Logging

  defp log_info(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    IO.write(:stderr, "[#{timestamp}] INFO: #{message}\n")
  end

  defp log_error(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    IO.write(:stderr, "[#{timestamp}] ERROR: #{message}\n")
  end
end
