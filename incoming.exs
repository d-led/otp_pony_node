# Calls a Pony node that published itself, the other way round from demo.exs.
# The node is expected to be running as `pony@<host>` before this starts.
{:ok, host} = :inet.gethostname
target = :"pony@#{host}"

unless Node.connect(target) do
  IO.puts("Elixir: could not reach #{target}")
  System.halt(1)
end

IO.puts("Elixir: connected to #{target}")
send({:any, target}, {self(), "hi from Elixir"})

receive do
  {:reply, text, _from} ->
    IO.puts("Elixir: #{text}")
after
  5_000 ->
    IO.puts("Elixir: nothing came back")
    System.halt(1)
end
