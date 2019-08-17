defmodule Warzone.Command do
  alias __MODULE__
  defstruct name: nil, params: %{}, error: nil, cost: 0

  def build_commands(command_input, available_energy) when is_list(command_input) do
    command_input
    |> Enum.map(fn {k, v} ->
      case k do
        "fire" ->
          {k, expand_fire_params(v)}

        _ when k in ["cloak", "thrust", "scan"] ->
          {k, [Map.new(v)]}
      end
    end)
    |> Enum.flat_map(fn {k, list_of_maps} -> Enum.map(list_of_maps, fn m -> {k, m} end) end)
    |> Enum.map(fn {k, v} -> %Command{name: k, params: v} end)
    |> Enum.map(&apply_defaults/1)
    |> Enum.map(&validate/1)
    |> Enum.map(&apply_energy_cost/1)
    |> apply_available_energy(available_energy)
  end

  def expand_fire_params(params) do
    params
    |> Enum.reduce([%{}], fn {k, v}, acc ->
      case v do
        _ when is_list(v) -> v
        _ -> [{nil, v}]
      end
      |> Map.new()
      |> Map.values()
      |> Enum.flat_map(fn v2 -> Enum.map(acc, fn m -> Map.put(m, k, v2) end) end)
    end)
  end

  defp apply_available_energy(command_list, energy_available) do
    Enum.reduce(command_list, {[], energy_available}, fn %Command{cost: cost} = c, {result, n} ->
      if cost <= n do
        {[c | result], n - cost}
      else
        {[%Command{c | error: :not_enough_energy} | result], n}
      end
    end)
    |> elem(0)
  end

  defp apply_defaults(%Command{name: "fire", params: params} = cmd) do
    new_params = Map.merge(%{"speed" => 0, "duration" => 1, "damage" => 1}, params)
    %Command{cmd | params: new_params}
  end

  defp apply_defaults(%Command{params: params} = cmd) do
    new_params = Map.merge(%{"power" => 1}, params)
    %Command{cmd | params: new_params}
  end

  defp validate(%Command{} = cmd) do
    if valid_params?(cmd), do: cmd, else: %Command{cmd | error: :invalid_params}
  end

  defp apply_energy_cost(%Command{error: nil} = cmd) do
    %Command{cmd | cost: energy_cost(cmd)}
  end

  defp apply_energy_cost(%Command{} = cmd) do
    cmd
  end

  defp valid_params?(%Command{
         name: "fire",
         params: %{
           "damage" => damage,
           "duration" => duration,
           "speed" => speed,
           "direction" => direction
         }
       })
       when is_number(damage) and is_number(duration) and is_number(speed) and
              is_number(direction) do
    !(damage < 0 || duration < 1 || speed < 0)
  end

  defp valid_params?(%Command{
         name: "thrust",
         params: %{"power" => power, "direction" => direction}
       })
       when is_number(power) and is_number(direction) do
    power > 0
  end

  defp valid_params?(%Command{name: "scan", params: %{"power" => power}})
       when is_number(power) do
    power > 0
  end

  defp valid_params?(%Command{name: "cloak", params: %{"power" => power}})
       when is_number(power) do
    power > 0
  end

  defp valid_params?(%Command{name: "log"}) do
    true
  end

  defp valid_params?(_) do
    false
  end

  defp energy_cost(
         %Command{
           name: "fire",
           params: %{"damage" => damage, "duration" => duration, "speed" => speed}
         } = cmd
       ) do
    damage * (speed + 1) * duration
  end

  defp energy_cost(%Command{params: %{"power" => power}}) do
    power
  end
end
