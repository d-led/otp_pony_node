use "erl_interface_pony"

// Nothing to add for the native archive: corral puts the dependency directory
// on the compiler's search path, and the package links the archive itself.

actor Main
  """
  Shows the library as a Corral dependency: no Elixir node needed, just terms.
  """

  new create(env: Env) =>
    let call: Array[ErlangTerm] val = [
      ErlangAtom("demo_hello")
      ErlangBinary("hello from a corral dependency!")
    ]
    let term: ErlangTerm = ErlangTuple(call)
    env.out.print("Encoding " + ErlangTermPrinter.string(term))

    let encoded = EMessage.begin()

    try
      encoded.encode(term)?
    else
      env.out.print("encoding failed")
      env.exitcode(1)
      return
    end

    env.out.print("Encoded " + encoded.length().string() + " bytes")

    match ErlangTermDecoder.decode(encoded)
    | let decoded: ErlangTuple =>
      env.out.print("Decoded " + ErlangTermPrinter.string(decoded))

      try
        let name = decoded.elements(0)? as ErlangAtom
        let text = decoded.elements(1)? as ErlangBinary
        env.out.print("  atom:   " + name.name)
        env.out.print("  binary: " + text.value)
      end
    else
      env.out.print("decoding failed")
      env.exitcode(1)
    end
