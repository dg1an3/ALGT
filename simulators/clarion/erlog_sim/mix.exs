defmodule ClarionSim.MixProject do
  use Mix.Project

  def project do
    [
      app: :clarion_sim,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:erlog, github: "rvirding/erlog"}
    ]
  end
end
