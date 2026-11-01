# Being called

The tutorial's node calls out. A node can also be the one that is called:
publish it, and accept what arrives.

## Publish, then accept

```pony
use "erl_interface_pony"

actor Main
  new create(env: Env) =>
    let node = EInterface("pony", "secretcookie")

    match node.publish(47_001)
    | Published =>
      env.out.print(node.this_nodename() + " listening on "
        + node.published_port().string())
    | PublishFailed =>
      env.out.print("cannot be reached (" + node.last_error() + ")")
      return
    end

    match node.accept_with_timeout(30_000)
    | let connection: EInterface =>
      env.out.print(connection.peer_nodename() + " called in")
      connection.dispose()
    | AcceptTimedOut =>
      env.out.print("nobody called")
    | AcceptFailed =>
      env.out.print("accepting failed (" + node.last_error() + ")")
    end
```

`publish(0)` lets the system choose a port, and `published_port()` reports the
one it took.

## The other side

An Elixir node reaches a published node by name:

```elixir
{:ok, host} = :inet.gethostname
target = :"pony@#{host}"

Node.connect(target)
send({:any, target}, {self(), "hi from Elixir"})

receive do
  {:reply, text, _from} -> IO.puts("Elixir: #{text}")
after
  5_000 -> IO.puts("Elixir: nothing came back")
end
```

The cookie has to be the one the node was created with.

## An accepted connection

`accept` answers with an `EInterface` of its own. It shares the node the
listener made, and holds that node until both are disposed, so either may go
first. Reading a call on it is the same as reading one anywhere else:

```pony
match ErlangShapes.pair(ErlangTermDecoder.decode(message))
| (let sender: ErlangPid, let text: ErlangBinary) =>
  let body: Array[ErlangTerm] val = [
    ErlangAtom("reply")
    ErlangBinary("pong: " + text.value)
    sender
  ]
  let answer = EMessage.begin()
  try answer.encode(ErlangTuple(body))? end
  connection.send_to(sender, answer, 500)
else None
end
```

## Before it works

Publishing needs epmd, the port mapper that Erlang starts for itself. A machine
that only has this library starts it once:

```bash
epmd -daemon
```

A publish that finds nothing listening there fails, and `last_error()` says so.
`./test.sh` starts epmd when it is installed, because the reachable tests
publish a node of their own.
