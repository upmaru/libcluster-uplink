defmodule Cluster.Strategy.Uplink do
  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State

  @default_polling_interval 5_000
  @service_discovery_key ~s(http:///1.0/config/user.service_discovery_endpoint)

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]) do
    init([%State{state | :meta => MapSet.new()}])
  end

  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, state) do
    {:noreply, load(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp load(
         %State{
           topology: topology,
           connect: connect,
           disconnect: disconnect,
           list_nodes: list_nodes
         } = state
       ) do
    case get_nodes(state) do
      {:ok, new_nodes} ->
        removed = MapSet.difference(state.meta, new_nodes)

        new_nodes =
          disconnect_nodes(
            topology,
            disconnect,
            list_nodes,
            MapSet.to_list(removed),
            new_nodes
          )

        new_nodes =
          connect_nodes(
            topology,
            connect,
            list_nodes,
            MapSet.to_list(new_nodes),
            new_nodes
          )

        Process.send_after(
          self(),
          :load,
          Keyword.get(
            state.config,
            :polling_interval,
            @default_polling_interval
          )
        )

        %State{state | :meta => new_nodes}

      _ ->
        Process.send_after(
          self(),
          :load,
          Keyword.get(
            state.config,
            :polling_interval,
            @default_polling_interval
          )
        )

        state
    end
  end

  defp get_nodes(%State{config: config}) do
    app_name = Keyword.fetch!(config, :app_name)
    service_discovery_endpoint = Keyword.get(config, :service_discovery_endpoint)

    endpoint =
      if service_discovery_endpoint do
        service_discovery_endpoint
      else
        %{body: instances_url} = Req.get!(@service_discovery_key, unix_socket: "/dev/lxd/sock")
        instances_url
      end

    Req.get!(endpoint)
    |> case do
      %{status: 200, body: %{"data" => %{"attributes" => %{"instances" => nodes}}}} ->
        nodes =
          nodes
          |> Enum.map(fn node_slug ->
            :"#{app_name}@#{node_slug}"
          end)

        {:ok, MapSet.new(nodes)}

      _ ->
        {:error, []}
    end
  end

  defp disconnect_nodes(
         topology,
         disconnect,
         list_nodes,
         to_be_removed,
         new_nodes
       ) do
    case Cluster.Strategy.disconnect_nodes(
           topology,
           disconnect,
           list_nodes,
           to_be_removed
         ) do
      :ok ->
        new_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, new_nodes, fn {n, _}, acc ->
          MapSet.put(acc, n)
        end)
    end
  end

  defp connect_nodes(topology, connect, list_nodes, to_be_connected, new_nodes) do
    case Cluster.Strategy.connect_nodes(
           topology,
           connect,
           list_nodes,
           to_be_connected
         ) do
      :ok ->
        new_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, new_nodes, fn {n, _}, acc ->
          MapSet.delete(acc, n)
        end)
    end
  end
end
