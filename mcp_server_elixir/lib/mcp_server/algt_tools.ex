defmodule McpServer.AlgtTools do
  @moduledoc """
  ALGT-specific tool implementations for MCP server.

  Provides Elixir-specific tools demonstrating the language's
  capabilities including Code evaluation, module introspection,
  and process management.
  """

  alias McpServer.Tools

  @doc """
  Register all ALGT tools with the MCP server.
  """
  @spec register_all() :: :ok
  def register_all do
    register_eval_tool()
    register_module_info_tool()
    register_process_list_tool()
    register_system_info_tool()
    register_apply_function_tool()
    :ok
  end

  # ============================================================
  # Tool: elixir_eval
  # Evaluate Elixir expressions
  # ============================================================

  defp register_eval_tool do
    Tools.register(
      "elixir_eval",
      "Evaluate an Elixir expression and return the result. " <>
        "Use for testing expressions, calculations, and exploring the runtime.",
      %{
        "type" => "object",
        "properties" => %{
          "expression" => %{
            "type" => "string",
            "description" =>
              "The Elixir expression to evaluate (e.g., 'Enum.map(1..5, &(&1 * 2))')"
          }
        },
        "required" => ["expression"]
      },
      &handle_eval/1
    )
  end

  defp handle_eval(args) do
    expression = Map.get(args, "expression", "")

    try do
      {result, _bindings} = Code.eval_string(expression)
      Tools.format_result(inspect(result, pretty: true, limit: :infinity))
    rescue
      error ->
        Tools.format_error("Evaluation error: #{inspect(error)}")
    end
  end

  # ============================================================
  # Tool: module_info
  # Get information about loaded modules
  # ============================================================

  defp register_module_info_tool do
    Tools.register(
      "module_info",
      "Get information about a loaded Elixir/Erlang module, including exported functions.",
      %{
        "type" => "object",
        "properties" => %{
          "module" => %{
            "type" => "string",
            "description" => "Module name (e.g., 'Enum', 'String', ':lists')"
          }
        },
        "required" => ["module"]
      },
      &handle_module_info/1
    )
  end

  defp handle_module_info(args) do
    module_name = Map.get(args, "module", "")

    try do
      module = parse_module_name(module_name)

      # Get exports, filtering out special functions
      exports =
        module.__info__(:functions)
        |> Enum.reject(fn {name, _arity} ->
          name |> Atom.to_string() |> String.starts_with?("__")
        end)
        |> Enum.sort()

      exports_str =
        exports
        |> Enum.map(fn {name, arity} -> "  #{name}/#{arity}" end)
        |> Enum.join("\n")

      result = """
      Module: #{inspect(module)}
      Exported functions (#{length(exports)}):
      #{exports_str}
      """

      Tools.format_result(result)
    rescue
      _ ->
        Tools.format_error("Module not found or not loaded: #{module_name}")
    end
  end

  defp parse_module_name(":" <> erlang_module) do
    String.to_existing_atom(erlang_module)
  end

  defp parse_module_name(elixir_module) do
    Module.concat([elixir_module])
  end

  # ============================================================
  # Tool: process_list
  # List running processes
  # ============================================================

  defp register_process_list_tool do
    Tools.register(
      "process_list",
      "List running BEAM processes with their registered names and current function.",
      %{
        "type" => "object",
        "properties" => %{
          "limit" => %{
            "type" => "integer",
            "description" => "Maximum processes to list (default: 20)"
          }
        }
      },
      &handle_process_list/1
    )
  end

  defp handle_process_list(args) do
    limit = Map.get(args, "limit", 20)
    processes = Process.list()
    limited = Enum.take(processes, limit)

    process_infos =
      limited
      |> Enum.map(fn pid ->
        info = Process.info(pid, [:registered_name, :current_function])

        name =
          case Keyword.get(info, :registered_name) do
            [] -> inspect(pid)
            nil -> inspect(pid)
            reg_name -> Atom.to_string(reg_name)
          end

        {m, f, a} = Keyword.get(info, :current_function, {:unknown, :unknown, 0})
        "  #{name}: #{inspect(m)}.#{f}/#{a}"
      end)
      |> Enum.join("\n")

    result = """
    Processes (#{length(limited)} of #{length(processes)}):
    #{process_infos}
    """

    Tools.format_result(result)
  end

  # ============================================================
  # Tool: system_info
  # Get Elixir/Erlang system information
  # ============================================================

  defp register_system_info_tool do
    Tools.register(
      "system_info",
      "Get Elixir/Erlang system information including versions, schedulers, and memory.",
      %{
        "type" => "object",
        "properties" => %{}
      },
      &handle_system_info/1
    )
  end

  defp handle_system_info(_args) do
    info = [
      "Elixir Version: #{System.version()}",
      "OTP Release: #{:erlang.system_info(:otp_release)}",
      "ERTS Version: #{:erlang.system_info(:version)}",
      "Schedulers: #{:erlang.system_info(:schedulers)} (online: #{:erlang.system_info(:schedulers_online)})",
      "Process Count: #{:erlang.system_info(:process_count)}",
      "Process Limit: #{:erlang.system_info(:process_limit)}",
      "Atom Count: #{:erlang.system_info(:atom_count)}",
      "Memory (total): #{:erlang.memory(:total)} bytes",
      "Memory (processes): #{:erlang.memory(:processes)} bytes",
      "Memory (system): #{:erlang.memory(:system)} bytes"
    ]

    Tools.format_result(Enum.join(info, "\n"))
  end

  # ============================================================
  # Tool: apply_function
  # Apply a function from a module with arguments
  # ============================================================

  defp register_apply_function_tool do
    Tools.register(
      "apply_function",
      "Apply a function from a module with given arguments. " <>
        "Arguments should be valid Elixir terms.",
      %{
        "type" => "object",
        "properties" => %{
          "module" => %{
            "type" => "string",
            "description" => "Module name (e.g., 'Enum', 'String', ':lists')"
          },
          "function" => %{
            "type" => "string",
            "description" => "Function name"
          },
          "args" => %{
            "type" => "string",
            "description" => "Arguments as Elixir list (e.g., '[[1, 2, 3]]')"
          }
        },
        "required" => ["module", "function", "args"]
      },
      &handle_apply_function/1
    )
  end

  defp handle_apply_function(args) do
    module_name = Map.get(args, "module")
    function_name = Map.get(args, "function")
    args_str = Map.get(args, "args")

    try do
      module = parse_module_name(module_name)
      function = String.to_existing_atom(function_name)
      {args_list, _} = Code.eval_string(args_str)

      result = apply(module, function, args_list)
      Tools.format_result(inspect(result, pretty: true, limit: :infinity))
    rescue
      error ->
        Tools.format_error("Apply error: #{inspect(error)}")
    end
  end
end
