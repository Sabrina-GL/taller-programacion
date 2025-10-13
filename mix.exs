defmodule Ledger.MixProject do
  use Mix.Project

  def project do
    [
      app: :ledger,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      name: "Ledger",
      source_url: "https://github.com/Sabrina-GL/taller-programacion/tree/tp1",
      docs: [
        main: "Ledger",
        output: "docs",
        extras: ["README.md"]
      ],
      package: [
        description: "Sistema de libro contable para transacciones multi-moneda",
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/Sabrina-GL/taller-programacion/tree/tp1"
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # extra_applications: [:logger]
      mod: {Ledger.Application, []},
      extra_applications: [:logger, :ecto_sql]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp escript do
    [
      main_module: Ledger
      # - 0 si main() retorna 0 o :ok
      # - 1 si main() retorna != 0 o :error
    ]
  end
end
