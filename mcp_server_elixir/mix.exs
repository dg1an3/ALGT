defmodule McpServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcp_server,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),

      # Docs
      name: "ALGT MCP Server",
      description: "Model Context Protocol server for ALGT in Elixir"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {McpServer.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp escript do
    [
      main_module: McpServer.CLI,
      name: :mcp_server
    ]
  end
end
