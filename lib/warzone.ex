defmodule Warzone do
  @moduledoc """
  Documentation for Warzone.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Warzone.hello()
      :world == Path.join(:code.priv_dir(:warzone), "data.xml")

  """
  def hello do
    :world
  end

  def test do
    Warzone.BattleServer.join()
    Warzone.BattleServer.submit_code("thrust(10)\nturn(5)")
  end

  def m1 do
    Warzone.BattleServer.submit_code("cow({power=10})")
  end

  def m2 do
    Warzone.BattleServer.submit_code("gar\n[]!cow({power=10})")
  end

  def m3 do
    Warzone.BattleServer.submit_code("scan({flu=10})")
  end

  def m4 do
    Warzone.BattleServer.submit_code("scan({flu=10})")
  end

  def m5 do
    Warzone.BattleServer.submit_code(
      "x=5\nwhile true do\nif x == 5 then\n x = 6\nprint(x)\n else\n x = x + 1\n if x % 1000000 == 0 then print(x) end \nend\nend"
    )
  end

  def k do
    Task.Supervisor.children(Warzone.TaskSupervisor)
  end
end
