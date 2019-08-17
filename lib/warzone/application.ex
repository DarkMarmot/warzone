defmodule Warzone.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    IO.puts("app start!")

    children = [
      {Warzone.Cache, []},
      {Task.Supervisor, name: Warzone.TaskSupervisor},
      {Warzone.BattleServer, []}
    ]

    opts = [strategy: :one_for_one, name: Warzone.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
