defmodule Interval.MixProject do
  use Mix.Project

  @version "0.3.3"
  @source_url "https://github.com/tbug/elixir_interval"

  def project do
    [
      app: :interval,
      description: """
      Interval operations on Decimal, DateTime, Integer, Float, etc.
      with Ecto support for Postgres Range types,
      and implementing intervals over your own custom structs.
      """,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      test_coverage: test_coverage(),
      preferred_cli_env: [check: :test],
      deps: deps(),
      package: package(),
      aliases: aliases(),
      dialyzer: dialyzer()
    ] ++ docs()
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs() do
    [
      name: "Interval",
      source_url: @source_url,
      # homepage_url: "https://github.com/tbug/interval_elixir",
      docs: [
        source_ref: "v#{@version}",
        main: "Interval",
        extras: [
          "README.md",
          "CHANGELOG.md"
        ]
      ]
    ]
  end

  defp package() do
    [
      links: %{"GitHub" => @source_url},
      licenses: [
        "Apache-2.0"
      ]
    ]
  end

  defp test_coverage() do
    [
      summary: [threshold: 85]
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "credo suggest --all --format=oneline",
        "test --cover --slowest 5"
      ]
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :underspecs, :unmatched_returns, :no_return],
      plt_add_apps: [:ecto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, ">= 3.4.3 and < 4.0.0", optional: true},
      {:postgrex, "~> 0.14", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:decimal, "~> 2.0", optional: true},
      {:stream_data, "~> 0.5", only: [:test, :dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end
end
