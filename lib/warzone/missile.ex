defmodule Warzone.Missile do
  alias Warzone.Missile
  defstruct id: 0,
            display_id: nil,
            power: 0,
            velocity: [0, 0],
            facing: 0,
            position: [0, 0],
            age: 0,
            owner_id: nil,
            destroyed: false

  def display(%Missile{display_id: display_id, position: [x, y], facing: facing}, [ship_x, ship_y]) do
    %{
      display_id: display_id,
      x: x - ship_x,
      y: y - ship_y,
      facing: facing
    }
  end

  def update(%Missile{} = missile) do
    missile
    |> age()
    |> move()
  end

  def age(%Missile{age: age, power: power} = missile) do
    %Missile{missile | age: age + 1, destroyed: age >= power * 50}
  end

  def move(%Missile{velocity: [vx, vy], position: [px, py]} = missile) do
    %Missile{missile | position: [px + vx, py + vy]}
  end


end
