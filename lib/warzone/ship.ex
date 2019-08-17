# to lua: ship (self), scan (ships, missiles, clock, range), clock

defmodule Warzone.Ship do
  alias Warzone.{Ship, Battle}

  @deg_to_radians :math.pi() / 180.0
  @max_energy 100
  @max_hull 100
  @recharge_rate 10
  @drag_coef 0.9
  @repulsion_edge 1000

  defstruct id: nil,
            name: nil,
            code: nil,
            playing: false,
            commands: [],
            spawn_counter: 30,
            missiles_ready: [],
            kills: 0,
            deaths: 0,
            age: 0,
            messages: [],
            hull: @max_hull,
            energy: @max_energy,
            velocity: [0, 0],
            position: [0, 0],
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
    |> IO.inspect()
  end

  def update(%Ship{} = ship) do
    ship
    |> count()
    |> move()
    |> recharge()
  end

  def count(%Ship{playing: true, age: age} = ship) do
    %Ship{ship | age: age + 1}
  end

  def count(%Ship{playing: false, spawn_counter: spawn_counter} = ship) do
    %Ship{ship | spawn_counter: spawn_counter - 1}
  end

  def move(%Ship{energy: energy, velocity: [vx, vy], position: [px, py]} = ship) do
    new_vx = vx * @drag_coef
    new_vy = vy * @drag_coef
    %Ship{ship | velocity: [new_vx, new_vy], position: [px + new_vx, py + new_vy]}
  end

  def recharge(%Ship{energy: energy} = ship) do
    %Ship{ship | energy: min(energy + @recharge_rate, @max_energy)}
  end

  # commands

  def thrust(
        %Ship{velocity: [vx, vy]} = ship,
        power,
        direction_as_degrees
      ) do
    radians = @deg_to_radians * direction_as_degrees
    thrust_vx = :math.cos(radians) * power
    thrust_vy = :math.sin(radians) * power
    new_vx = vx + thrust_vx
    new_vy = vy + thrust_vy

    %Ship{
      ship
      | velocity: [new_vx, new_vy],
        thrust: [thrust_vx, thrust_vy]
    }
  end

  def scan(%Ship{} = ship) do
  end

  def cloak(%Ship{} = ship) do
  end

  def fire(%Ship{} = ship) do
  end

  #
  #  def update_script(%Ship{} = ship, state) do
  #    import SandBox
  #    state
  #    |> set("ship", ship)
  #  end
  #
  #  def tick(%Ship{} = ship) do
  #    ship
  ##    |> update_clock()
  #    |> recharge()
  #    |> clear_actions()
  #    |> process_commands()
  #  end
  #
  #  def clear_actions(%Ship{} = ship) do
  #    Map.put(ship, :actions, [])
  #  end

  #  def generate_actions(%Ship{commands: commands} = ship) when is_list(commands) do
  #    commands
  #    |> Enum.map(fn {k, v} -> to_action(name, args) end)
  #
  #  end

  # joins all params into action sets for firing multiple missiles, returns list of maps

  #  def process_commands(%Ship{commands: commands} = ship) do
  #
  #    Enum.reduce(commands, ship, fn
  #      ["thrust", power, direction], ship_acc when is_number(power) and is_number(direction) ->
  #        thrust(ship_acc, power, direction)
  #
  #      ["scan", power], ship_acc when is_number(power) ->
  #        scan(ship_acc, power)
  #
  ##      ["cloak", power], ship_acc when is_number(power) ->
  ##        cloak(ship_acc, power)
  #
  #      ["fire", damage, speed, duration, direction], ship_acc
  #      when is_number(damage) and is_number(speed) and is_number(duration) and
  #             is_number(direction) ->
  #        fire(ship_acc, damage, speed, duration, direction)
  #      _, ship_acc -> %Ship{ship_acc | actions: [:invalid_command | ship.actions]}
  #    end)
  #    |> Map.put(:commands, [])
  #  end
  #
  #  def scan(
  #        %Ship{energy: energy, velocity: [vx, vy], position: [px, py]} = ship,
  #        power
  #      ) do
  ##    power_used = min(power, energy)
  ##
  ##    if power_used > 0 do
  ##
  ##    %Ship{
  ##      ship
  ##    | velocity: [new_vx, new_vy],
  ##      position: [new_px, new_py],
  ##      energy: energy - power_used,
  ##      thrust: [thrust_vx, thrust_vy]
  ##    }
  ##    |> log_if(power_used < power, :partial_thrust)
  ##    else
  ##
  ##    end
  #  end
  #
  #  def thrust(
  #        %Ship{energy: energy, velocity: [vx, vy], position: [px, py]} = ship,
  #        power,
  #        direction_as_degrees
  #      ) do
  #    power_used = min(power, energy)
  #
  #    radians = @deg_to_radians * direction_as_degrees
  #    thrust_vx = :math.cos(radians) * power
  #    thrust_vy = :math.sin(radians) * power
  #    new_vx = thrust_vx + vx * @drag_coef
  #    new_vy = thrust_vy * power + vy * @drag_coef
  #    new_px = px + new_vx
  #    new_py = py + new_vy
  #
  #    %Ship{
  #      ship
  #      | velocity: [new_vx, new_vy],
  #        position: [new_px, new_py],
  #        energy: energy - power_used,
  #        thrust: [thrust_vx, thrust_vy]
  #    }
  #    |> log_if(power_used < power, :partial_thrust)
  #  end
  #
  #  def fire(
  #        %Ship{
  #          owner: owner,
  #          energy: energy,
  #          velocity: [vx, vy],
  #          position: position,
  #          actions: log,
  ##          missiles: missiles
  #        } = ship,
  #        damage,
  #        speed,
  #        duration,
  #        direction_as_degrees
  #      ) do
  #    power_needed = damage * (speed + 1) * (duration + 1)
  #    percent_available = if energy > 0, do: min(power_needed / energy, 1), else: 0
  #    damage_used = floor(damage * percent_available)
  #    power_used = damage_used * (speed + 1) * (duration + 1)
  #
  #    if power_used > 0 do
  #      radians = @deg_to_radians * direction_as_degrees
  #      new_vx = :math.cos(radians) * speed + vx
  #      new_vy = :math.sin(radians) * speed + vy
  #
  #      missile = %SandWar.Missile{
  #        owner: owner,
  #        position: position,
  #        velocity: [new_vx, new_vy],
  #        damage: damage_used,
  #        duration: duration
  #      }
  #
  #      %Ship{ship | energy: energy - power_used, actions: [missile | missiles]}
  #      |> log_if(power_used < power_needed, :partial_fire)
  #    else
  #      %Ship{ship | energy: 0, actions: [:misfire | log]}
  #    end
  #  end
  #
  #  def recharge(%Ship{energy: energy} = ship) do
  #    new_energy = min(energy + @recharge_rate, @max_energy)
  #    %Ship{ship | energy: new_energy}
  #  end
  #
  ##  def update_clock(%Ship{clock: clock} = ship) do
  ##    %Ship{ship | clock: clock + 1}
  ##  end
  #
  #  defp log_if(%Ship{actions: log} = ship, conditional, message) do
  #    case conditional do
  #      true -> %Ship{ship | actions: [message | log]}
  #      false -> ship
  #    end
  #  end
end
