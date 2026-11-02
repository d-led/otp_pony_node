# Calls a Pony node that published itself, the other way round from demo.exs.
#
# The node is named on the command line, because the name it published is the
# only one that reaches it: a host name spelled here can differ in case from
# the one the node registered, and then the node is not found.  integration.sh
# reads the name the Pony node printed.
#
# A second argument is a silence, in milliseconds, between connecting and
# speaking.  A node answers the polls the other side sends on a quiet
# connection only while it is reading, so a silence longer than this node's
# net_ticktime tells whether it is.
{target, silence_ms} =
  case System.argv() do
    [name] -> {name, 0}
    [name, silence] -> {name, String.to_integer(silence)}
    _ ->
      IO.puts("usage: elixir incoming.exs <node@host> [silence_ms]")
      System.halt(2)
  end

target = String.to_atom(target)

unless Node.connect(target) do
  IO.puts("Elixir: could not reach #{target}")
  System.halt(1)
end

IO.puts("Elixir: connected to #{target}")

if silence_ms > 0 do
  IO.puts("Elixir: saying nothing for #{silence_ms} ms")
  Process.sleep(silence_ms)
end

send({:any, target}, {self(), "hi from Elixir"})

receive do
  {:reply, text, _from} ->
    IO.puts("Elixir: #{text}")
after
  # A node dropped for not answering polls is gone before the message is sent,
  # and then nothing comes back.
  10_000 ->
    IO.puts("Elixir: nothing came back")
    System.halt(1)
end
