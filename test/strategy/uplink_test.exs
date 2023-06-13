defmodule Cluster.Strategy.UplinkTest do
  use ExUnit.Case, async: true

  alias Cluster.Strategy.Uplink

  setup do
    bypass = Bypass.open()

    {:ok, bypass: bypass}
  end

  describe "start_link/1" do
    setup %{bypass: bypass} do
      state = %Cluster.Strategy.State{
        topology: Uplink,
        list_nodes: {__MODULE__, :list_nodes, [[]]},
        connect: {__MODULE__, :connect, [self()]},
        disconnect: {__MODULE__, :disconnect, [self()]},
        config: [
          app_name: "uplink",
          service_discovery_endpoint: "http://localhost:#{bypass.port}/installs/1/instances"
        ]
      }

      %{state: state}
    end

    test "should add new nodes", %{bypass: bypass, state: state} do
      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{attributes: %{instances: ["uplink-something-01"]}})
        )
      end)

      Uplink.start_link([state])

      assert_receive {:connect, :"uplink@uplink-something-01"}, 100
    end

    test "should remove nodes", %{bypass: bypass, state: state} do
      nodes = [:"uplink@uplink-something-01", :"uplink@uplink-something-02"]

      state = Map.put(state, :meta, MapSet.new(nodes))
      state = Map.put(state, :list_nodes, {__MODULE__, :list_nodes, [nodes]})

      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{attributes: %{instances: ["uplink-something-01"]}})
        )
      end)

      Uplink.start_link([state])

      assert_receive {:disconnect, :"uplink@uplink-something-02"}, 100
      refute_receive {:connect, :"uplink@uplink-something-01"}, 100
    end

    test "should not do anything if node not changed", %{bypass: bypass, state: state} do
      nodes = [:"uplink@uplink-something-01"]

      state = Map.put(state, :meta, MapSet.new(nodes))
      state = Map.put(state, :list_nodes, {__MODULE__, :list_nodes, [nodes]})

      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{attributes: %{instances: ["uplink-something-01"]}})
        )
      end)

      Uplink.start_link([state])

      refute_receive {:connect, _}, 100
      refute_receive {:disconnect, _}, 100
    end

    test "do nothing if server returns error", %{bypass: bypass, state: state} do
      nodes = [:"uplink@uplink-something-01"]

      state = Map.put(state, :meta, MapSet.new(nodes))
      state = Map.put(state, :list_nodes, {__MODULE__, :list_nodes, [nodes]})

      Bypass.expect(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          500,
          Jason.encode!(~s(internal server error))
        )
      end)

      Uplink.start_link([state])

      refute_receive {:connect, _}, 100
      refute_receive {:disconnect, _}, 100
    end
  end

  def list_nodes(nodes), do: nodes

  def connect(caller, result \\ true, node) do
    send(caller, {:connect, node})
    result
  end

  def disconnect(caller, result \\ true, node) do
    send(caller, {:disconnect, node})
    result
  end
end
