defmodule ClusterUplink.MixProject do
  use Mix.Project

  @url "https://github.com/upmaru/libcluster-uplink"

  def project do
    [
      app: :libcluster_uplink,
      version: "0.4.1",
      elixir: "~> 1.14",
      source_url: @url,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => @url}
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        authors: ["Zack Siri"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Uplink strategy for libcluster
    """
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:libcluster, "~> 3.5"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [
      test: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end
