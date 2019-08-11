defmodule Warzone.Cache do
  use GenServer

  def start_link(_) do
    IO.puts("moo")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def save(key, value) do

  end

  def load(key) do

  end

  @impl true
  def init(state) do
    IO.puts("init!")
    :ets.new(Warzone.Cache, [:set, :protected, :named_table, read_concurrency: true])
    file = "ship.lua"
    code_path = Path.join(:code.priv_dir(:warzone), file)
    file_contents = File.read!(code_path)
    chunk = Sandbox.chunk!(Sandbox.init(), file_contents)
    IO.inspect(chunk)
    {:ok, state}
  end


end