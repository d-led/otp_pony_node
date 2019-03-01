# WIP

- build: adjust the Erlang path in [premake5.lua](premake5.lua) &rarr; `./build.sh`
- demo:
  - one terminal: `./demo_exs.sh` or open an interactive shell: `iex --sname demo@localhost --cookie secretcookie`
  - another terminal one: `./otp_pony_node`

successful POC:

- messages received
- graceful handling failed receive

```txt
$ ./otp_pony_node
Connection successful
Received: 100bytes
Received: 100bytes
Received: 100bytes
Receive failed. Disconnecting
```
