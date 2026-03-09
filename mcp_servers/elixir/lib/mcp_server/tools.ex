defmodule McpServer.Tools do
  @moduledoc """
  Tool registry and execution for MCP server.

  Uses a GenServer with an ETS table for storing tool definitions.
  Provides a clean API for registering and calling tools.
  """

  use GenServer

  @table_name :mcp_tools_registry

  # Client API

  @doc """
  Start the tool registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a tool with the MCP server.

  ## Parameters
    - name: Tool name (string)
    - description: Tool description (string)
    - input_schema: JSON Schema for input validation (map)
    - handler: Function to handle tool calls (fn args -> result)

  ## Example

      McpServer.Tools.register(
        "my_tool",
        "Does something useful",
        %{"type" => "object", "properties" => %{}},
        fn args -> {:ok, "result"} end
      )
  """
  @spec register(String.t(), String.t(), map(), function()) :: :ok
  def register(name, description, input_schema, handler) do
    GenServer.call(__MODULE__, {:register, name, description, input_schema, handler})
  end

  @doc """
  List all registered tools in MCP format.
  """
  @spec list() :: [map()]
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Call a registered tool with arguments.
  """
  @spec call(String.t(), map()) :: map()
  def call(name, arguments) do
    GenServer.call(__MODULE__, {:call, name, arguments}, :infinity)
  end

  @doc """
  Format a successful result in MCP format.
  """
  @spec format_result(String.t() | any()) :: map()
  def format_result(text) when is_binary(text) do
    %{
      "content" => [
        %{
          "type" => "text",
          "text" => text
        }
      ]
    }
  end

  def format_result(value) do
    format_result(inspect(value, pretty: true))
  end

  @doc """
  Format an error result in MCP format.
  """
  @spec format_error(term()) :: map()
  def format_error(error) do
    %{
      "isError" => true,
      "content" => [
        %{
          "type" => "text",
          "text" => inspect(error)
        }
      ]
    }
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for tool storage
    :ets.new(@table_name, [:named_table, :set, :protected])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, name, description, input_schema, handler}, _from, state) do
    tool = %{
      name: name,
      description: description,
      input_schema: input_schema,
      handler: handler
    }

    :ets.insert(@table_name, {name, tool})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    tools =
      :ets.foldl(
        fn {_name, tool}, acc ->
          tool_def = %{
            "name" => tool.name,
            "description" => tool.description,
            "inputSchema" => tool.input_schema
          }

          [tool_def | acc]
        end,
        [],
        @table_name
      )

    {:reply, tools, state}
  end

  @impl true
  def handle_call({:call, name, arguments}, _from, state) do
    result =
      case :ets.lookup(@table_name, name) do
        [{_, tool}] ->
          try do
            tool.handler.(arguments)
          rescue
            error ->
              log_error("Tool #{name} error: #{inspect(error)}")
              format_error(error)
          catch
            kind, error ->
              log_error("Tool #{name} error: #{kind} - #{inspect(error)}")
              format_error({kind, error})
          end

        [] ->
          format_error("Tool not found: #{name}")
      end

    {:reply, result, state}
  end

  defp log_error(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    IO.write(:stderr, "[#{timestamp}] ERROR: #{message}\n")
  end
end
