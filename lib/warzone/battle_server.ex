defmodule Warzone.BattleServer do
  alias Warzone.{Battle, Ship, Missile, Cache, Player}

  use GenServer

  @physics_timestep 500
  @input_timestep 2500

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Battle{}, name: __MODULE__)
  end

  def init(_) do
    file = "ship.lua"
    code_path = Path.join(:code.priv_dir(:warzone), file)
    base_ai = Sandbox.play_file!(Sandbox.init(), code_path)
    Process.send_after(self(), :update, @physics_timestep)
    Process.send_after(self(), :generate_commands, @input_timestep)
    {:ok, %Battle{base_ai: base_ai}}
  end

  def join() do
    player_pid = self()
    GenServer.cast(__MODULE__, {:join, player_pid})
  end

  def submit_name(name) do
    player_pid = self()
    GenServer.cast(__MODULE__, {:submit_name, player_pid, name})
  end

  def submit_code(code) do
    player_pid = self()
    GenServer.cast(__MODULE__, {:submit_code, player_pid, code})
  end

  def debug() do
    player_pid = self()
    GenServer.cast(__MODULE__, {:debug, player_pid})
  end

  def handle_info({:receive_commands, commands_by_id}, %Battle{} = battle) do
    IO.inspect("got commands #{inspect(commands_by_id)}")
    {:noreply, %Battle{battle | commands_by_id: commands_by_id}}
  end

  def handle_info(:generate_commands, %Battle{} = battle) do
    Task.Supervisor.async_nolink(Warzone.TaskSupervisor, fn ->
      Battle.generate_commands(battle)
    end)
    Process.send_after(self(), :generate_commands, @input_timestep)
    {:noreply, battle}
  end

  def handle_cast({:join, player_pid}, %Battle{} = battle) do
    {:noreply, Battle.join(battle, player_pid)}
  end

  def handle_cast({:submit_name, player_pid, name}, %Battle{} = battle) do
    {:noreply, Battle.submit_name(battle, player_pid, name)}
  end

  def handle_cast({:submit_code, player_pid, code}, %Battle{} = battle) do
    Task.Supervisor.async_nolink(Warzone.TaskSupervisor, fn ->
      Battle.submit_code(battle, player_pid, code)
    end)
    {:noreply, battle}
  end

  def handle_cast({:debug, player_pid}, %Battle{} = battle) do
    IO.inspect(battle)
    {:noreply, battle}
  end

  def handle_info(:update, %Battle{} = battle) do
    Process.send_after(self(), :update, 500)
    {:noreply, Battle.update(battle)}
  end

#  def handle_info(:input, %Battle{} = battle) do
#    Process.send_after(self(), :generate_commands, 500)
#    {:noreply, Battle.update(battle)}
#  end


  def handle_info({ref, {:commands_by_id, commands_by_id}}, %Battle{} = battle) when is_reference(ref) do
#    IO.puts("cid #{inspect(commands_by_id)}")
    Process.demonitor(ref, [:flush])
    {:noreply, %Battle{battle | commands_by_id: commands_by_id}}
  end

  def handle_info({ref, {:submitted_code, id, code, ai_state}}, %Battle{} = battle) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, battle |> Battle.update_code(id, code, ai_state)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %Battle{} = battle) do
    {:noreply, battle}
  end

end
