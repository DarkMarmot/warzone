defmodule Warzone.Missile do
  defstruct id: 0,
            power: 0,
            velocity: [0, 0],
            position: [0, 0],
            age: 0,
            owner_id: nil,
            destroyed: false

  def update() do
  end

end
