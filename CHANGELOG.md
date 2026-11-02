# Changelog

What changed between releases, newest first. Each version is a git tag, which
is what `corral add … --version X.Y.Z` asks for. `0.2.0` is the first release;
nothing before it was published for corral.

## 0.7.2 — 2026-11-02

### Fixed

A receive with a time limit counts the time from the call. The polls that arrive on a quiet connection used to start the wait again, so `receive_with_timeout(3_000)` on a live connection could wait far longer than three seconds.

A connection stays reachable while it is read. The C library answers the other side's polls from inside a receive, and a connection that nobody reads for longer than the other node's `net_ticktime` (sixty seconds by default) is dropped and reported as down there. This side does not poll, so it notices a connection that went away on the next read or write.

The demo used to stop reading a served connection after five seconds of quiet, which cut off a caller that was silent for longer; it reads for sixty seconds now.

## 0.7.1 — 2026-11-02

### Fixed

A node is named after the host without its domain, so an Erlang or Elixir node started with `-sname` can call it. When the host's resolver returned a qualified name, the node carried the domain into its own name, and a short-name peer refused it with `System NOT running to use fully qualified hostnames`.

## 0.7.0 — 2026-11-02

### Added

A node can be called. `publish` registers the node's name with epmd, `accept_with_timeout` takes a connection from a node that calls in, and the result is read with the same `receive_with_timeout` as an outgoing connection.

```pony
use "erl_interface_pony"

actor Listener
  let _env: Env
  let _erl: EInterface

  new create(env: Env) =>
    _env = env
    _erl = EInterface("pony_server", "secretcookie")

  be start() =>
    match _erl.publish(47_002)
    | PublishFailed =>
      _env.out.print("cannot be reached: " + _erl.last_error())
    | Published =>
      _env.out.print("listening as " + _erl.this_nodename())
    end

  be accept() =>
    match _erl.accept_with_timeout(30_000)
    | let caller: EInterface =>
      _env.out.print(caller.peer_nodename() + " called in")
    | AcceptTimedOut => None
    | AcceptFailed => None
    end
```

### Fixed

`dispose` closes the listening socket before it lets go of the node, so a node that was disposed cannot be called any more. The name stays with epmd until the process ends, so one process publishes a given name once.

## 0.6.0 — 2026-11-01

### Added

`ErlangShapes.pair` and `triple` take a `(ErlangTerm | None)`, so the result of `ErlangTermDecoder.decode` goes straight in and a handler matches without unwrapping first.

The documentation site: a tutorial, a guide to reading messages, and a page for every type generated from the docstrings.

## 0.5.0 — 2026-11-01

### Added

`ErlangMap.get_binary` and `get_atom` look a key up by the kind of key the other side wrote, and `ErlangMap.binary_keyed` and `atom_keyed` build a map with that kind of key. An atom and a binary of the same name are different keys, and Elixir writes binary keys for a `%{"timeout" => 5000}` map.

## 0.4.0 — 2026-11-01

### Added

`ErlangValues` reads the value out of a term without a cast: `atom_name`, `bytes`, `chars`, `integer`, `float` and `pid`. Each returns `None` for a term of another kind, so a handler matches on the result instead of going through a type test.

## 0.3.0 — 2026-11-01

### Added

`ErlangShapes.is_atom` compares an atom's name, and `ErlangShapes.pair` and `triple` split a two or three element tuple into its elements.

A term reads without `try`: `ErlangList.at` and `ErlangTuple.at` give the element at an index, and `ErlangMap.get` gives the value under a key, each returning `None` when the term is another kind or holds nothing there.

### Fixed

The first use of the C library is kept to one thread, so creating two nodes at the same time no longer races in its initialisation.

## 0.2.0 — 2026-11-01

### Added

The first release: an Erlang C node for Pony. Terms are Pony values, one class per wire type, decoded and encoded as whole values. The C library is wrapped by a shim that CMake builds into one static archive, so a program wants no `ei` at run time and nothing on a library path.
