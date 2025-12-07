defmodule McpServer.Application do
  @moduledoc """
  OTP Application for the MCP Server.

  Starts the supervision tree when used as an OTP application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      McpServer.Tools
    ]

    opts = [strategy: :one_for_one, name: McpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
