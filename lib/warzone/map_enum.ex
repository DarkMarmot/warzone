
defmodule Warzone.MapEnum do

  def map(%{} = map, map_fun) when is_function(map_fun, 1) do
    map
    |> Enum.map(fn {key, value}-> {key, map_fun.(value)} end)
    |> Map.new()
  end

  def filter(%{} = map, filter_fun) when is_function(filter_fun, 1) do
    map
    |> Enum.filter(fn {key, value} -> filter_fun.(value) end)
    |> Map.new()
  end

  def filter_map(%{} = map, filter_fun, map_fun) when is_function(filter_fun, 1) and is_function(map_fun, 1) do
    map
    |> Enum.filter(fn {key, value} -> filter_fun.(value) end)
    |> Enum.map(fn {key, value}-> {key, map_fun.(value)} end)
    |> Map.new()
  end

end