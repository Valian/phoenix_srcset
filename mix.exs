defmodule PhoenixSrcset.MixProject do
  use Mix.Project

  @version "0.0.1"
  @repo_url "https://github.com/Valian/phoenix_srcset"

  def project do
    [
      app: :phoenix_srcset,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description:
        "Dead-simple responsive images for Phoenix. Generate srcset variants with ImageMagick.",
      package: package(),

      # Docs
      name: "PhoenixSrcset",
      docs: [
        source_ref: "v#{@version}",
        source_url: @repo_url,
        homepage_url: @repo_url,
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Jakub Skalecki"],
      licenses: ["MIT"],
      links: %{
        GitHub: @repo_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end
end
