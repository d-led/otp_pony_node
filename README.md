# otp_pony_node

An Erlang C node for Pony. It speaks the Erlang distribution protocol through
OTP's `ei` library and hands back Erlang terms as Pony values.

## Status

Beta. Expect breaking changes.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/d-led/otp_pony_node.git --version 0.7.0`
* `corral fetch` to fetch your dependencies
* `use "erl_interface_pony"` to include this package
* `corral run -- ponyc` to compile your application

## Using it from corral

Corral keeps its working directories inside your project, and the dependency
lands in `_corral/github_com_d_led_otp_pony_node`: the locator with every dot
and slash turned into an underscore, and the `.git` suffix dropped. `_corral`
and `_repos` belong in your `.gitignore`, because corral maintains them.

`corral fetch` obtains the dependencies that are missing, and `corral update`
is what moves one that is already there to the revision `corral.json` asks for.
After a version change, run `corral update` and then rebuild the shim below.

Corral fetches Pony sources and runs no build script, so the native shim is
built once, in the copy:

```bash
make -C _corral/github_com_d_led_otp_pony_node
```

That writes `libotp_pony_node_c.a` beside the package: one archive with `ei`
inside it, so the compiled program wants no `ei` at run time and nothing to
find on a library path. The archive is a build artifact, so a fresh clone of
your project needs the `make` again. CMake and the Erlang installation are
needed for it and not after it.

The package declares `use "lib:otp_pony_node_c"` itself, so your sources name
only the package:

```pony
use "erl_interface_pony"
```

That is enough because `corral run -- ponyc` puts each dependency directory on
the compiler's search path, and the linker is given those directories too.
Compiling without corral means passing the dependency directory yourself:

```bash
ponyc -p path/to/otp_pony_node
```

[`corral_demo/`](https://github.com/d-led/otp_pony_node/tree/master/corral_demo)
is a project set up this way, and `run_demo.sh` in it runs each step.

## Dependencies

Erlang/OTP with `erl_interface`, which provides `ei.h` and the static archive
`libei.a`. Erlang/OTP ships both together; a distribution that splits it puts
them in the `erl_interface` development package.

Building the shim needs CMake 3.20 or newer and a C11 compiler. The build reads
`include/ei.h` and `lib/libei.a` out of the installation that `erl` on your
`PATH` reports, and `-DOPN_EI_DIR=<dir>` overrides that.

## Usage

```pony
use "erl_interface_pony"

actor PonyNode
  let _env: Env
  let _erl: EInterface

  new create(env: Env) =>
    _env = env
    _erl = EInterface("pony", "secretcookie")

  be start() =>
    match _erl.connect("demo@localhost")
    | ConnectionFailed =>
      _env.out.print("Pony: connection failed (" + _erl.last_error() + ")")
      return
    | ConnectionSucceeded => None
    end

    receive_loop()

  be receive_loop() =>
    match _erl.receive_with_timeout(5_000)
    | ReceiveFailed => return
    | ReceiveTimedOut => return
    | let message: EMessage => answer(message)
    end
    receive_loop()

  fun ref answer(message: EMessage ref) =>
    match ErlangShapes.pair(ErlangTermDecoder.decode(message))
    | (let sender: ErlangPid, let text: ErlangBinary) =>
      _env.out.print("Pony: \"" + text.value + "\" from " + sender.string())

      let body: Array[ErlangTerm] val = [
        ErlangAtom("reply")
        ErlangBinary("hello from Pony!")
        sender
      ]

      let reply = EMessage.begin()
      try reply.encode(ErlangTuple(body))? end
      _erl.send_to(sender, reply, 500)
    else
      _env.out.print("Pony: not a {Pid, Binary} call")
    end
```

`receive_with_timeout(0)` waits forever. `send_to_registered` sends to a process
registered under a name. `dispose()` releases the socket and the node
immediately; the garbage collector releases them otherwise.

Terms encode and decode as whole values:

```pony
let pairs: Array[(ErlangTerm, ErlangTerm)] val =
  [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangFloat(2.5))]

let message = EMessage.begin()
message.encode(ErlangTuple([ErlangAtom("reply"); ErlangMap(pairs)]))?

match ErlangTermDecoder.decode(message)
| let term: ErlangTerm => ErlangTermPrinter.string(term)  // {reply, #{a => 1, b => 2.5}}
else None  // the bytes were not a term
end
```

Each wire type has a class: `ErlangAtom`, `ErlangInteger`, `ErlangBigInteger`,
`ErlangFloat`, `ErlangBinary`, `ErlangBitstring`, `ErlangString`,
`ErlangList` (proper and improper), `ErlangTuple`, `ErlangMap`, `ErlangPid`,
`ErlangPort`, `ErlangReference`. Funs and exports arrive as `ErlangOpaque`,
which carries their encoded bytes so they can be forwarded.

They are value classes: `==` compares contents and `hash()` agrees with it, so a
concrete term can be a `Map` or `Set` key. `ErlangTerm` is a union of classes
whose `eq` methods take different types, so `==` does not apply to the union;
a value known only as an `ErlangTerm` compares through `ErlangTerms.eq` and
hashes through `ErlangTerms.hash`.

`ErlangInteger` holds 64 bits. A wider integer arrives as `ErlangBigInteger`,
which stores the magnitude and gives the digits through `decimal()`.

Three of the comparisons follow Erlang rather than the host language: floats
compare bit for bit, as `=:=` does, so `0.0` and `-0.0` differ; maps compare as
sets of pairs, so the order they were written in does not matter; and a byte
aligned bitstring is a binary in the external format, so it decodes as
`ErlangBinary`. Unused bits in the last byte of a partial bitstring are cleared
on construction, which is what the format carries.

## Reading a message

Pony matches on types and not on values, so a message is read by naming the
types its elements must have. A decoder is the one place that does it, and
handlers then work with a value of their own:

```pony
class val Call
  """A `{Pid, Binary}` message, in the types a handler wants."""
  let sender: ErlangPid
  let text: String

  new val create(sender': ErlangPid, text': String) =>
    sender = sender'
    text = text'

