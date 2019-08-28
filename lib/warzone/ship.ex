# to lua: ship (self), scan (ships, missiles, clock, range), clock

defmodule Warzone.Ship do
  alias Warzone.{Ship, Battle, Command, CommandSet, Missile}

  @deg_to_radians :math.pi() / 180.0
  @radians_to_deg 1.0 / @deg_to_radians
  @max_energy 100
  @max_hull 100
  # is 10 per input
  @recharge_rate 4
  @missile_speed 5
  @default_scanning_range 150
  @power_to_speed_factor 0.2
  @power_to_cloaking_factor 1
  @power_to_scanning_factor 1


  defstruct id: nil,
            display_id: nil,
            missile_color: nil,
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
            scanning_power: @default_scanning_range,
            heading: 0,
            facing: 0,
            display: %{ships: [], missiles: []},
            ai_state: nil,
            ai_error: nil,
            stardate: 0

  def spawn(%Ship{} = ship) do
    range = 200 + :random.uniform() * 300
    angle = :rand.uniform() * :math.pi() * 2
    x = :math.cos(angle) * range
    y = :math.sin(angle) * range
    %Ship{ship | spawn_counter: 30, playing: true, hull: 100, energy: 100, position: [x, y]}
  end

  def apply_damage(%Ship{hull: hull} = ship, damage) do
    case damage >= hull do
      true ->
        IO.puts("BOOM!")
        %Ship{ship | spawn_counter: 30, playing: false}
      false -> %Ship{ship | hull: hull - damage}
    end
  end

  def can_see(%Ship{position: p1, scanning_power: scanning_power} , %Ship{position: p2, cloaking_power: cloaking_power}) do
    Battle.distance(p1, p2) - scanning_power + cloaking_power < 0
  end

  def can_see(%Ship{position: p1, scanning_power: scanning_power} = ship, %Missile{position: p2}) do
    Battle.distance(p1, p2) - scanning_power < 0
  end

  def display(%Ship{name: name, position: [x, y]}, [ship_x, ship_y]) do
    dx = x - ship_x
    dy = y - ship_y
    %{
      name: name,
      x: dx,
      y: dy,
      direction: :math.atan2(dy, dx) * @radians_to_deg |> keep_angle_between_0_and_360(),
      distance: :math.sqrt(dx * dx + dy * dy)
    }
  end

  def render_messages(%Ship{messages: messages, name: name} = ship, new_messages) do

    new_rendered_messages =
      new_messages
    |> Enum.map(fn message ->
      m = message.content
      text =
      cond do
        m.kill && m.attacker == name -> "You destroyed " <> m.defender <> "!!!"
        m.attacker == name -> "You struck " <> m.defender <> " for " <> to_string(m.damage) <> " hull damage."
        m.kill && m.defender == name -> m.attacker <> " has utterly destroyed you!"
        m.defender == name -> m.attacker <> " blasts you for " <> to_string(m.damage) <> " hull damage."
        true -> nil
      end

      %{stardate: message.created_at, text: text}
    end)
    |> Enum.reject(fn m -> m.text == nil end)

    resulting_messages = (new_rendered_messages ++ messages) |> Enum.take(10)
    %Ship{ship | messages: resulting_messages}
  end



  def generate_commands(%Ship{id: id, ai_state: nil}, _base_ai) do
    %CommandSet{id: id, error: :missing_ai}
  end

  def generate_commands(%Ship{id: id, ai_state: {:error, _ai_reason}}, _base_ai) do
    %CommandSet{id: id, error: :ai_could_not_compile}
  end

  def generate_commands(%Ship{id: id, playing: false}, _base_ai) do
    %CommandSet{id: id, error: :ai_ready}
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
        age: trunc(age/5),
        ships: display.ships,
        missiles: display.missiles
      })
      |> Sandbox.play_function!(["math", "randomseed"], age, 1_000_000)
      |> Sandbox.play(ai_chunk, 1_000_000)


    #      |> Sandbox.moo(ai_chunk)

    case ai_play_result do
      {:error, {:reductions, _}} ->
        %CommandSet{id: id, error: :ai_timeout_error}

      {:error, _reason} ->
        %CommandSet{id: id, error: :ai_runtime_error}

      {:ok, lua_state} ->
        commands = lua_state |> Sandbox.get!("commands") |> parse_lua_commands()
        %CommandSet{id: id, commands: commands, error: :ai_engaged}
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
        velocity: [0, 0],
        speed: 0,
        scanning_power: @default_scanning_range,
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

  def move(%Ship{energy: energy, velocity: [vx, vy], position: [px, py]} = ship) do
    %Ship{ship | position: [px + vx, py + vy]}
  end

  def recharge(%Ship{energy: energy} = ship) do
    %Ship{ship | energy: min(energy + @recharge_rate, @max_energy)}
  end

  def perform_command(
        %Ship{
          facing: facing,
          energy: energy,
          commands: commands
        } = ship,
        %Command{name: "thrust", param: power} = command
      )
      when is_number(power) do

      power_used = max(Enum.min([power, energy, 10]), 0)

      speed = @power_to_speed_factor * power_used
      radians = @deg_to_radians * facing
      tx = :math.cos(radians) * speed
      ty = :math.sin(radians) * speed

      %Ship{
        ship
        | energy: energy - power_used,
          velocity: [tx, ty],
          speed: speed,
          heading: facing,
          commands: [command | commands]
      }

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
          missile_color: missile_color,
          display_id: display_id
        } = ship,
        %Command{name: "fire", param: power} = command
      )
      when is_number(power) do
     if power >= 1 do
       power_used = Enum.min([power, energy, 10])

       radians = @deg_to_radians * facing
      vx = :math.cos(radians) * @missile_speed
      vy = :math.sin(radians) * @missile_speed

      missile = %Missile{
        id: {id, missile_counter},
        display_id: to_string(display_id) <> "_" <> to_string(missile_counter),
        owner_id: id,
        power: power_used,
        velocity: [vx, vy],
        position: position,
        facing: facing,
        color: missile_color
      }

      %Ship{
        ship
        | energy: energy - power_used,
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

    power_used = max(Enum.min([power, energy, 10]), 0)


    %Ship{
        ship
        | energy: energy - power_used,
          cloaking_power: power_used * 50,
          commands: [command | commands]
      }

  end

  def perform_command(
        %Ship{energy: energy, commands: commands} = ship,
        %Command{name: "scan", param: power} = command
      )
      when is_number(power) do
    power_used = max(Enum.min([power, energy, 10]), 0)


    %Ship{
        ship
        | energy: energy - power_used,
          scanning_power: power_used * 50 + @default_scanning_range,
          commands: [command | commands]
      }

  end

  def perform_command(%Ship{} = ship, %Command{} = _command) do
    IO.puts("unknown cmd")
    ship
  end
end
