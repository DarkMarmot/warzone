defmodule Warzone.Battle do
  alias Warzone.{Battle, Ship, Missile, Cache, CommandSet, Collision, MapEnum}

  @realm_size 10000
  @missile_size 0
  @ship_size 100
  @hash_size 1000

  # cloak = -power * 500
  # scan = power * 500 + 2000
  # damage = power * 5, cost = (power + 1) * 5 -- speed 200, duration 25 ticks
  # thrust = power, max speed = 100

  defstruct base_ai: nil, ships_by_id: %{}, missiles_by_id: %{}, ship_ids_by_spatial_hash: %{}, missile_ids_by_spatial_hash: %{}, collisions: [], commands_by_id: %{}, stardate: 0, id_counter: 0

  def join(%Battle{ships_by_id: ships_by_id} = battle, id) do
    put_ship(battle, %Ship{id: id, position: get_spawn_position()})
  end

  def leave(%Battle{ships_by_id: ships_by_id} = battle, id) do
    %Battle{battle | ships_by_id: Map.delete(ships_by_id, id)
    }
  end

  def get_spawn_position() do
    # todo random
    [0, 0]
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
    |> render_scanner_views()
#    |> helm_ships()
#   |> asteroid_damage() for things beyond bounds
#   |> report_back()
  end

  def spawn_fired_missiles_into_battle(%Battle{ships_by_id: ships_by_id, missiles_by_id: missiles_by_id} = battle) do

    missiles_ready =
      ships_by_id
      |> Enum.flat_map(fn {id, %Ship{missiles_ready: missiles_ready}} -> missiles_ready end)
      |> Enum.map(fn %Missile{id: id} = missile -> {id, missile} end)
      |> Map.new()

    %Battle{battle | missiles_by_id: missiles_by_id |> Map.merge(missiles_ready)}
  end

  def destroy_missiles(%Battle{missiles_by_id: missiles_by_id} = battle) do
    filter_fun = fn %Missile{destroyed: destroyed} -> !destroyed end
    %Battle{battle | missiles_by_id: missiles_by_id |> MapEnum.filter(filter_fun)}
  end

  def resolve_collisions(
        %Battle{collisions: collisions, ships_by_id: ships_by_id, missiles_by_id: missiles_by_id} =
          battle
      ) do
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
    |> Enum.flat_map(fn {id, %Ship{position: position}} ->
      hashes = get_spatial_hashes(position, @ship_size)
      hashes |> Enum.map(fn hash -> {hash, id} end)
    end)
    |> Enum.group_by(fn {hash, _id} -> hash end, fn {_hash, id} -> id end)
  end

  def get_missile_ids_by_spatial_hash(%Battle{missiles_by_id: missiles_by_id}) do
    missiles_by_id
    |> Map.to_list()
    |> Enum.flat_map(fn id, %Missile{position: position} ->
      get_spatial_hashes(position, @missile_size) |> Enum.map(&{&1, id})
    end)
    |> Enum.group_by(fn {hash, _id} -> hash end, fn {_hash, id} -> id end)
  end

  def generate_spatial_hashes(%Battle{} = battle) do
    %Battle{battle |
      ship_ids_by_spatial_hash: get_ship_ids_by_spatial_hash(battle),
      missile_ids_by_spatial_hash: get_missile_ids_by_spatial_hash(battle)
    }
  end

  def determine_collisions(
        %Battle{ship_ids_by_spatial_hash: ship_ids_by_spatial_hash,
missile_ids_by_spatial_hash: missile_ids_by_spatial_hash,
          ships_by_id: ships_by_id, missiles_by_id: missiles_by_id} = battle
      ) do

    hash_collisions =
      ship_ids_by_spatial_hash
      |> Map.keys()
      |> Enum.filter(fn hash -> Map.has_key?(missile_ids_by_spatial_hash, hash) end)
      |> Enum.uniq()

    collisions =
      hash_collisions
      |> Enum.map(fn hash ->
        missile_ids = Map.get(missile_ids_by_spatial_hash, hash)
        ship_ids = Map.get(ship_ids_by_spatial_hash, hash)

        missile_ids
        |> Enum.flat_map(fn missile_id ->
          Enum.map(ship_ids, fn ship_id ->
            %Collision{missile_id: missile_id, ship_id: ship_id}
          end)
        end)
        |> Enum.filter(fn %Collision{missile_id: missile_id, ship_id: ship_id} ->
          %Missile{owner_id: owner_id, position: missile_position} = get_missile(battle, missile_id)
          %Ship{position: ship_position} = get_ship(battle, ship_id)
          owner_id != ship_id && distance(missile_position, ship_position) < @ship_size
        end)
      end)

    %Battle{battle | collisions: collisions}
  end

  def clear_fired_missiles_from_ships(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> %Ship{ship | missiles_ready: []} end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

#  def perform_commands(%Battle{ships_by_id: ships_by_id} = battle) do
#    map_fun = fn %Ship{} = ship ->
#      Ship.perform_commands(ship, battle) end
#    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
#  end

#  def clear_commands(%Battle{ships_by_id: ships_by_id} = battle) do
#    map_fun = fn %Ship{} = ship -> %Ship{ship | commands: []} end
#    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
#  end

  def spawn_ships_into_battle(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn
      %Ship{spawn_counter: 0, playing: false} = ship -> %Ship{ship | playing: true}
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
      %CommandSet{commands: commands, error: error} = Map.get(commands_by_id, id, %CommandSet{error: :missing_ai})
      fresh_helm = Ship.clear_commands(ship, error)
      commands
      |> Enum.reduce(fresh_helm, fn command, ship_acc ->
        ship_acc |> Ship.perform_command(command)
      end)
    end

    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def render_scanner_view(%Battle{} = battle, %Ship{} = ship) do
    ship
  end

  def render_scanner_views(%Battle{ships_by_id: ships_by_id} = battle) do
    map_fun = fn %Ship{} = ship -> Battle.render_scanner_view(battle, ship) end
    %Battle{battle | ships_by_id: ships_by_id |> MapEnum.map(map_fun)}
  end

  def generate_commands(%Battle{base_ai: base_ai, ships_by_id: ships_by_id} = battle) do

      # returns map of ship_id to command_list
    default_failures = ships_by_id |> MapEnum.map(fn %Ship{id: id} = ship -> %CommandSet{id: id, error: :ai_timeout} end)
    commands_by_id =
      Task.Supervisor.async_stream_nolink(Warzone.TaskSupervisor,
      ships_by_id |> Map.values(),
      fn %Ship{} = ship ->
        Ship.generate_commands(ship, base_ai)
      end,
      ordered: false,
      timeout: 500,
      on_timeout: :kill_task)
    |> Enum.filter(fn task_response -> match?({:ok, _}, task_response) end)
    |> Enum.map(fn {:ok, %CommandSet{id: id} = command_set} -> {id, command_set} end)
    |> Map.new()

    IO.inspect("commands:\n#{inspect(commands_by_id)}")
    {:commands_by_id, commands_by_id}

  end

  def submit_code(%Battle{base_ai: base_ai} = battle, id, code) do
    chunk = Sandbox.chunk(base_ai, code)
    {:submitted_code, id, code, chunk}
  end

  def update_code(%Battle{} = battle, id, code, ai_state) do
    ship = %Ship{get_ship(battle, id) | code: code, ai_state: ai_state}
    IO.puts("update code: #{inspect(id)} ")
    battle |> put_ship(ship)
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

  def add_missile(
        %Battle{missiles_by_id: missiles_by_id, id_counter: id_counter} = battle,
        %Missile{} = missile
      ) do
    battle
    |> put_missile(%Missile{missile | id: id_counter})
    |> Map.put(:id_counter, id_counter + 1)
  end
  
end
