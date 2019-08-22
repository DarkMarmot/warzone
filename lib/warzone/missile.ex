defmodule Warzone.Missile do
  alias Warzone.Missile
  defstruct id: 0,
            power: 0,
            velocity: [0, 0],
            position: [0, 0],
            age: 0,
            owner_id: nil,
            destroyed: false

  def update(%Missile{} = missile) do
    missile
    |> age()
    |> move()
  end

  def age(%Missile{age: age} = missile) do
    %Missile{missile | age: age + 1, destroyed: age < 50}
  end

  def move(%Missile{velocity: [vx, vy], position: [px, py]} = missile) do
    %Missile{missile | position: [px + vx, py + vy]}
  end


end
