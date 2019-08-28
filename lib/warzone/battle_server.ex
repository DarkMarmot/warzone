defmodule Warzone.BattleServer do
  alias Warzone.{Battle}

  use GenServer

  @physics_timestep 1000
  @input_timestep 5000
  @compile_timestep 2500


  @updates_per_input @input_timestep / @physics_timestep

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Battle{}, name: __MODULE__)
  end

  def init(_) do
    file = "ship.lua"
    code_path = Path.join(:code.priv_dir(:warzone), file)
    base_ai = Sandbox.play_file!(Sandbox.init(), code_path)
    Process.send_after(self(), :update, @physics_timestep)
    Process.send_after(self(), :generate_commands, @input_timestep)
    Process.send_after(self(), :compile_code, @compile_timestep)
    {:ok, %Battle{base_ai: base_ai}}
  end

  def join(user_name) do
    player_pid = self()
    GenServer.cast(__MODULE__, {:join, player_pid, user_name})
  end

  def leave() do
    player_pid = self()
    GenServer.cast(__MODULE__, {:leave, player_pid})
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
#    IO.inspect("got commands #{inspect(commands_by_id)}")
    {:noreply, %Battle{battle | commands_by_id: commands_by_id}}
  end

  def handle_info(:generate_commands, %Battle{} = battle) do
    Task.Supervisor.async_nolink(Warzone.TaskSupervisor, fn ->
      Battle.generate_commands(battle)
    end)

    Process.send_after(self(), :generate_commands, @input_timestep)
    {:noreply, battle}
  end

  def handle_info(:compile_code, %Battle{} = battle) do
    Task.Supervisor.async_nolink(Warzone.TaskSupervisor, fn ->
      Battle.compile_code(battle)
    end)

    Process.send_after(self(), :compile_code, @compile_timestep)
    {:noreply, battle}
  end

  def handle_cast({:join, player_pid, user_name}, %Battle{} = battle) do
    {:noreply, Battle.join(battle, player_pid, user_name)}
  end

  def handle_cast({:leave, player_pid}, %Battle{} = battle) do
    {:noreply, Battle.leave(battle, player_pid)}
  end

  def handle_cast({:submit_name, player_pid, name}, %Battle{} = battle) do
    {:noreply, Battle.submit_name(battle, player_pid, name)}
  end

  def handle_cast({:submit_code, player_pid, code}, %Battle{} = battle) do
#    Task.Supervisor.async_nolink(Warzone.TaskSupervisor, fn ->
#      Battle.submit_code(battle, player_pid, code)
#    end)

    {:noreply, Battle.submit_code(battle, player_pid, code)}
  end

  def handle_cast({:debug, _player_pid}, %Battle{} = battle) do
    IO.inspect(battle)
    {:noreply, battle}
  end

  def handle_info(:update, %Battle{} = battle) do
    Process.send_after(self(), :update, @physics_timestep)
    {:noreply, Battle.update(battle)}
  end

  def handle_info({ref, {:commands_by_id, commands_by_id}}, %Battle{} = battle)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, battle |> Battle.distribute_commands_to_ships(commands_by_id)}
  end

  def handle_info({ref, {:ai_states_by_id, ai_states_by_id}}, %Battle{} = battle)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, battle |> Battle.distribute_ai_states_to_ships(ai_states_by_id)}
  end
#  def handle_info({ref, {:submitted_code, id, code, ai_state}}, %Battle{} = battle)
#      when is_reference(ref) do
#    Process.demonitor(ref, [:flush])
#    {:noreply, battle |> Battle.update_code(id, code, ai_state)}
#  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %Battle{} = battle) do
    IO.inspect("down!: #{inspect(pid)}")
    {:noreply, battle}
  end
end
