# WIP

- build: adjust the Erlang path in [premake5.lua](premake5.lua) &rarr; `./build.sh`
- demo:
  - one terminal: `./demo_exs.sh` or open an interactive shell: `iex --sname demo@localhost --cookie secretcookie`
  - another terminal one: `./otp_pony_node`

successful POC:

- messages received
- graceful handling a failed receive

```txt
$ ./otp_pony_node
Connection successful
Received: 100bytes
Received: 100bytes
Received: 100bytes
Receive failed. Disconnecting
```

## Backlog

- spike
  - receive with timeout
  - send/send with timeout
  - destructuring the messages in Pony
- Travis CI
- testing strategy
- reconnects?

## Dependencies

### ei_connect

- http://erlang.org/doc/man/ei_connect.html [Apache License 2.0](https://www.erlang.org/about)
- key API currently in use
  - `ei_set_tracelevel`
  - `ei_connect`
  - `ei_xreceive_msg`

### Pony

- https://github.com/ponylang/ponyc [BSD 2-Clause](https://github.com/ponylang/ponyc/blob/master/LICENSE)

### Elixir

- used for the demo
- https://elixir-lang.org [Apache License 2.0](https://github.com/elixir-lang/elixir/blob/master/LICENSE)

### Premake

- simplified meta-build
- http://premake.github.io [BSD 3-Clause](https://github.com/premake/premake-core/blob/master/LICENSE.txt)