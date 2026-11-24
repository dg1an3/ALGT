defmodule ClarionReader.MixProject do
  use Mix.Project

  def project do
    [
      app: :clarion_reader,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: ClarionReader.CLI],
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
      {:erlog, git: "https://github.com/zkessin/erlog.git", branch: "master"}
    ]
  end
end
