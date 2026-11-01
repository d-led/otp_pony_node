# Calls a Pony node that published itself, the other way round from demo.exs.
#
# The node is named on the command line, because the name it published is the
# only one that reaches it: a host name spelled here can differ in case from
# the one the node registered, and then the node is not found.  integration.sh
# reads the name the Pony node printed.
target =
  case System.argv() do
    [name] -> String.to_atom(name)
    _ ->
      IO.puts("usage: elixir incoming.exs <node@host>")
      System.halt(2)
  end

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
