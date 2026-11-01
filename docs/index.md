# otp_pony_node

An Erlang C node for Pony. Your program joins a running BEAM as a node, sends
and receives Erlang terms, and keeps them as Pony values.

```pony
use "erl_interface_pony"

actor Main
  new create(env: Env) =>
    let node = EInterface("pony", "secretcookie")

    match node.connect("app@localhost")
    | ConnectionSucceeded =>
      let message = EMessage.begin()
      try message.encode(ErlangTuple([ErlangAtom("hello")]))? end

      match node.send_to_registered("app", message, 500)
      | SentOk => env.out.print("sent")
      else env.out.print("was not sent")
      end
    | ConnectionFailed =>
      env.out.print("no node there (" + node.last_error() + ")")
    end
```

Terms arrive as values of their own kind: `ErlangAtom`, `ErlangInteger`,
`ErlangTuple`, `ErlangMap` and the rest. They compare and hash by content, so a
term can be a `Map` key, and a message is read by matching on types.

## Where to go

* [Install](install.md) — add the library, build the native part.
* [Your first node](tutorial.md) — a program the BEAM can call, in one page.
* [Being called](reachable.md) — publish the node, accept what arrives.
* [Reading messages](messages.md) — shapes, values and keys, without casts.
* [API reference](api/erl_interface_pony--index.md) — every type and method.

## What it does not do

Links, monitors and exit signals reach the node but are not modelled;
distribution compression and TLS are not implemented. The
[README](https://github.com/d-led/otp_pony_node#limitations) keeps the full
list.
