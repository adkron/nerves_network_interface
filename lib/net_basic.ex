# Copyright 2014 LKC Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule NetBasic do
  use GenServer

  @moduledoc """
  This module exposes a simplified view of Linux network configuration to
  applications.

  ## Overview

  This module should be added to a supervision tree or started via the
  `start_link/0` call. Once running, the module provides functions to
  list network interfaces, modify their state (up or down), get statistics
  and set IP networking parameters. Network events, such as when an Ethernet
  cable is connected, are reported via a `GenEvent`.

  ## Privilege

  The functions that return information don't require that the `NetBasic`'s
  associated port process has privileged access to the system. If you
  need to change any parameters or bring up or down an interface, you should
  ensure that the port process is running as a privileged user.
  """

  defstruct port: nil,
            manager: nil,
            requests: []

  @doc """
  Start and link a NetBasic process. A GenEvent will be spawned for managing
  link layer events. Call Event_manager/1 to get the GenEvent pid.
  """
  def start_link() do
    { :ok, manager } = GenEvent.start_link
    GenServer.start_link(__MODULE__, manager)
  end

  @doc """
  Start and link a NetBasic process. Use the specified GenEvent for sending
  all network link events.
  """
  def start_link(event_manager, opts \\ []) do
    GenServer.start_link(__MODULE__, event_manager, opts)
  end

  @doc """
  Return the GenEvent pid that is being used for sending events.
  """
  def event_manager(pid) do
    GenServer.call(pid, :event_manager)
  end

  @doc """
  Manually stop the server.
  """
  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  @doc """
  Return the list of network interfaces on this machine.
  """
  def interfaces(pid) do
    GenServer.call(pid, :interfaces)
  end

  @doc """
  Return link-level status on the specified interface.
  """
  def status(pid, ifname) do
    GenServer.call(pid, {:status, ifname})
  end

  @doc """
  Bring the specified interface up.
  """
  def ifup(pid, ifname) do
    GenServer.call(pid, {:ifup, ifname})
  end

  @doc """
  Bring the specified interface down.
  """
  def ifdown(pid, ifname) do
    GenServer.call(pid, {:ifdown, ifname})
  end

  @doc """
  Return IP configuration for the specified interface.
  """
  def get_config(pid, ifname) do
    GenServer.call(pid, {:get_config, ifname})
  end

  @doc """
  Set IP settings for the specified interface. The following options are
  available:

    * `:ipv4_address` - the IPv4 address of the interface
    * `:ipv4_broadcast` - the IPv4 broadcast address for the interface
    * `:ipv4_subnet_mask` - the IPv4 subnet mask
    * `:ipv4_gateway` - the default gateway

  Options can be specified either as a keyword list or as a map.
  """
  def set_config(pid, ifname, options) when is_list(options) do
    set_config(pid, ifname, :maps.from_list(options))
  end
  def set_config(pid, ifname, options) when is_map(options) do
    GenServer.call(pid, {:set_config, ifname, options})
  end

  def init(event_manager) do
    executable = :code.priv_dir(:net_basic) ++ '/net_basic'
    port = Port.open({:spawn_executable, executable},
    [{:packet, 2}, :use_stdio, :binary])
    { :ok, %NetBasic{port: port, manager: event_manager} }
  end

  def handle_call(:interfaces, _from, state) do
    {:ok, response} = call_port(state, :interfaces, [])
    {:reply, response, state }
  end
  def handle_call({:status, ifname}, _from, state) do
    {:ok, response} = call_port(state, :status, ifname)
    {:reply, response, state }
  end
  def handle_call(:event_manager, _from, state) do
    {:reply, state.manager, state}
  end
  def handle_call({:ifup, ifname}, _from, state) do
    {:ok, response} = call_port(state, :ifup, ifname)
    {:reply, response, state }
  end
  def handle_call({:ifdown, ifname}, _from, state) do
    {:ok, response} = call_port(state, :ifdown, ifname)
    {:reply, response, state }
  end
  def handle_call({:set_config, ifname, options}, _from, state) do
    {:ok, response} = call_port(state, :set_config, {ifname, options})
    {:reply, response, state }
  end
  def handle_call({:get_config, ifname}, _from, state) do
    {:ok, response} = call_port(state, :get_config, ifname)
    {:reply, response, state }
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info({_, {:data, <<?n, message::binary>>}}, state) do
    {notif, data} = :erlang.binary_to_term(message)
    GenEvent.notify(state.manager, {:net_basic, self, notif, data})
    {:noreply, state}
  end
  def handle_info({_, {:exit_status, _}}, state) do
    {:stop, :unexpected_exit, state}
  end

  # Private helper functions
  defp call_port(state, command, arguments) do
    msg = {command, arguments}
    send state.port, {self, {:command, :erlang.term_to_binary(msg)}}
    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        {:ok, :erlang.binary_to_term(response)}
    after
      1_000 -> :error
    end
  end
end
