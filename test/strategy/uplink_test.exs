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
          service_discovery_endpoint: "http://localhost:#{bypass.port}/installs/1/instances",
          req_options: [retry: false]
        ]
      }

      %{state: state}
    end

    @tag skip: not (match?({:unix, _}, :os.type()) and Code.ensure_loaded?(:socket))
    test "resolves the discovery endpoint through the LXD Unix socket", %{
      bypass: bypass,
      state: state
    } do
      endpoint = "http://localhost:#{bypass.port}/installs/1/instances"
      {socket_path, listener, lxd_server} = start_lxd_server(endpoint)

      on_exit(fn ->
        :socket.close(listener)
        File.rm(socket_path)
      end)

      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{data: %{attributes: %{instances: ["uplink-something-01"]}}})
        )
      end)

      state = %{
        state
        | config:
            state.config
            |> Keyword.delete(:service_discovery_endpoint)
            |> Keyword.put(:lxd_socket, socket_path)
      }

      Uplink.start_link([state])

      assert_receive {:lxd_request, request}, 100

      assert request =~ "GET /1.0/config/user.service_discovery_endpoint HTTP/1.1\r\n"
      assert String.downcase(request) =~ ~r/\r\nhost: localhost(?::\d+)?\r\n/
      assert_receive {:connect, :"uplink@uplink-something-01"}, 100
      Task.await(lxd_server)
    end

    test "should add new nodes", %{bypass: bypass, state: state} do
      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{data: %{attributes: %{instances: ["uplink-something-01"]}}})
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
          Jason.encode!(%{data: %{attributes: %{instances: ["uplink-something-01"]}}})
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
          Jason.encode!(%{data: %{attributes: %{instances: ["uplink-something-01"]}}})
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

      Bypass.expect_once(bypass, "GET", "/installs/1/instances", fn conn ->
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

  defp start_lxd_server(endpoint) do
    socket_path = "/tmp/libcluster-uplink-#{System.unique_integer([:positive])}.sock"
    File.rm(socket_path)

    {:ok, listener} = :socket.open(:local, :stream, :default)
    :ok = :socket.bind(listener, %{family: :local, path: socket_path})
    :ok = :socket.listen(listener)

    test_pid = self()

    lxd_server =
      Task.async(fn ->
        {:ok, socket} = :socket.accept(listener)
        {:ok, request} = :socket.recv(socket, 0)
        send(test_pid, {:lxd_request, request})

        response = [
          "HTTP/1.1 200 OK\r\n",
          "content-type: text/plain\r\n",
          "content-length: ",
          Integer.to_string(byte_size(endpoint)),
          "\r\n",
          "connection: close\r\n\r\n",
          endpoint
        ]

        :ok = :socket.send(socket, response)
        :socket.close(socket)
      end)

    {socket_path, listener, lxd_server}
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
