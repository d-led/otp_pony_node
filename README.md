# Erlang C Node for the Pony Language

[![Native CI Build and Test](https://github.com/d-led/otp_pony_node/actions/workflows/ci.yml/badge.svg)](https://github.com/d-led/otp_pony_node/actions/workflows/ci.yml)
[![Docker CI Build and Test](https://github.com/d-led/otp_pony_node/actions/workflows/docker-image.yml/badge.svg)](https://github.com/d-led/otp_pony_node/actions/workflows/docker-image.yml)

An implementation of Erlang C Nodes in the **Pony** language, allowing you to seamlessly exchange messages between the BEAM (Erlang/Elixir) and Pony runtimes utilizing standard Erlang node communication protocols.

---

## Installation & Setup (Corral)

You can add this library as a dependency to your Pony project using **Corral** (the Pony package manager).

### 1. Add the Dependency
Inside your project folder, run:
```bash
corral add github.com/d-led/otp_pony_node
corral fetch
```
This downloads the source code into your project's local dependency directory (typically `_corral/github_com_d-led_otp_pony_node/`).

### 2. Compile the native C wrapper (`otp_pony_node_c`)
Since Corral does not run post-install build scripts for compiled native components, you must build the custom C wrapper in the dependency directory.

#### On macOS and Linux:
Run `make` inside the dependency directory. It dynamically resolves your local Erlang/OTP `erl_interface` path using `erl` and compiles the shared library:
```bash
make -C _corral/github_com_d-led_otp_pony_node CONFIG=release
```

#### On Windows:
Generate the Visual Studio project files and compile with MSBuild:
```cmd
cd _corral\github_com_d-led_otp_pony_node
premake\windows\premake5 vs2022
msbuild build\windows\vs2022\otp_pony_node.sln /p:Configuration=Release
```

---

## Usage in Your Project

### 1. Link the Dependency
In your `.pony` source files, specify the library paths to tell `ponyc` where to link the native wrapper and locate the Pony bindings:

```pony
// Link the compiled C wrapper shared library
use "path:_corral/github_com_d-led_otp_pony_node"
use "lib:otp_pony_node_c"

// Import the erl_interface Pony package
use "github_com_d-led_otp_pony_node/erl_interface_pony"
```

### 2. Code Example (Pattern Matching Erlang Terms)
This library features a structured, recursive algebraic representation of Erlang terms (`ErlangTerm`) utilizing Pony's finite recursive type aliases. This allows you to match Erlang terms safely using standard pattern matching:

```pony
use "erl_interface_pony"

actor PonyNode
  let erl: EInterface

  new create(env: Env) =>
    erl = EInterface("pony", "secretcookie")

    // Connect to Elixir/Erlang node
    match erl.connect("demo@localhost")
    | ConnectionFailed => env.out.print("Connection failed.")
    | ConnectionSucceeded => env.out.print("Connected!")
    end

    receive_loop(env)

  be receive_loop(env: Env) =>
    // Receive message from the C-Node connection
    match erl.receive_with_timeout(5000)
    | ReceiveFailed => erl.disconnect()
    | ReceiveTimedOut => erl.disconnect()
    | let m: EMessage =>
      // Decode the raw message buffer into a structured ErlangTerm
      match ErlangTermDecoder.decode(m)
      | let root: ErlangTuple =>
        try
          // Expecting a tuple format: {Pid, Binary}
          let pid = root.elements(0)? as ErlangPid
          let msg = root.elements(1)? as ErlangBinary
          env.out.print("Received text: " + msg.value + " from " + pid.node)

          // Send a reply
          let r = EMessage.begin()
          r.encode_tuple_header(3)
          r.encode_atom("reply")
          r.encode_binary("hello from Pony!")
          r.encode_pid(erl.self_pid())
          erl.send_with_timeout(pid, r, 500)
        end
      end
    end
    receive_loop(env)
```

---

## Local Development & Testing

If you are developing this library locally:

### Requirements
- **Erlang/OTP** (with `erl_interface` headers/libraries installed).
- **Elixir** (needed for integration tests).
- **Pony** (installed via `ponyup`).

### Compile & Test
To build and execute unit and integration tests locally on macOS/Linux:
```bash
# Compile C and Pony binaries
./build.sh

# Run unit tests and distributed node demo
./test.sh
```