primitive CallDecoder
  """A `{Pid, Binary}` call, or `None` for anything else."""

  fun apply(message: EMessage ref): (Call | None) =>
    match ErlangTermDecoder.decode(message)
    | let term: ErlangTerm =>
      match ErlangShapes.pair(term)
      | (let sender: ErlangPid, let text: ErlangBinary) =>
        Call(sender, text.value)
      else None
      end
    else None
    end
```

`ErlangShapes.pair` and `ErlangShapes.triple` hand back the leading elements of
a tuple, so one `match` binds each of them with its type; a term of any other
shape falls to `else`. Reading inside a term is total too: `ErlangTuple.at`,
`ErlangList.at` and `ErlangMap.get` answer `None` rather than raising, and
`ErlangTerms.is_atom` compares a tag.

`ErlangValues` reads a payload out of a term, so that a lookup and the read
that follows stay one expression:

```pony
let timeout: I64 =
  match ErlangValues.integer(config.get_binary("timeout"))
  | let found: I64 => found
  | None => 5_000   // no such key, or a value of another kind
  end
```

`atom_name`, `bytes`, `chars`, `integer`, `float` and `pid` each answer `None`
for a term of another kind, so the value is never cast and never raises.

Keys come in two kinds, and a lookup says which one it means:
`get_binary("timeout")` finds `%{"timeout" => 5000}`, `get_atom("timeout")`
finds `#{timeout => 5000}`, and `get` takes any term as the key.
`ErlangMap.binary_keyed` and `ErlangMap.atom_keyed` build the first two from
Pony strings.

## Being called

The example above calls out. A node can be the one that is called too: publish
it, then accept what arrives.

```pony
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
  answer_on(connection)  // receive and answer, as in the example above
  connection.dispose()
| AcceptTimedOut => None
| AcceptFailed => None
end
```

An accepted connection is an `EInterface` of its own that shares the node the
listener made, and it holds that node until both are disposed, so either may go
first. Reading a call on it is the same as reading one anywhere else.

Publishing needs epmd, the port mapper that Erlang starts for itself. A machine
that only has this library starts it once with `epmd -daemon`; a publish that
finds nothing there fails, and `last_error()` says so.

## Limitations

* Links, monitors and exit signals reach the node but are not modelled. Only
  `SEND` and `REG_SEND` messages carry a term this library decodes.
* Distribution compression and TLS are not implemented.
* Terms decode recursively, so a very deep term from an untrusted peer can
  exhaust the stack.
* `ErlangOpaque` terms can be forwarded, not inspected.
* The C library keeps process wide state, so creating a node and connecting
  take a process wide lock. Sending from two nodes at the same time has not
  been shown to be safe.

## API Documentation

[https://d-led.github.io/otp_pony_node/](https://d-led.github.io/otp_pony_node/)

That site carries a tutorial, the [reading messages](https://d-led.github.io/otp_pony_node/messages/)
guide, and a page for every type, generated from the docstrings in
[`erl_interface_pony/`](https://github.com/d-led/otp_pony_node/tree/master/erl_interface_pony).

## Working on this library

```bash
./build.sh          # native shim, demo and tests
./build.sh --debug  # the same, unoptimised
./test.sh           # unit tests, no Erlang node needed
./integration.sh    # round trip against a live Elixir node, needs Elixir
./ci-local.sh       # the Linux CI job, in a container
./docs.sh           # the documentation site, needs mkdocs-material
```

The container carries the toolchain the Linux job installs: `ci.yml` asks for
OTP 27.2 and Elixir 1.18.2, and the image is those versions on the same Ubuntu
release, so `ci-local.sh` runs the same commands on the same Erlang.  It cannot
run the macOS job, and on an arm64 machine it cannot stand in for the x86_64
runner.

`./demo_exs.sh` runs the Elixir side of the demo in the foreground; run
`./otp_pony_node` from another terminal to watch the exchange.

The documentation site is `./docs.sh`: it runs `pony-doc` through corral (as
the [Pony documentation](https://www.ponylang.io/use/documentation/) describes)
and builds the pages in `docs/` with the generated reference.  For an agent,
`corral run -- pony-agent-server .` answers questions about the package from
the compiler itself.

The native part is CMake, with presets in `CMakePresets.json`:

```bash
cmake --preset debug
cmake --build --preset debug
```

Zig can be the compiler (`cmake --preset zig`) but not the build system.
`erl_interface` comes from the host, so there is nothing to cross compile, and
`build.zig` would add a second language to read for no gain.

The shim lives in `src/otp_pony_node_c/`, not next to the Pony sources. ponyc
compiles a `.c` file that sits in a module directory and links it into the
program, which would make every consumer build `ei` from scratch and need the
`ei.h` include path of that machine.
