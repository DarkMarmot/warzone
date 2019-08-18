# to lua: ship (self), scan (ships, missiles, clock, range), clock

defmodule Warzone.Ship do
  alias Warzone.{Ship, Battle, Command, Missile}

  @deg_to_radians :math.pi() / 180.0
  @max_energy 100
  @max_hull 100
  @recharge_rate 1
  @drag_coef 0.85
  @missile_speed 30

  defstruct id: nil,
            name: nil,
            code: nil,
            playing: false,
            commands: [],
            spawn_counter: 30,
            missile_counter: 0,
            missiles_ready: [],
            kills: 0,
            deaths: 0,
            age: 0,
            messages: [],
            hull: @max_hull,
            energy: @max_energy,
            velocity: [0, 0],
            position: [0, 0],
            cloaking_power: 0,
            scanning_power: 0,
            thrust: [0, 0],
            view: nil,
            ai_state: nil

  def generate_commands(%Ship{ai_state: nil}, base_ai) do
    []
  end

  def generate_commands(%Ship{ai_state: {:ok, ai_chunk}, velocity: [vx, vy], position: [px, py], energy: energy, hull: hull} = ship, base_ai) do
    base_ai
    |> Sandbox.set!("status", %{velocity: %{x: vx, y: vy}, position: %{x: px, y: py}, energy: energy, hull: hull})
    |> Sandbox.play!(ai_chunk)
    |> Sandbox.get!("commands")
    |> parse_lua_commands()
    |> IO.inspect()
  end

  def parse_lua_commands(commands) do
#    [{1, [{"angle", 0.0}, {"name", "thrust"}, {"power", 3.0}]}]
    commands
    |> Map.new()
    |> Map.values()
    |> Enum.map(&Map.new/1)
    |> Enum.map(fn m -> %Command{name: Map.get(m, "name"), angle: Map.get(m, "angle"), power: Map.get(m, "power")} end)

  end

  def update(%Ship{} = ship) do
    ship
    |> count()
    |> move()
    |> recharge()
  end

  def clear_commands(%Ship{} = ship) do
    %Ship{ship | commands: [], thrust: [0, 0], scanning_power: 0, cloaking_power: 0}
  end

  def perform_command(%Ship{energy: energy, commands: commands} = ship, %Command{name: name, power: power} = command) do

      case name do
        "fire" -> fire(ship, command)
        "thrust" -> thrust(ship, command)
        "cloak" -> cloak(ship, command)
        "scan" -> scan(ship, command)
        _ -> ship
      end

  end

  def not_enough_energy(%Ship{energy: energy, commands: commands} = ship, %Command{} = command) do
    %Ship{ship | commands: [%Command{command | error: "not enough energy"} | commands]}
  end

  def count(%Ship{playing: true, age: age} = ship) do
    %Ship{ship | age: age + 1}
  end

  def count(%Ship{playing: false, spawn_counter: spawn_counter} = ship) do
    %Ship{ship | spawn_counter: spawn_counter - 1}
  end

  def move(%Ship{energy: energy, velocity: [vx, vy], position: [px, py], thrust: [tx, ty]} = ship) do
    new_vx = (vx + tx / 10) * @drag_coef
    new_vy = (vy + ty / 10) * @drag_coef
    %Ship{ship | velocity: [new_vx, new_vy], position: [px + new_vx, py + new_vy]}
  end

  def recharge(%Ship{energy: energy} = ship) do
    %Ship{ship | energy: min(energy + @recharge_rate, @max_energy)}
  end

  # commands

  def thrust(%Ship{velocity: [vx, vy], thrust: [tx, ty], energy: energy, commands: commands} = ship, %Command{name: "thrust", power: power, angle: angle} = command) do
    # multiple small thrusts can be added together in one command set
    if power <= energy do
      radians = @deg_to_radians * angle
      new_tx = tx + :math.cos(radians) * power
      new_ty = ty + :math.sin(radians) * power
      %Ship{ship | energy: energy - power, thrust: [new_tx, new_ty], commands: [command | commands]}
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def scan(%Ship{energy: energy, commands: commands} = ship, %Command{name: "scan", power: power} = command) do
    if power <= energy do
      %Ship{ship | energy: energy - power, scanning_power: power * 500 + 2000, commands: [command | commands]}
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def cloak(%Ship{energy: energy, commands: commands} = ship, %Command{name: "cloak", power: power} = command) do
    if power <= energy do
      %Ship{ship | energy: energy - power, cloaking_power: power * 500, commands: [command | commands]}
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def fire(%Ship{id: id, energy: energy, commands: commands, missile_counter: missile_counter, missiles_ready: missiles_ready, position: position} = ship, %Command{name: "fire", power: power, angle: angle} = command) do
    if (power > 2 && power <= energy) do
      radians = @deg_to_radians * angle
      vx = :math.cos(radians) * @missile_speed
      vy = :math.sin(radians) * @missile_speed
      missile = %Missile{id: {id, missile_counter}, owner_id: id, power: power - 2, velocity: [vx, vy], position: position}
      %Ship{ship |energy: energy - power,  missiles_ready: [missile | missiles_ready], commands: [command | commands]}
    else
      ship |> Ship.not_enough_energy(command)
    end
  end


end
