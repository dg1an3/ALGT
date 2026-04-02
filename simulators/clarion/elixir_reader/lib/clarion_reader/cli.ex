defmodule ClarionReader.CLI do
  @moduledoc """
  Command-line interface for the Clarion code reader.

  Usage:
    clarion_reader <file.clw>              Parse and display a Clarion file
    clarion_reader --ast <file.clw>        Show raw AST instead of formatted
    clarion_reader --adapt-only            Just output the adapted parser (for debugging)
  """

  def main(args) do
    case parse_args(args) do
      {:file, path, :display} ->
        read_and_display_file(path)

      {:file, path, :ast} ->
        read_and_show_ast(path)

      :adapt_only ->
        adapt_only()

      :help ->
        print_usage()
    end
  end

  defp parse_args(["--help" | _]), do: :help
  defp parse_args(["-h" | _]), do: :help
  defp parse_args(["--adapt-only" | _]), do: :adapt_only
  defp parse_args(["--ast", path | _]), do: {:file, path, :ast}
  defp parse_args([path | _]), do: {:file, path, :display}
  defp parse_args([]), do: :help

  defp read_and_display_file(path) do
    IO.puts("Parsing #{path}...")
    IO.puts("")

    case ClarionReader.read_file(path) do
      {:ok, formatted} ->
        IO.puts(formatted)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp read_and_show_ast(path) do
    IO.puts("Parsing #{path}...")
    IO.puts("")

    {:ok, engine} = ClarionReader.Engine.new()

    case ClarionReader.Engine.parse_file(engine, path) do
      {:ok, ast, _engine} ->
        IO.inspect(ast, pretty: true, limit: :infinity)

      {:error, reason, _engine} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp adapt_only do
    parser_path = Path.expand("../../../../unified/clarion_parser.pl", __DIR__)
    adapted = ClarionReader.ParserAdapter.adapt(parser_path)
    IO.puts(adapted)
  end

  defp print_usage do
    IO.puts("""
    Clarion Code Reader — Parse and display Clarion source using Erlog + DCG

    Usage:
      clarion_reader <file.clw>          Parse and display formatted
      clarion_reader --ast <file.clw>    Show raw Elixir AST
      clarion_reader --adapt-only        Output adapted parser (debug)
      clarion_reader --help              This message
    """)
  end
end
