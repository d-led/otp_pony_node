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

An Elixir node reaches a published node by the name the Pony node printed when
it published, which is the one that reaches it:

```elixir
[node_name] = System.argv()
target = String.to_atom(node_name)

Node.connect(target)
send({:any, target}, {self(), "hi from Elixir"})

receive do
  {:reply, text, _from} -> IO.puts("Elixir: #{text}")
after
  5_000 -> IO.puts("Elixir: nothing came back")
end
```

A host name built here with `:inet.gethostname` can be spelled in another case
than the one the node registered, and then the node is not found. The cookie
has to be the one the node was created with.

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
`./test.sh` starts epmd when it is installed, and waits for it to answer,
because the reachable tests publish a node of their own.

## Letting go

`dispose` closes the socket the node listened on, so a caller is turned away at
once. The name belongs to epmd, which keeps it until the process ends, so a
process publishes a given name once; a program that wants a fresh node under
the same name starts a new process.

A call in is proved against a real Erlang node in `integration.sh`, where an
Elixir node calls the demo and waits for its answer. Two nodes of this library
in one process are not the other side this package is tested with: the C
library keeps state per process.

