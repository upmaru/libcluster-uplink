# ClusterUplink

Libcluster strategy for uplink. This strategy will connect to the unix socket inside your container and retrieve service discovery endpoint. It will then call the endpoint and retrieve the list of instances to connect to.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `libcluster_uplink` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_uplink, "~> 0.1.0"}
  ]
end
```

```elixir
config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Uplink,
      config: [
        app_name: "your-app"
      ]
    ]
  ]
```

## Configuration

| Key | Required | Description |
| :-- | :------: | :---------- |
| `:app_name` | ✓ | The name of your elixir application |

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/libcluster_uplink>.


