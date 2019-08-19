defmodule Warzone.Missile do
  alias Warzone.Missile
  defstruct id: 0,
            power: 0,
            velocity: [0, 0],
            position: [0, 0],
            age: 0,
            owner_id: nil,
            destroyed: false

  def update(%Missile{age: age} = missile) do
    %Missile{missile | age: age + 1}
  end


end
