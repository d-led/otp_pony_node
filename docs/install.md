# Install

## Add the library

```bash
corral add github.com/d-led/otp_pony_node.git --version 0.7.2
corral fetch
```

Corral puts the dependency in `_corral/github_com_d_led_otp_pony_node`; both
`_corral` and `_repos` belong in your `.gitignore`.

## Build the native part

The library wraps OTP's `ei` in a small C shim. Corral fetches Pony sources and
runs no build script, so the shim is built once, by hand:

```bash
make -C _corral/github_com_d_led_otp_pony_node
```

That writes `libotp_pony_node_c.a` beside the package: one archive with `ei`
inside it, so the compiled program reads no library at run time. CMake and the
Erlang installation are needed for that step and not after it.

## Dependencies

Erlang/OTP with `erl_interface`, which provides `ei.h` and the static archive
`libei.a`. Erlang/OTP ships both together; a distribution that splits it puts
them in the `erl_interface` development package.

The build reads `include/ei.h` and `lib/libei.a` out of the installation that
`erl` on your `PATH` reports, and `-DOPN_EI_DIR=<dir>` overrides that.

## Use it

```pony
use "erl_interface_pony"
```

That is the whole import. The package names the native archive itself and
`corral run -- ponyc` puts the dependency on the compiler's search path.

Compiling without corral means passing that directory yourself:

```bash
ponyc -p path/to/otp_pony_node
```
