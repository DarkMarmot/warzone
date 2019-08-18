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
    Warzone.BattleServer.submit_code("thrust({power=10})")
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

end
