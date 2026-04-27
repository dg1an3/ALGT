defmodule ClarionSim.ErlogEngine do
  @moduledoc """
  Erlog engine wrapper — consults all Prolog files (parser, bridge,
  state, eval, builtins, classes, simulator) and provides a unified
  interface for parsing, bridging, and executing Clarion programs.

  The entire execution engine runs in Erlog/Prolog. Variables can
  be open (unbound), and Prolog backtracking enables backward execution.

  ## Architecture

      .clw source → [Erlog: DCG Parser] → Simple AST
                  → [Erlog: AST Bridge] → Modular AST
                  → [Erlog: Simulator]  → Final State (Prolog term)
                  → [Elixir: normalize] → Elixir-friendly result

  All state lives in Prolog during execution. Elixir is the host
  that consults files, proves goals, and converts results.
  """

  @prolog_files [
    "clarion_state.pl",
    "clarion_eval.pl",
    "clarion_classes.pl",
    "clarion_builtins.pl",
    "clarion_bridge.pl",
    "clarion_simulator.pl",
    "clarion_parser.pl"
  ]

  @doc """
  Create a new Erlog engine with all simulator modules loaded.
  """
  def new() do
    case :erlog.new() do
      {:ok, erlog} ->
        consult_all(erlog, @prolog_files)

      error ->
        {:error, {:erlog_init, error}}
    end
  end

  @doc """
  Parse Clarion source code, returning the simple AST.
  """
  def parse(erlog, source) do
    codes = String.to_charlist(source)

    case :erlog.prove({:parse_clarion_codes, codes, {:result}}, erlog) do
      {{:succeed, bindings}, erlog2} ->
        ast = get_binding(:result, bindings)
        {:ok, normalize_term(ast), erlog2}

      {:fail, erlog2} ->
        {:error, :parse_failed, erlog2}
    end
  end

  @doc """
  Bridge a simple AST to the modular format.
  """
  def bridge(erlog, simple_ast) do
    erlog_ast = elixir_to_erlog(simple_ast)

    case :erlog.prove({:bridge_ast, erlog_ast, {:result}}, erlog) do
      {{:succeed, bindings}, erlog2} ->
        ast = get_binding(:result, bindings)
        {:ok, normalize_term(ast), erlog2}

      {:fail, erlog2} ->
        {:error, :bridge_failed, erlog2}
    end
  end

  @doc """
  Parse and bridge in one step.
  """
  def parse_and_bridge(erlog, source) do
    case parse(erlog, source) do
      {:ok, simple_ast, erlog2} ->
        bridge(erlog2, simple_ast)

      error ->
        error
    end
  end

  @doc """
  Run an AST to completion, returning the final state as an Elixir term.
  """
  def run_ast(erlog, modular_ast) do
    erlog_ast = elixir_to_erlog(modular_ast)

    case :erlog.prove({:run_ast, erlog_ast, {:final_state}}, erlog) do
      {{:succeed, bindings}, erlog2} ->
        state = get_binding(:final_state, bindings)
        {:ok, normalize_term(state), erlog2}

      {:fail, erlog2} ->
        {:error, :execution_failed, erlog2}
    end
  end

  @doc """
  Initialize a session for multi-call DLL simulation.
  """
  def init_session(erlog, modular_ast) do
    erlog_ast = elixir_to_erlog(modular_ast)

    case :erlog.prove({:init_session, erlog_ast, {:session}}, erlog) do
      {{:succeed, bindings}, erlog2} ->
        session = get_binding(:session, bindings)
        {:ok, session, erlog2}

      {:fail, erlog2} ->
        {:error, :init_failed, erlog2}
    end
  end

  @doc """
  Call a procedure on an existing session.
  The session state is a raw Erlog term (not normalized) for efficiency.
  """
  def call_procedure(erlog, session, proc_name, args) do
    erlog_args = Enum.map(args, &elixir_to_erlog/1)

    case :erlog.prove(
           {:call_procedure, session, proc_name, erlog_args, {:result}, {:new_session}},
           erlog
         ) do
      {{:succeed, bindings}, erlog2} ->
        result = get_binding(:result, bindings)
        new_session = get_binding(:new_session, bindings)
        {:ok, normalize_term(result), new_session, erlog2}

      {:fail, erlog2} ->
        {:error, :call_failed, erlog2}
    end
  end

  @doc """
  Execute a PROGRAM with event simulation.
  """
  def exec_program(erlog, modular_ast, events) do
    erlog_ast = elixir_to_erlog(modular_ast)
    erlog_events = elixir_to_erlog(events)

    case :erlog.prove(
           {:exec_program, erlog_ast, erlog_events, {:result}, {:final_state}},
           erlog
         ) do
      {{:succeed, bindings}, erlog2} ->
        result = get_binding(:result, bindings)
        state = get_binding(:final_state, bindings)
        {:ok, normalize_term(result), normalize_term(state), erlog2}

      {:fail, erlog2} ->
        {:error, :program_failed, erlog2}
    end
  end

  @doc """
  Prove an arbitrary Prolog goal — for backward execution queries.

  Example:
      # "What makes Result = 152 after running this body?"
      goal = {:exec_statements, body, init_state, {:final}, {:control}}
      ErlogEngine.query(erlog, goal)
  """
  def query(erlog, goal) do
    erlog_goal = elixir_to_erlog(goal)

    case :erlog.prove(erlog_goal, erlog) do
      {{:succeed, bindings}, erlog2} ->
        normalized = Enum.map(bindings, fn {k, v} -> {k, normalize_term(v)} end)
        {:ok, normalized, erlog2}

      {:fail, erlog2} ->
        {:fail, erlog2}
    end
  end

  @doc """
  Extract a variable value from a raw Prolog state term.
  """
  def get_state_var(erlog, state, var_name) do
    case :erlog.prove({:get_var, var_name, state, {:value}}, erlog) do
      {{:succeed, bindings}, _erlog2} ->
        value = get_binding(:value, bindings)
        {:ok, normalize_term(value)}

      {:fail, _} ->
        :error
    end
  end

  @doc """
  Get the output list from a raw Prolog state term.
  """
  def get_state_output(erlog, state) do
    case :erlog.prove({:get_output_list, state, {:output}}, erlog) do
      {{:succeed, bindings}, _erlog2} ->
        output = get_binding(:output, bindings)
        {:ok, normalize_term(output)}

      {:fail, _} ->
        {:ok, []}
    end
  end

  # ── Private ──

  defp consult_all(erlog, []) do
    {:ok, erlog}
  end

  defp consult_all(erlog, [file | rest]) do
    path = prolog_path(file)

    case :erlog.consult(path, erlog) do
      {:ok, erlog2} ->
        consult_all(erlog2, rest)

      {:error, reason} ->
        {:error, {:consult_failed, file, reason}}
    end
  end

  defp prolog_path(filename) do
    Path.join(:code.priv_dir(:erlog_sim), "prolog/#{filename}")
    |> to_charlist()
  end

  defp get_binding(name, bindings) do
    case List.keyfind(bindings, name, 0) do
      {^name, value} -> value
      nil -> nil
    end
  end

  @doc false
  def normalize_term(term) do
    case term do
      # Atoms pass through
      t when is_atom(t) -> t

      # Numbers pass through
      t when is_number(t) -> t

      # Erlang strings (charlists) → Elixir strings
      t when is_list(t) ->
        if charlist?(t) do
          List.to_string(t)
        else
          Enum.map(t, &normalize_term/1)
        end

      # Erlog uses 2-tuples for pairs: {a, b} but also for compound terms
      # Erlog compound terms are typically tuples
      t when is_tuple(t) ->
        list = Tuple.to_list(t)
        normalized = Enum.map(list, &normalize_term/1)
        List.to_tuple(normalized)

      other ->
        other
    end
  end

  defp charlist?(list) do
    Enum.all?(list, fn
      c when is_integer(c) and c >= 0 and c < 128 -> true
      _ -> false
    end)
  rescue
    _ -> false
  end

  @doc false
  def elixir_to_erlog(term) do
    case term do
      t when is_atom(t) -> t
      t when is_number(t) -> t
      t when is_binary(t) -> String.to_charlist(t)

      t when is_list(t) ->
        Enum.map(t, &elixir_to_erlog/1)

      t when is_tuple(t) ->
        list = Tuple.to_list(t)
        converted = Enum.map(list, &elixir_to_erlog/1)
        List.to_tuple(converted)

      other ->
        other
    end
  end
end
