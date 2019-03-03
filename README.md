# Erlang C Node for the Pony Language (spike/WIP)

[![Build Status](https://travis-ci.org/d-led/otp_pony_node.svg?branch=master)](https://travis-ci.org/d-led/otp_pony_node)

- build: `./build.sh`
- demo: `./test.sh`

successful POC:

- messages received
- graceful handling of a failed receive
- parsing the messages (in progress)

```txt
$ ./otp_pony_node
Connection successful
Received: 100bytes
Received: 100bytes
Received: 100bytes
Receive failed. Disconnecting
```

## Sending messages to the Pony node from the IEx

```elixir
$ iex --sname demo@localhost --cookie secretcookie
iex(demo@localhost)1> {:ok, hostname} = :inet.gethostname
{:ok, '...'}
iex(demo@localhost)2> pony = {:any, :"pony@#{String.downcase("#{hostname}")}"}
{:any, :"pony@..."}
iex(demo@localhost)3> send(pony, {self(),"0: Hi!"})
{#PID<0.109.0>, "0: Hi!"}
```

## Backlog

- spike
  - receive with timeout
  - send/send with timeout
  - destructuring the messages in Pony
- testing strategy
- remove the double term type checking in decode functions after testing is in place
- remove the demo executable and treat the project as a library
- reconnects / actor interface design?

## Dependencies

### ei_connect

- http://erlang.org/doc/man/ei_connect.html [Apache License 2.0](https://www.erlang.org/about)
- key API currently in use
  - `ei_set_tracelevel`
  - `ei_connect`
  - `ei_xreceive_msg`
  - [`ei_decode_*`](http://erlang.org/doc/man/ei.html)

### Pony

- https://github.com/ponylang/ponyc [BSD 2-Clause](https://github.com/ponylang/ponyc/blob/master/LICENSE)

### Elixir

- used for the demo
- https://elixir-lang.org [Apache License 2.0](https://github.com/elixir-lang/elixir/blob/master/LICENSE)

### Premake

- simplified meta-build
- http://premake.github.io [BSD 3-Clause](https://github.com/premake/premake-core/blob/master/LICENSE.txt)

## Development

- Tested on OSX & Linux currently
- `vagrant up` if you don't want to install the dependencies yourself
