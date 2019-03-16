# Erlang C Node for the Pony Language (spike/WIP)

[![Build Status](https://travis-ci.org/d-led/otp_pony_node.svg?branch=master)](https://travis-ci.org/d-led/otp_pony_node)

## Motivation

While different [Actor Model](https://www.brianstorti.com/the-actor-model/) implementations may differ in many details,
transferring the knowledge and design considerations between them is not too hard. An Actor is a unit of concurrency,
and processes its messages synchronously. A run-time that includes a scheduler and some form of mailboxes
for the Actors makes sure, the CPU is utilized as desired (which may vary from implementation to implementation).
Concurrent and distributed software 
not written with the Actor Model implementation [needs to solve problems]( http://rvirding.blogspot.com/2008/01/virdings-first-rule-of-programming.html), such as safe distribution and scheduling of work onto CPUs/cores,
granularity of the scheduled computations, work interruption, resource clean-up, fault-tolerance.

Pony and the BEAM (Erlang/Elixir/others) have different design goals and give different guarantees.
In a project, where the benefits of both need to be utilized, it might be beneficial to simply partition the problem,
and solve each problem with a dedicated Actor Model implementation. Depending on the use-case and the boundary conditions,
a different communication channel between the parts of the application can be chosen. This project attempts to provide
an option to write [Erlang C Nodes]( http://erlang.org/doc/man/ei_connect.html) in Pony to exchange messages between
the two run-times the Erlang way. There are other options, of course,
e.g. via ZeroMQ or any other appropriate transport available to both technologies.

A particular sweet spot for Pony is its [built-in FFI](https://tutorial.ponylang.io/c-ffi.html) that doesn’t require
an extra build system or config, given a shared library can be found. The BEAM has another sweet-spot,
as it can isolate the failures, timeouts and deadlocks of native code [by means]( http://erlang.org/doc/reference_manual/ports.html)
of starting native code in another OS process and treating a handle to it as a process (Actor).
Given a Pony C Node process, connected to a parent Erlang process, utilizing existing native libraries can be simplified without giving up the Actor Model.


## POC

- build: OSX, Linux: `./build.sh`, Windows: `build.bat`
- demo: `./test.sh`

successful POC:

- messages received in Pony
- messages sent from Pony
- graceful handling of a failed receive
- parsing the messages (in progress)
- encoding new messages (in progress)

```txt
$ ./otp_pony_node
Connection successful
1: ERL_SMALL_TUPLE 2bytes
3: ERL_PID 0bytes
29: ERL_BINARY 6bytes
Received: 100bytes
pid: demo@localhost
atom: 7: Hi!
1: ERL_SMALL_TUPLE 2bytes
3: ERL_PID 0bytes
Received: 100bytes
pid: demo@localhost
29: ERL_BINARY 6bytes
atom: 6: Hi!
Receive failed. Disconnecting
```

windows (release mode, messages sent from iex):

```txt
D:\src\otp_pony_node>otp_pony_node.exe
Connection successful
Received: 100bytes
pid: demo@localhost
atom: 0: Hi!
Received: 100bytes
pid: demo@localhost
atom: 1: Hi!
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

## Current API Preview

```pony
// connecting
let erl = EInterface("pony", "secretcookie")
match erl.connect("demo@localhost")
| ConnectionFailed => 
    _env.out.print("Connection failed. Exiting")
    return
| ConnectionSucceeded =>
    _env.out.print("Connection successful")
end

// receiving a message
match erl.receive_with_timeout(5_000/*ms*/)
| ReceiveFailed =>
    _env.out.print("Receive failed. Disconnecting")
    erl.disconnect()
    return
| ReceiveTimedOut =>
    _env.out.print("Receive timed out. Disconnecting")
    erl.disconnect()
    return
| let m: EMessage =>
    handle_message(m)
end

// handle_message: parsing the message linearly
(var arity, var pos) = m.tuple_arity_at(m.beginning)
if arity != 2 then
    _env.out.print("Didn't expect tuple arity of " + arity.string())
    return
end

// print the term type of the token at pos
m.debug_type_at(pos)

(var pid, pos) = m.pid_at(pos)
// do something with pid ...

// pos is mutable and gets updated after each successful token parsed
(let msg, pos) = m.binary_at(pos)
// do something with msg
```

## Backlog

- expand the API coverage
  - fill the gaps of encoding/decoding the messages
  - conform to the C Node protocol
- higher level API
  - message builder & reader (hiding away current position)
- connected testing strategy
- treat and test the project as a library
- reconnects / actor interface design?
- multiple connections per `EInterface`

## Development

- Linux, OSX, Windows build config via Premake
- `vagrant up` if you don't want to install the dependencies yourself

### Source Structure

- [erl_interface_pony](erl_interface_pony) the Pony API to `ei_connect`
- [src/otp_pony_node_c](src/otp_pony_node_c) - a slim wrapper around `ei_connect` (see below)
- [demo](demo) a Pony "main" spike used to get familiar with the `ei_connect` API and bootstrap the project: connects to an Erlang node and awaits message tuples
- [demo.exs](demo.exs) the OTP/Elixir counterpart to the Pony demo, which sends the expected messages
- [build](build) build config generated via premake from [premake5.lua](premake5.lua)

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
