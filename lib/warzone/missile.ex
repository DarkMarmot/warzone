defmodule Warzone.Missile do
  alias Warzone.Missile

  @deg_to_radians :math.pi() / 180.0
  @radians_to_deg 1.0 / @deg_to_radians

  defstruct id: 0,
            display_id: nil,
            power: 0,
            velocity: [0, 0],
            facing: 0,
            position: [0, 0],
            age: 0,
            owner_id: nil,
            destroyed: false,
            color: 0

  def display(
        %Missile{
          display_id: display_id,
          position: [x, y],
          facing: facing,
          power: power,
          color: color
        },
        [ship_x, ship_y]
      ) do

    dx = x - ship_x
    dy = y - ship_y

    %{
      name: display_id,
      x: dx,
      y: dy,
      heading: facing,
      power: power,
      color: color,
      direction: (:math.atan2(dy, dx) * @radians_to_deg) |> keep_angle_between_0_and_360(),
      distance: :math.sqrt(dx * dx + dy * dy)
    }
  end

  def keep_angle_between_0_and_360(angle) do
    angle - :math.floor(angle / 360) * 360
  end

  def update(%Missile{} = missile) do
    missile
    |> age()
    |> move()
  end

  def age(%Missile{age: age, power: power} = missile) do
    %Missile{missile | age: age + 1, destroyed: age >= power * 10}
  end

  def move(%Missile{velocity: [vx, vy], position: [px, py]} = missile) do
    %Missile{missile | position: [px + vx, py + vy]}
  end
end
