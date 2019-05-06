defmodule Scrappy.MixProject do
  use Mix.Project

  @description "Scrappy is a scraper."
  @version "0.1.0"
  def project do
    [
      app: :scrappy,
      name: "Scrappy",
      version: @version,
      description: @description,
      version: "0.1.0",
      elixir: "~> 1.8",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/arghmeleg/scrappy"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "1.5.0"},
      {:floki, "~> 0.20.4"}
    ]
  end

  defp package do
    %{
      maintainers: ["Steve DeGele"],
      licenses: ["MIT"],
      files: [
        "lib",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE",
      ],
      links: %{
        "GitHub" => "https://github.com/arghmeleg/scrappy"
      }
    }
  end
end
