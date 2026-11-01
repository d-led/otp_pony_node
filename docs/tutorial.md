# Your first node

A Pony program that a running BEAM can call, and that answers. The whole
program is on this page, and it runs.

## The shape of the exchange

Elixir sends `{Pid, binary}`; the node answers `{reply, binary, Pid}`. The `Pid`
is the caller's, so the answer goes back to whoever asked.

## The Elixir side

Save this as `demo.exs`:

```elixir
{:ok, hostname} = :inet.gethostname
# The node is named after the machine's host name without its domain.
host = hostname |> to_string() |> String.downcase() |> String.split(".") |> hd()
pony = {:any, :"pony@#{host}"}
# The Pony program connects after it starts, so give it a moment.
Process.sleep(2_000)

for n <- 1..5 do
  send(pony, {self(), "#{n}: Hi!"})

  receive do
    {:reply, text, _from} -> IO.puts("Elixir: #{text}")
  after
    3_000 -> IO.puts("Elixir: nothing came back")
  end
end
```

Start it and leave it running:

```bash
elixir --sname demo@localhost --cookie secretcookie demo.exs
```

`{:any, :"pony@hostname"}` addresses the node rather than a process on it, and
the cookie has to be the one the node was created with. Nothing is listening
yet; the next step is the node.

## The Pony side

```pony
use "erl_interface_pony"

actor Main
  let _env: Env
  let _node: EInterface

  new create(env: Env) =>
    _env = env
    _node = EInterface("pony", "secretcookie")

    match _node.connect("demo@localhost")
    | ConnectionFailed =>
      _env.out.print("no node there (" + _node.last_error() + ")")
      return
    | ConnectionSucceeded =>
      _env.out.print("connected as " + _node.this_nodename())
    end

    listen()

  fun ref listen() =>
    match _node.receive_with_timeout(5_000)
    | let message: EMessage =>
      answer(message)
      listen()
    | ReceiveTimedOut =>
      _env.out.print("nothing more to do")
    | ReceiveFailed =>
      _env.out.print("the other side stopped")
    end

  fun ref answer(message: EMessage ref) =>
    match ErlangShapes.pair(ErlangTermDecoder.decode(message))
    | (let sender: ErlangPid, let text: ErlangBinary) =>
      _env.out.print("asking: " + text.value)

      let reply: Array[ErlangTerm] val = [
        ErlangAtom("reply")
        ErlangBinary("pong: " + text.value)
        sender
      ]

      try
        let encoded = EMessage.begin()
        encoded.encode(ErlangTuple(reply))?
        _node.send_to(sender, encoded, 500)
      end
    else
      _env.out.print("not a {Pid, Binary}")
    end
```

Build and run it in a second terminal:

```bash
corral run -- ponyc -b node
./node
```

The first terminal starts printing:

```
Elixir: pong: 1: Hi!
Elixir: pong: 2: Hi!
...
```

## What happened there

`connect` joins the BEAM as a node called `pony` on this host. The cookie is the
distribution cookie, the same one Elixir was started with.

`receive_with_timeout(5_000)` waits up to five seconds for a message and answers
with an `EMessage`; `0` waits forever.

`ErlangShapes.pair(ErlangTermDecoder.decode(message))` is where bytes become
Pony values: either two elements, a pid and a binary, or two `None`s for
anything else. That is the only place the message's shape is checked.

The reply is a Pony array of terms encoded into a message, then sent to the pid
that asked.

## Where to go next

* [Reading messages](messages.md) — shapes, values and keys, without casts.
* `demo/` in the repository is this program with a reply counter.
* `corral_demo/` is the same library consumed through corral, with no Erlang
  node needed.
