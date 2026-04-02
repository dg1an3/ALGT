defmodule ClarionReader.Engine do
  @moduledoc """
  Wraps the Erlog Prolog interpreter for Clarion parsing.

  Initializes Erlog, loads the compatibility layer and adapted Clarion DCG
  parser, and provides an Elixir-friendly API for parsing Clarion source code.
  """

  # Compile-time paths relative to this source file (lib/clarion_reader/)
  @compat_path Path.expand("../../prolog/compat.pl", __DIR__)
  @default_parser Path.expand("../../../unified/clarion_parser.pl", __DIR__)

  defstruct [:erlog_state]

  @doc """
  Create a new engine with the parser loaded.

  Requires the path to the original clarion_parser.pl.
  The parser is adapted for Erlog on the fly and loaded.
  """
  def new(parser_path \\ @default_parser) do
    # Adapt the parser for Erlog compatibility
    adapted_path = Path.join(System.tmp_dir!(), "clarion_parser_erlog.pl")
    ClarionReader.ParserAdapter.adapt_to_file(parser_path, adapted_path)

    # Initialize Erlog
    {:ok, state} = :erlog.new()

    # Load compatibility predicates
    {:ok, state} = :erlog.consult(String.to_charlist(@compat_path), state)

    # Load the adapted parser
    case :erlog.consult(String.to_charlist(adapted_path), state) do
      {:ok, state} ->
        # Assert parse_clarion_codes/2 that takes a code list directly
        # (avoids Erlang atom size limits for large source files)
        clause = {:":-", {:parse_clarion_codes, {:Codes}, {:AST}},
                  {:phrase, {:program, {:AST}}, {:Codes}}}
        {{:succeed, _}, state} = :erlog.prove({:assertz, clause}, state)
        {:ok, %__MODULE__{erlog_state: state}}

      {:error, error} ->
        {:error, {:parser_load_failed, error, adapted_path}}
    end
  end

  @doc """
  Parse Clarion source code and return the AST as an Elixir term.
  """
  def parse(engine, source) when is_binary(source) do
    # Convert source to character code list for Prolog's phrase/2
    # parse_clarion/2 handles both atoms and code lists via string_to_list
    codes = String.to_charlist(source)
    goal = {:parse_clarion_codes, codes, {:AST}}

    case :erlog.prove(goal, engine.erlog_state) do
      {{:succeed, bindings}, new_state} ->
        ast = find_binding(:AST, bindings)
        {:ok, erlog_to_elixir(ast), %{engine | erlog_state: new_state}}

      {:fail, new_state} ->
        {:error, :parse_failed, %{engine | erlog_state: new_state}}
    end
  end

  @doc """
  Parse a Clarion .clw file by reading it and parsing the contents.
  """
  def parse_file(engine, file_path) do
    source = File.read!(file_path)
    parse(engine, source)
  end

  @doc """
  Prove an arbitrary Prolog goal (for testing/debugging).
  """
  def prove(engine, goal) do
    case :erlog.prove(goal, engine.erlog_state) do
      {{:succeed, bindings}, new_state} ->
        {:ok, bindings, %{engine | erlog_state: new_state}}

      {:fail, new_state} ->
        {:error, :fail, %{engine | erlog_state: new_state}}
    end
  end

  # Find a variable binding in the result
  defp find_binding(var_name, bindings) do
    case List.keyfind(bindings, var_name, 0) do
      {^var_name, value} -> value
      nil -> nil
    end
  end

  @doc """
  Convert Erlog term representation to idiomatic Elixir.

  Erlog terms:
  - Atoms -> Elixir atoms
  - Numbers -> Elixir numbers
  - Lists -> Elixir lists
  - {Functor, Arg1, ...} -> {:functor, [arg1, ...]} tagged tuple
  - {VarName} -> {:var, VarName} (unbound variable)
  """
  def erlog_to_elixir(term) do
    convert(term)
  end

  defp convert(term) when is_atom(term), do: term
  defp convert(term) when is_integer(term), do: term
  defp convert(term) when is_float(term), do: term
  defp convert([]), do: []
  defp convert([h | t]), do: [convert(h) | convert(t)]

  # Erlog variable (unbound) - 1-tuple
  defp convert({var_name}) when is_atom(var_name), do: {:var, var_name}
  defp convert({n}) when is_integer(n), do: {:var, n}

  # Erlog compound term - tuple with functor as first element
  defp convert(tuple) when is_tuple(tuple) and tuple_size(tuple) >= 2 do
    [functor | args] = Tuple.to_list(tuple)
    {functor, Enum.map(args, &convert/1)}
  end

  # Fallback
  defp convert(other), do: other
end
