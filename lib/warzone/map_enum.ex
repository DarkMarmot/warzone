defmodule Warzone.MapEnum do
  def map(%{} = map, map_fun) when is_function(map_fun, 1) do
    map
    |> Enum.map(fn {key, value} -> {key, map_fun.(value)} end)
    |> Map.new()
  end

  def pmap(%{} = map, map_fun) do
    map
    |> Enum.map(
      &Task.async(fn ->
        {k, v} = &1
        {k, map_fun.(v)}
      end)
    )
    |> Enum.map(&Task.await(&1, 500))
    |> Map.new()
  end

  def filter(%{} = map, filter_fun) when is_function(filter_fun, 1) do
    map
    |> Enum.filter(fn {key, value} -> filter_fun.(value) end)
    |> Map.new()
  end

  def filter_map(%{} = map, filter_fun, map_fun)
      when is_function(filter_fun, 1) and is_function(map_fun, 1) do
    map
    |> Enum.filter(fn {key, value} -> filter_fun.(value) end)
    |> Enum.map(fn {key, value} -> {key, map_fun.(value)} end)
    |> Map.new()
  end
end
