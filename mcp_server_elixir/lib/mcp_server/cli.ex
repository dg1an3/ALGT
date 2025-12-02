defmodule McpServer.CLI do
  @moduledoc """
  Command-line interface for the MCP server.

  Used as the entry point for the escript.
  """

  def main(_args) do
    McpServer.start()
  end
end
