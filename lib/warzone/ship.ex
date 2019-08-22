# to lua: ship (self), scan (ships, missiles, clock, range), clock

defmodule Warzone.Ship do
  alias Warzone.{Ship, Battle, Command, CommandSet, Missile}

  @deg_to_radians :math.pi() / 180.0
  @max_energy 100
  @max_hull 100
  # is 10 per input
  @recharge_rate 2
  @drag_coef 0.9
  @missile_speed 30

  defstruct id: nil,
            display_id: nil,
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
            speed: 0,
            position: [0, 0],
            cloaking_power: 0,
            scanning_power: 0,
            thrust: [0, 0],
            thrust_dir: 0,
            thrust_mag: 0,
            facing: 0,
            display: %{ships: [], missiles: []},
            ai_state: nil,
            ai_error: nil

  def display(%Ship{display_id: display_id, position: position, facing: facing}) do
    %{
      display_id: display_id,
      position: position,
      facing: facing
    }
  end

  def generate_commands(%Ship{id: id, ai_state: nil}, _base_ai) do
    %CommandSet{id: id, error: :no_ai}
  end

  def generate_commands(%Ship{id: id, ai_state: {:error, _ai_reason}}, _base_ai) do
    %CommandSet{id: id, error: :ai_could_not_compile}
  end

  def generate_commands(
        %Ship{
          id: id,
          ai_state: {:ok, ai_chunk},
          speed: speed,
          position: [px, py],
          energy: energy,
          hull: hull,
          age: age,
          facing: facing,
          display: display
        } = ship,
        base_ai
      ) do

    ai_play_result =
      base_ai
      |> Sandbox.set!("status", %{
        x: px,
        y: py,
        facing: facing,
        speed: speed,
        energy: energy,
        hull: hull,
        age: age,
        view: display
      })
      |> Sandbox.play(ai_chunk, 1_000_000)


    #      |> Sandbox.moo(ai_chunk)

    case ai_play_result do
      {:error, {:reductions, _}} ->
        %CommandSet{id: id, error: :ai_timeout_error}

      {:error, _reason} ->
        %CommandSet{id: id, error: :ai_runtime_error}

      {:ok, lua_state} ->
        commands = lua_state |> Sandbox.get!("commands") |> parse_lua_commands()
        %CommandSet{id: id, commands: commands}
    end
  end

  def parse_lua_commands(commands) do
    commands
    |> Map.new()
    |> Map.values()
    |> Enum.map(&Map.new/1)
    |> Enum.map(fn m -> %Command{name: Map.get(m, "name"), param: Map.get(m, "param")} end)
  end

  def update(%Ship{id: id} = ship) do
#    IO.puts(
#      "energy: #{inspect(ship.energy)} velocity: #{inspect(trunc(ship.velocity |> Enum.at(0)))} #{
#        inspect(trunc(ship.velocity |> Enum.at(1)))
#      } position: #{inspect(trunc(ship.position |> Enum.at(0)))}  #{
#        inspect(trunc(ship.position |> Enum.at(1)))
#      } #{inspect(ship.age)}"
#    )

