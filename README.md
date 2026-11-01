# Erlang C Node for the Pony Language

[![Native CI Build and Test](https://github.com/d-led/otp_pony_node/actions/workflows/ci.yml/badge.svg)](https://github.com/d-led/otp_pony_node/actions/workflows/ci.yml)
[![Docker CI Build and Test](https://github.com/d-led/otp_pony_node/actions/workflows/docker-image.yml/badge.svg)](https://github.com/d-led/otp_pony_node/actions/workflows/docker-image.yml)

An Erlang C node for **Pony**: exchange messages with the BEAM (Erlang/Elixir)
over the standard distribution protocol, with Erlang terms as ordinary Pony
values.

The distribution plumbing comes from OTP's `ei` (`erl_interface`). On top of it
lives a small pure Pony layer:

| | |
|---|---|
| `EInterface` | a node: connect, receive, send, identify yourself |
| `EMessage` | one encoded message, the low level encoder and decoder |
| `ErlangTerm` | atoms, integers, big integers, floats, binaries, bitstrings, strings, lists, tuples, maps, pids, ports, references |
| `ErlangTermEncoder` / `ErlangTermDecoder` | whole terms in and out |
| `ErlangTermPrinter` | a term in Erlang syntax, for logs and tests |

Everything that has a value has a class, so terms can be pattern matched and
compared; the few types that cannot be modelled (funs, exports) are carried
verbatim in `ErlangOpaque` and can still be forwarded.

## Requirements

- **Erlang/OTP** with `erl_interface` (`ei.h` and the static archive `libei.a`).
- **Pony** (`ponyc`), installed with [ponyup](https://github.com/ponylang/ponyup).
- **CMake ≥ 3.20** and a C11 compiler, to build the native shim.

`erl_interface` is located automatically by asking the `erl` on your `PATH`.
To point at a specific installation, configure with
`-DOPN_EI_DIR=/path/to/lib/erlang/lib/erl_interface-X.Y`.

## Using it from Corral

```bash
corral add github.com/d-led/otp_pony_node.git
corral fetch

# Corral does not run build scripts for native code, so build the shim once:
make -C _corral/github_com_d-led_otp_pony_node
```

That produces `libotp_pony_node_c.a` in the package directory: a **single self
contained static archive** with `ei` folded in. Nothing has to be copied next to
your binary and no library search path is needed at run time.

Then use the package from your program:

```pony
use "path:_corral/github_com_d-led_otp_pony_node"
use "lib:otp_pony_node_c"
use "erl_interface_pony"
```

## Talking to a node

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
    | ConnectionSucceeded =>
      _env.out.print("Pony: connected as " + _erl.this_nodename())
    end

    receive_loop()

  be receive_loop() =>
    match _erl.receive_with_timeout(5_000)
    | ReceiveFailed  => return
    | ReceiveTimedOut => return
    | let message: EMessage =>
      reply(message)
    end
    receive_loop()

  fun ref reply(message: EMessage ref) =>
    match ErlangTermDecoder.decode(message)
    | let call: ErlangTuple =>
      try
        let sender = call.elements(0)? as ErlangPid
        let text = call.elements(1)? as ErlangBinary
        _env.out.print("Pony: \"" + text.value + "\" from " + sender.string())

        let self_pid = _erl.self_pid()?
        let answer: Array[ErlangTerm] val = [
          ErlangAtom("reply")
          ErlangBinary("hello from Pony!")
          self_pid
        ]
        let encoded = EMessage.begin()
        encoded.encode(ErlangTuple(answer))?
        _erl.send_to(sender, encoded, 500)
      end
    else
      _env.out.print("Pony: not a {Pid, Binary} call")
    end
```

`receive_with_timeout(0)` waits forever. Sending to a process registered under a
name goes through `send_to_registered`.

## Terms

Encode a term to bytes, decode it back, and print it:

```pony
let pairs: Array[(ErlangTerm, ErlangTerm)] val =
  [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangFloat(2.5))]

let message = EMessage.begin()
message.encode(ErlangTuple([ErlangAtom("reply"); ErlangMap(pairs)]))?
ErlangTermPrinter.string(ErlangTuple([...]))   // {reply, #{a => 1, b => 2.5}}

match ErlangTermDecoder.decode(message)
| let term: ErlangTuple => ...  // elements are ErlangTerm again
else                          // the message did not decode
end
```

Low level access is available too: `encode_atom`, `encode_int`,
`encode_binary`, `encode_list_header`, `encode_map_header`, `encode_pid`,
`encode_port`, `encode_reference`, … and the matching `decode_*` functions,
each of which reports the position just past the term it read.

### What maps to what

| Erlang | Pony |
|---|---|
| `atom` | `ErlangAtom` |
| `-1`, `42` | `ErlangInteger` (`I64`) |
| integers wider than 64 bits | `ErlangBigInteger`, `.decimal()` to read |
| `1.5` | `ErlangFloat` (`F64`) |
| `<<"bytes">>` | `ErlangBinary` (raw bytes, NUL safe) |
| `<<1:3>>` | `ErlangBitstring` (unused trailing bits cleared) |
| `"abc"` | `ErlangString` (a byte charlist) |
| `[1, 2 \| 3]` | `ErlangList` with an improper `tail` |
| `{a, b}` | `ErlangTuple` |
| `#{a => 1}` | `ErlangMap`, as key/value pairs in wire order |
| `<0.1.0>` | `ErlangPid` |
| `#Port<…>` | `ErlangPort` |
| `#Ref<…>` | `ErlangReference` |
| funs, exports, anything newer | `ErlangOpaque`, forwarded unchanged |

Two consequences of the wire format are worth knowing: a byte aligned
bitstring *is* a binary, and an empty bitstring decodes as an `ErlangBinary`.
`ErlangTerms.eq` compares terms structurally; maps compare in wire order.

## Limitations

- Links, monitors and exit signals are delivered by the BEAM but not modelled;
  only `SEND` and `REG_SEND` messages carry a term this library decodes.
- Distribution compression and TLS are not implemented.
- `ErlangOpaque` terms can be forwarded, not inspected.
- Terms are decoded recursively, so a pathologically deep term from an
  untrusted peer can exhaust the stack.

## Building this repository

```bash
./build.sh          # native shim + demo + tests
./build.sh --debug  # same, unoptimised
./test.sh           # unit tests, no Erlang node needed
./integration.sh    # round trip against a live Elixir node (needs Elixir)
```

`./demo_exs.sh` runs the Elixir side of the demo in the foreground if you want to
watch the exchange, then run `./otp_pony_node` in another terminal.

### The build

The native part is [CMake](CMakeLists.txt) with presets:

```bash
cmake --preset debug
cmake --build --preset debug
```

`cmake/MergeStaticLibraries.cmake` folds `libei.a` into
`libotp_pony_node_c.a` so consumers link exactly one file, and
`cmake/toolchains/zig.cmake` lets you build with `zig cc` instead of the system
compiler (`cmake --preset zig`).

This repository used premake before: it committed prebuilt `premake5` binaries
for three platforms and generated project files that were checked in. CMake
removes both, finds `erl_interface` in the same way the old Lua script did, and
gives IDEs and CI one entry point. Zig is a good *compiler* choice here (one
toolchain on every platform, no `libstdc++`/`libc++` mismatch), but not a good
*build system* choice: `ei` has to be found on the host, so there is nothing to
cross compile, and `build.zig` would be one more thing to learn. Hence CMake for
orchestration, zig as an optional toolchain.
