defmodule BambooPostmark.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bamboo_postmark,
      version: "0.0.1",
      elixir: "~> 1.11",
      name: "bamboo_postmark",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bamboo, ">= 2.0.0"},
      {:hackney, ">= 1.6.5"},
      {:poison, ">= 1.5.0", only: :test},
      {:plug, "~> 1.0"},
      {:plug_cowboy, "~> 1.0", only: [:test, :dev]},
      {:ex_doc, "> 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: "https://github.com/plausible/bamboo_postmark",
      homepage_url: "https://github.com/plausible/bamboo_postmark",
      formatters: ["html"]
    ]
  end
end
