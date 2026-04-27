defmodule ClarionSim do
  @moduledoc """
  Clarion Simulator — Erlog/Elixir implementation.

  The entire execution engine runs in Erlog (embedded Prolog).
  Variables can be open (unbound Prolog variables), and Prolog
  backtracking enables backward execution / constraint propagation.

  ## Architecture

      .clw source → [Erlog: DCG Parser]  → Simple AST
                  → [Erlog: AST Bridge]  → Modular AST
                  → [Erlog: Simulator]   → Final State
                                              ↓
                                   Elixir normalizes results

  Storage/UI backends are implemented directly in Prolog
  (in-memory lists) so the full state is available for
  backward reasoning. Elixir protocols (Storage.Backend,
  UI.Backend) remain available for session-level persistence.

  ## Usage

      # One-shot procedure execution
      {:ok, result} = ClarionSim.exec_procedure(source, :MathAdd, [10, 20])

      # Stateful session (DLL simulation)
      {:ok, session} = ClarionSim.init_session(source)
      {:ok, result, session} = ClarionSim.call_procedure(session, :SSOpen, [])

      # Full program execution with event injection
      {:ok, result} = ClarionSim.exec_program(source, [set: {:SensorID, 1}, 1])

      # Backward execution query
      {:ok, bindings} = ClarionSim.query(source, goal)
  """

  alias ClarionSim.ErlogEngine

  @doc """
  Parse Clarion source code and return the modular AST.
  """
  def parse(source) do
    with {:ok, erlog} <- ErlogEngine.new(),
         {:ok, simple_ast, erlog2} <- ErlogEngine.parse(erlog, source),
         {:ok, modular_ast, _erlog3} <- ErlogEngine.bridge(erlog2, simple_ast) do
      {:ok, modular_ast}
    end
  end

  @doc """
  Run source code and return the final state (as Elixir term).
  """
  def run_source(source) do
    with {:ok, erlog} <- ErlogEngine.new(),
         {:ok, _simple_ast, erlog2} <- ErlogEngine.parse(erlog, source),
         {:ok, modular_ast, erlog3} <- ErlogEngine.bridge(erlog2, _simple_ast),
         {:ok, final_state, _erlog4} <- ErlogEngine.run_ast(erlog3, modular_ast) do
      {:ok, final_state}
    end
  end

  @doc """
  Execute a named procedure (stateless, one-shot).
  """
  def exec_procedure(source, proc_name, args) do
    with {:ok, session} <- init_session(source) do
      call_procedure(session, proc_name, args)
    end
  end

  @doc """
  Initialize a stateful session for multi-call DLL simulation.

  Returns `{:ok, session}` where session is an opaque term
  containing the Erlog engine state and the Prolog simulator state.
  """
  def init_session(source) do
    with {:ok, erlog} <- ErlogEngine.new(),
         {:ok, simple_ast, erlog2} <- ErlogEngine.parse(erlog, source),
         {:ok, modular_ast, erlog3} <- ErlogEngine.bridge(erlog2, simple_ast),
         {:ok, prolog_state, erlog4} <- ErlogEngine.init_session(erlog3, modular_ast) do
      {:ok, %{erlog: erlog4, state: prolog_state}}
    end
  end

  @doc """
  Call a procedure on an existing session.
  Returns {:ok, result, new_session}.
  """
  def call_procedure(%{erlog: erlog, state: prolog_state} = _session, proc_name, args) do
    case ErlogEngine.call_procedure(erlog, prolog_state, proc_name, args) do
      {:ok, result, new_prolog_state, new_erlog} ->
        {:ok, result, %{erlog: new_erlog, state: new_prolog_state}}

      error ->
        error
    end
  end

  @doc """
  Execute a PROGRAM with event simulation (for GUI testing).
  """
  def exec_program(source, events) do
    with {:ok, erlog} <- ErlogEngine.new(),
         {:ok, simple_ast, erlog2} <- ErlogEngine.parse(erlog, source),
         {:ok, modular_ast, erlog3} <- ErlogEngine.bridge(erlog2, simple_ast),
         {:ok, result, final_state, _erlog4} <-
           ErlogEngine.exec_program(erlog3, modular_ast, events) do
      {:ok, result, final_state}
    end
  end

  @doc """
  Prove an arbitrary Prolog goal for backward execution.

  This is the key capability enabled by running the simulator in Erlog:
  you can query what variable assignments produce a desired output.

  ## Example

      # After init_session, query what inputs make Result = 152
      ClarionSim.query(session, {:exec_statements, body, init_state, {:final}, {:control}})
  """
  def query(%{erlog: erlog} = _session, goal) do
    case ErlogEngine.query(erlog, goal) do
      {:ok, bindings, _erlog2} -> {:ok, bindings}
      {:fail, _} -> :fail
    end
  end

  @doc """
  Get the output messages accumulated during execution.
  """
  def get_output(%{erlog: erlog, state: prolog_state}) do
    case ErlogEngine.get_state_output(erlog, prolog_state) do
      {:ok, output} -> output
      _ -> []
    end
  end

  @doc """
  Get a variable value from a session state.
  """
  def get_var(%{erlog: erlog, state: prolog_state}, name) do
    ErlogEngine.get_state_var(erlog, prolog_state, name)
  end
end