#    IO.puts("send: #{inspect(id)} #{inspect(ship.age)}")
    Process.send(id, {:ship_status, ship}, [])

    ship
    |> count()
    |> move()
    |> recharge()
  end

  def clear_commands(%Ship{} = ship, error) do
    %Ship{
      ship
      | ai_error: error,
        commands: [],
        thrust: [0, 0],
        scanning_power: 0,
        cloaking_power: 0
    }
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
    speed = :math.sqrt(new_vx * new_vx + new_vy * new_vy)
    %Ship{ship | speed: speed, velocity: [new_vx, new_vy], position: [px + new_vx, py + new_vy]}
  end

  def recharge(%Ship{energy: energy} = ship) do
    %Ship{ship | energy: min(energy + @recharge_rate, @max_energy)}
  end

  # commands

  #  def thrust(%Ship{velocity: [vx, vy], thrust: [tx, ty], energy: energy, commands: commands} = ship, %Command{name: "thrust", power: power, angle: angle} = command) do
  #    # multiple small thrusts can be added together in one command set
  #    if power <= energy do
  #      radians = @deg_to_radians * angle
  #      new_tx = tx + :math.cos(radians) * power
  #      new_ty = ty + :math.sin(radians) * power
  #      %Ship{ship | energy: energy - power, thrust: [new_tx, new_ty], commands: [command | commands]}
  #    else
  #      ship |> Ship.not_enough_energy(command)
  #    end
  #  end
  #
  #  def face(%Ship{commands: commands} = ship, %Command{name: "face", power: power} = command) do
  #    if power <= energy do
  #      %Ship{ship | energy: energy - power, scanning_power: power * 500 + 2000, commands: [command | commands]}
  #    else
  #      ship |> Ship.not_enough_energy(command)
  #    end
  #  end
  #
  #  def scan(%Ship{energy: energy, commands: commands} = ship, %Command{name: "scan", power: power} = command) do
  #    if power <= energy do
  #      %Ship{ship | energy: energy - power, scanning_power: power * 500 + 2000, commands: [command | commands]}
  #    else
  #      ship |> Ship.not_enough_energy(command)
  #    end
  #  end
  #
  #  def cloak(%Ship{energy: energy, commands: commands} = ship, %Command{name: "cloak", power: power} = command) do
  #    if power <= energy do
  #      %Ship{ship | energy: energy - power, cloaking_power: power * 500, commands: [command | commands]}
  #    else
  #      ship |> Ship.not_enough_energy(command)
  #    end
  #  end
  #
  #  def fire(%Ship{id: id, energy: energy, commands: commands, missile_counter: missile_counter, missiles_ready: missiles_ready, position: position} = ship, %Command{name: "fire", power: power, angle: angle} = command) do
  #    if (power > 2 && power <= energy) do
  #      radians = @deg_to_radians * angle
  #      vx = :math.cos(radians) * @missile_speed
  #      vy = :math.sin(radians) * @missile_speed
  #      missile = %Missile{id: {id, missile_counter}, owner_id: id, power: power - 2, velocity: [vx, vy], position: position}
  #      %Ship{ship |energy: energy - power,  missiles_ready: [missile | missiles_ready], commands: [command | commands]}
  #    else
  #      ship |> Ship.not_enough_energy(command)
  #    end
  #  end

  def perform_command(
        %Ship{
          facing: facing,
          energy: energy,
          commands: commands,
          thrust: [tx, ty]
        } = ship,
        %Command{name: "thrust", param: power} = command
      )
      when is_number(power) do
    if power <= energy do
      radians = @deg_to_radians * facing
      new_tx = tx + :math.cos(radians) * power
      new_ty = ty + :math.sin(radians) * power

      %Ship{
        ship
        | energy: energy - power,
          thrust: [new_tx, new_ty],
          commands: [command | commands]
      }
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def perform_command(
        %Ship{
          id: id,
          facing: facing,
          position: position,
          energy: energy,
          commands: commands,
          missiles_ready: missiles_ready,
          missile_counter: missile_counter,
          display_id: display_id
        } = ship,
        %Command{name: "fire", param: power} = command
      )
      when is_number(power) do
    if power > 2 && power <= energy do
      radians = @deg_to_radians * facing
      vx = :math.cos(radians) * @missile_speed
      vy = :math.sin(radians) * @missile_speed

      missile = %Missile{
        id: {id, missile_counter},
        display_id: to_string(display_id) <> "_" <> to_string(missile_counter),
        owner_id: id,
        power: power - 2,
        velocity: [vx, vy],
        position: position,
        facing: facing
      }

      %Ship{
        ship
        | energy: energy - power,
          missiles_ready: [missile | missiles_ready],
          commands: [command | commands],
          missile_counter: missile_counter + 1
      }
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def perform_command(
        %Ship{facing: facing, commands: commands} = ship,
        %Command{name: "face", param: angle} = command
      )
      when is_number(angle) do
    %Ship{ship | facing: angle, commands: [command | commands]}
  end

  def keep_angle_between_0_and_360(angle) do
    angle -  :math.floor(angle/360) * 360
  end

  def perform_command(
        %Ship{facing: facing, commands: commands} = ship,
        %Command{name: "turn", param: angle} = command
      )
      when is_number(angle) do

    %Ship{ship | facing: keep_angle_between_0_and_360(facing + angle), commands: [command | commands]}
  end

  def perform_command(
        %Ship{energy: energy, commands: commands} = ship,
        %Command{name: "cloak", param: power} = command
      )
      when is_number(power) do
    if power <= energy do
      %Ship{
        ship
        | energy: energy - power,
          cloaking_power: power,
          commands: [command | commands]
      }
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def perform_command(
        %Ship{energy: energy, commands: commands} = ship,
        %Command{name: "scan", param: power} = command
      )
      when is_number(power) do
    if power <= energy do
      %Ship{
        ship
        | energy: energy - power,
          scanning_power: power,
          commands: [command | commands]
      }
    else
      ship |> Ship.not_enough_energy(command)
    end
  end

  def perform_command(%Ship{} = ship, %Command{} = _command) do
    IO.puts("unknown cmd")
    ship
  end
end
