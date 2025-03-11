defmodule Interval.MixProject do
  use Mix.Project

  @version "2.0.0-alpha.2"
  @source_url "https://github.com/tbug/elixir_interval"

  def project do
    [
      app: :interval,
      description: """
      Interval/range operations on Decimal, DateTime, Integer, Float, etc.
      Ecto support for Postgres range types like int4range, daterange, tstzrange, etc.
      Implement intervals over your own custom data.
      """,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs() do
    [
      name: "Interval",
      source_url: @source_url,
      docs: [
        assets: %{
          "assets" => "assets"
        },
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
        source_ref: "v#{@version}",
        main: "readme",
        extras: [
          "README.md": [filename: "readme", title: "Readme"],
          "CHANGELOG.md": []
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
      ignore_modules: [Helper],
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
      plt_add_apps: [:ecto, :decimal]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, ">= 3.4.3 and < 4.0.0", optional: true},
      {:postgrex, "~> 0.14", optional: true},
      {:decimal, "~> 2.0", optional: true},
      {:stream_data, "~> 1.0", only: [:test, :dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end
end
