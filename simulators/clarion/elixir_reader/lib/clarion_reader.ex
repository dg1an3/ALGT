defmodule ClarionReader do
  @moduledoc """
  Reads and displays Clarion source code using Erlog and the Clarion DCG parser.

  Uses the Erlog Prolog interpreter to run the existing Clarion DCG parser
  (from simulators/clarion/unified/clarion_parser.pl), producing an AST that
  can be displayed as a readable tree.
  """

  @doc """
  Parse and display a Clarion source string.
  Returns {:ok, formatted_string} or {:error, reason}.
  """
  def read_and_display(source, opts \\ []) do
    parser_path = Keyword.get(opts, :parser_path, nil)

    engine_args = if parser_path, do: [parser_path], else: []
    {:ok, engine} = apply(ClarionReader.Engine, :new, engine_args)

    case ClarionReader.Engine.parse(engine, source) do
      {:ok, ast, _engine} ->
        formatted = ClarionReader.Display.format(ast)
        {:ok, formatted}

      {:error, reason, _engine} ->
        {:error, reason}
    end
  end

  @doc """
  Parse and display a Clarion .clw file.
  """
  def read_file(file_path, opts \\ []) do
    source = File.read!(file_path)
    read_and_display(source, opts)
  end
end
