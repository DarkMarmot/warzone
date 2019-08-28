defmodule Warzone.Battle do
  alias Warzone.{Battle, Collision, Ship, Missile, CommandSet, Collision, MapEnum}

  @realm_size 10000
  @missile_size 0
  @ship_size 20
  @hash_size 100

  defstruct base_ai: nil,
            ships_by_id: %{},
            missiles_by_id: %{},
            ship_ids_by_spatial_hash: %{},
            missile_ids_by_spatial_hash: %{},
            collisions: [],
            commands_by_id: %{},
            stardate: 0,
            messages: [],
            id_counter: 0

  def advance_counter(%Battle{id_counter: id_counter} = battle) do
    %Battle{battle| id_counter: id_counter + 1}
  end

  def join(%Battle{ships_by_id: ships_by_id, id_counter: id_counter} = battle, id, user_name) do
    put_ship(battle, %Ship{id: id, display_id: "ship_" <> to_string(id_counter), name: user_name})
    |> advance_counter()
  end

  def leave(%Battle{ships_by_id: ships_by_id} = battle, id) do
    %Battle{battle | ships_by_id: Map.delete(ships_by_id, id)}
  end

  def update(
        %Battle{ships_by_id: ships_by_id, missiles_by_id: missiles_by_id, stardate: stardate} =
          battle
      ) do
    battle
    |> advance_stardate()
    |> destroy_missiles()
    |> update_ships()
    |> update_missiles()
    |> spawn_fired_missiles_into_battle()
    |> clear_fired_missiles_from_ships()
    |> spawn_ships_into_battle()
    |> generate_spatial_hashes()
    |> determine_collisions()
    |> resolve_collisions()
    |> render_scanners()
    |> clear_messages()

    #    |> helm_ships()
    #   |> asteroid_damage() for things beyond bounds
    #   |> report_back()
  end

  def clear_messages(%Battle{} = battle) do
    %Battle{battle | messages: []}
  end

  def spawn_fired_missiles_into_battle(
        %Battle{ships_by_id: ships_by_id, missiles_by_id: missiles_by_id} = battle
      ) do
    missiles_ready =
      ships_by_id
      |> Enum.flat_map(fn {id, %Ship{missiles_ready: missiles_ready}} -> missiles_ready end)
      |> Enum.map(fn %Missile{id: id} = missile -> {id, missile} end)
      |> Map.new()

    %Battle{battle | missiles_by_id: missiles_by_id |> Map.merge(missiles_ready)}
  end

  def destroy_missiles(%Battle{missiles_by_id: missiles_by_id} = battle) do
    filter_fun = fn %Missile{destroyed: destroyed, age: age} -> !destroyed end
    %Battle{battle | missiles_by_id: missiles_by_id |> MapEnum.filter(filter_fun)}
  end

  def resolve_collisions(
        %Battle{collisions: collisions, ships_by_id: ships_by_id, missiles_by_id: missiles_by_id} =
          battle
      ) do

    collisions
    |> Enum.reduce(battle, fn c, battle_acc ->
      %Collision{ship_id: ship_id, missile_id: missile_id} = c
      missile = %Missile{get_missile(battle_acc, missile_id) | destroyed: true}
      attacker = get_ship(battle_acc, missile.owner_id)
      defender = get_ship(battle_acc, ship_id)
      if defender.playing do
          kill = missile.power >= defender.hull
          damaged_defender = defender |> Ship.apply_damage(missile.power)
          message = %{created_at: battle_acc.stardate, content: %{type: :collision, attacker: attacker.name, defender: defender.name, damage: missile.power, kill: kill}}
          battle_acc |> put_ship(damaged_defender) |> put_message(message)
      else
         battle_acc
      end
      |> put_missile(missile)
    end)

  end

  def put_message(%Battle{messages: messages} = battle, :collision, %Missile{} = missile, %Ship{} = ship) do
    battle
  end

  def get_spatial_hashes([x, y] = _position, 0 = _object_size) do
    [[trunc(x / @hash_size), trunc(y / @hash_size)]]
  end

  def get_spatial_hashes([x, y] = _position, object_size) do
    x1 = trunc((x - object_size) / @hash_size)
    x2 = trunc((x + object_size) / @hash_size)
    y1 = trunc((y - object_size) / @hash_size)
    y2 = trunc((y + object_size) / @hash_size)

    x1..x2
    |> Enum.flat_map(fn hx ->
      y1..y2 |> Enum.map(fn hy -> [hx, hy] end)
    end)
    |> Enum.uniq()
  end

  def distance([x1, y1], [x2, y2]) do
    xd = x1 - x2
    yd = y1 - y2
    :math.sqrt(xd * xd + yd * yd)
  end

  def get_ship_ids_by_spatial_hash(%Battle{ships_by_id: ships_by_id}) do
    ships_by_id
    |> Map.to_list()
    |> Enum.filter(fn {id, %Ship{playing: playing}} -> playing == true end)
    |> Enum.flat_map(fn {id, %Ship{position: position}} ->
      hashes = get_spatial_hashes(position, @ship_size)
      hashes |> Enum.map(fn hash -> {hash, id} end)
    end)
    |> Enum.group_by(fn {hash, _id} -> hash end, fn {_hash, id} -> id end)
  end

  def get_missile_ids_by_spatial_hash(%Battle{missiles_by_id: missiles_by_id}) do
    missiles_by_id
    |> Map.to_list()
    |> Enum.flat_map(fn {id, %Missile{position: position}} ->
      hashes = get_spatial_hashes(position, @missile_size)
      hashes |> Enum.map(fn hash -> {hash, id} end)
    end)
    |> Enum.group_by(fn {hash, _id} -> hash end, fn {_hash, id} -> id end)
  end

  def generate_spatial_hashes(%Battle{} = battle) do
    %Battle{
      battle
      | ship_ids_by_spatial_hash: get_ship_ids_by_spatial_hash(battle),
        missile_ids_by_spatial_hash: get_missile_ids_by_spatial_hash(battle)
    }
  end

  def determine_collisions(
        %Battle{
          ship_ids_by_spatial_hash: ship_ids_by_spatial_hash,
          missile_ids_by_spatial_hash: missile_ids_by_spatial_hash,
          ships_by_id: ships_by_id,
          missiles_by_id: missiles_by_id
        } = battle
      ) do
    hash_collisions =
      ship_ids_by_spatial_hash
      |> Map.keys()
      |> Enum.filter(fn hash -> Map.has_key?(missile_ids_by_spatial_hash, hash) end)
      |> Enum.uniq()

    collisions =
      hash_collisions
      |> Enum.flat_map(fn hash ->
        missile_ids = Map.get(missile_ids_by_spatial_hash, hash)
        ship_ids = Map.get(ship_ids_by_spatial_hash, hash)

        missile_ids
        |> Enum.flat_map(fn missile_id ->
          Enum.map(ship_ids, fn ship_id ->
            %Collision{missile_id: missile_id, ship_id: ship_id}
          end)
        end)
        |> Enum.filter(fn %Collision{missile_id: missile_id, ship_id: ship_id} ->
          %Missile{owner_id: owner_id, position: missile_position} =
            get_missile(battle, missile_id)

          %Ship{position: ship_position} = get_ship(battle, ship_id)
          owner_id != ship_id && distance(missile_position, ship_position) < @ship_size
        end)
      end)
      |> Enum.uniq()

    %Battle{battle | collisions: collisions}
  end

  def clear_fired_missiles_from_ships(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> %Ship{ship | missiles_ready: []} end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end


  def spawn_ships_into_battle(%Battle{ships_by_id: ships_by_id} = battle) do

    map_fun = fn
      %Ship{spawn_counter: 0, playing: false} = ship -> Ship.spawn(ship)
      ship -> ship
    end

    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def update_ships(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> Ship.update(ship) end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def update_missiles(%Battle{missiles_by_id: missiles_by_id} = battle) do
    map_fun = fn %Missile{} = missile -> Missile.update(missile) end
    %Battle{battle | missiles_by_id: missiles_by_id |> MapEnum.map(map_fun)}
  end

  def advance_stardate(%Battle{stardate: stardate} = battle) do
    %Battle{battle | stardate: stardate + 1}
  end

  def distribute_commands_to_ships(%Battle{ships_by_id: ships_by_id} = battle, commands_by_id) do
    #    IO.inspect("cid: #{inspect(commands_by_id)}")

    map_fun = fn %Ship{id: id} = ship ->
      %CommandSet{commands: commands, error: error} =
        Map.get(commands_by_id, id, %CommandSet{error: :missing_ai})

      fresh_helm = Ship.clear_commands(ship, error)

      commands
      |> Enum.reduce(fresh_helm, fn command, ship_acc ->
        ship_acc |> Ship.perform_command(command)
      end)
    end

    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end


  def distribute_ai_states_to_ships(%Battle{ships_by_id: ships_by_id} = battle, ai_states_by_id) do
    #    IO.inspect("cid: #{inspect(commands_by_id)}")

    ships_with_updated_ais =
    ai_states_by_id
    |> Map.to_list()
    |> Enum.reduce(ships_by_id, fn {id, ai_state}, ships_by_id_acc ->
      ship = Map.get(ships_by_id, id)
      Map.put(ships_by_id_acc, id, %Ship{ship | ai_state: ai_state})
    end)

    %Battle{battle | ships_by_id: ships_with_updated_ais}
  end


  def render_scanner(%Battle{missile_ids_by_spatial_hash: missile_ids_by_spatial_hash, ship_ids_by_spatial_hash: ship_ids_by_spatial_hash} = battle, %Ship{position: position, scanning_power: scanning_power} = ship) do

    scanning_hashes = get_spatial_hashes(position, scanning_power)

    ships =
    scanning_hashes
    |> Enum.flat_map(fn spatial_hash -> Map.get(ship_ids_by_spatial_hash, spatial_hash, []) end)
    |> Enum.uniq()
    |> Enum.map(fn id -> get_ship(battle, id) end)
    |> Enum.filter(fn %Ship{} = target_ship -> ship != target_ship && Ship.can_see(ship, target_ship) end)
    |> Enum.map(fn ship -> Ship.display(ship, position) end)

    missiles =
      scanning_hashes
      |> Enum.flat_map(fn spatial_hash -> Map.get(missile_ids_by_spatial_hash, spatial_hash, []) end)
      |> Enum.uniq()
      |> Enum.map(fn id -> get_missile(battle, id) end)
      |> Enum.filter(fn %Missile{} = missile -> Ship.can_see(ship, missile) end)
      |> Enum.map(fn missile -> Missile.display(missile,  position) end)

    %Ship{ship | display: %{missiles: missiles, ships: ships}}

  end

  def render_scanners(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> Battle.render_scanner(battle, ship) end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def render_messages(%Battle{messages: messages, ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> Ship.render_messages(ship, messages) end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def generate_commands(%Battle{base_ai: base_ai, ships_by_id: ships_by_id} = battle) do
    # returns map of ship_id to command_list
    default_failures =
      ships_by_id
      |> MapEnum.map(fn %Ship{id: id} = ship -> %CommandSet{id: id, error: :ai_timeout} end)

    #    commands_by_id =
    #    Parallel.map(ships_by_id |> Map.values(), fn %Ship{} = ship -> Ship.generate_commands(ship, base_ai) end)
    #    map_fun = fn %Ship{} = ship -> Ship.generate_commands(ship, base_ai) end
    #    commands_by_id = MapEnum.pmap(ships_by_id, map_fun)
    #    IO.inspect("xid: #{inspect(commands_by_id)}")
    commands_by_id =
      Task.Supervisor.async_stream_nolink(
        Warzone.SandboxTaskSupervisor,
        ships_by_id |> Map.values(),
        fn %Ship{} = ship ->
          Ship.generate_commands(ship, base_ai)
        end,
        ordered: false
      )
      |> Enum.filter(fn task_response -> match?({:ok, _}, task_response) end)
      |> Enum.map(fn {:ok, %CommandSet{id: id} = command_set} -> {id, command_set} end)
      |> Map.new()

#    IO.inspect(Task.Supervisor.children(Warzone.SandboxTaskSupervisor))

    all_commands_by_id = Map.merge(default_failures, commands_by_id)

#    IO.inspect("commands:\n#{inspect(all_commands_by_id)}")
    {:commands_by_id, all_commands_by_id}
  end


  def compile_code(%Battle{base_ai: base_ai, ships_by_id: ships_by_id} = battle) do

    ships_with_new_code =
    ships_by_id
    |> Map.values()
    |> Enum.filter(fn %Ship{ai_state: ai_state, code: code} -> ai_state == nil && is_binary(code) end)

    ai_states_by_id =
      Task.Supervisor.async_stream_nolink(
        Warzone.SandboxTaskSupervisor,
        ships_with_new_code,
        fn %Ship{id: id, code: code} = ship ->
          chunk = Sandbox.chunk(base_ai, code)
          {id, chunk}
        end,
        shutdown: 1000,
        on_timeout: :kill_task,
        ordered: false
      )
      |> Enum.filter(fn task_response -> match?({:ok, _}, task_response) end)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Map.new()

    {:ai_states_by_id, ai_states_by_id}
  end

#  def submit_code(%Battle{base_ai: base_ai} = battle, id, code) do
#    chunk = Sandbox.chunk(base_ai, code)
#    {:submitted_code, id, code, chunk}
#  end

  def submit_code(%Battle{} = battle, id, code) do
    ship = get_ship(battle, id)
    case ship do
      nil -> battle # join(battle, id) |> submit_code(id, code)
      _ -> put_ship(battle, %Ship{ship | code: code, ai_state: nil})
    end
#    ship = %Ship{get_ship(battle, id) | code: code, ai_state: nil}
#    IO.puts("update code: #{inspect(id)} ")
#    battle |> put_ship(ship)
  end

  def submit_name(%Battle{} = battle, id, name) do
    ship = %Ship{get_ship(battle, id) | name: name}
    battle |> put_ship(ship)
  end

  def get_ship(%Battle{ships_by_id: ships_by_id}, id) do
    Map.get(ships_by_id, id)
  end

  def get_missile(%Battle{missiles_by_id: missiles_by_id}, id) do
    Map.get(missiles_by_id, id)
  end

  def put_ship(%Battle{ships_by_id: ships_by_id} = battle, %Ship{id: id} = ship) do
    %Battle{battle | ships_by_id: Map.put(ships_by_id, id, ship)}
  end

  def put_missile(%Battle{missiles_by_id: missiles_by_id} = battle, %Missile{id: id} = missile) do
    %Battle{battle | missiles_by_id: Map.put(missiles_by_id, id, missile)}
  end

  def put_message(%Battle{messages: messages} = battle, message) do
    %Battle{battle | messages: [message | messages]}
  end
#
#  def add_missile(
#        %Battle{missiles_by_id: missiles_by_id, id_counter: id_counter} = battle,
#        %Missile{} = missile
#      ) do
#    battle
#    |> put_missile(%Missile{missile | id: id_counter, display_id: "missile_" <> to_string(id_counter)})
#    |> advance_counter()
#  end
end
