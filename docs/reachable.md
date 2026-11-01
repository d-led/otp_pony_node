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

The name is `<alive>@<the machine's host name without its domain>`, in lower
case: a node of Erlang's own started with a short name only calls hosts it can
name without a domain. `this_nodename()` says what the node is called, and it
is worth asking rather than building the name.

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

Name the Elixir node on the host the Pony node named itself on, as the example
in `integration.sh` does:

```bash
elixir --sname "caller@${pony_node#*@}" --cookie secretcookie incoming.exs "$pony_node"
```

A node of Erlang's own with a short name only talks to hosts it can name
without a domain, so a machine whose short host name resolves with one refuses
the connection when the two ends are named differently.

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

## Trying it

`demo/main.pony` has both directions. Build it, then serve:

```bash
./build.sh
./otp_pony_node --listen 47_002
```

It prints the name it published and waits for a call. From Elixir, with the
same cookie and a node name on the same host:

```elixir
# iex --sname caller@yourhost --cookie secretcookie
send({:any, :"pony_server@yourhost"}, {self(), "hi"})
flush()
# {:reply, "pong from a reachable node: hi", #PID<...>}
```

`integration.sh` runs exactly that against the demo in both directions, and
fails if either exchange does not happen.

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

