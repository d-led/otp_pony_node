use "erl"
use "debug"

use "path:./"

actor PonyNode
    let _env : Env
    let erl: EInterface

    new create(env: Env) =>
        _env = env
        erl = EInterface("pony", "secretcookie")
        // erl.set_tracelevel(5)

    be demo() =>
        let connected = erl.connect("demo@localhost")
        match connected
        | ConnectionFailed => 
            _env.out.print("Connection failed. Exiting")
            return
        | ConnectionSucceeded =>
            _env.out.print("Connection successful")
        end

        receive_loop()

    be receive_loop() =>
        // todo: receive with timeout
        let receved = erl.receive()
        match receved
        | ReceiveFailed =>
            _env.out.print("Receive failed. Disconnecting")
            erl.disconnect()
            return
        | let m: EMessage =>
            handle_message(m)
        end

        // until failure
        receive_loop()
    
    fun print_string_or_none(a: (String | None), s: I32) =>
      match a
        | let text: String =>
          _env.out.print("atom["+ s.string() + "]: " + text)
        else
          _env.out.print("Expected a string...:(")
        end
    
    fun handle_message(m: EMessage ref) =>
      _env.out.print("Received: " + m.length().string() + "bytes")
      m.debug_type_at(m.beginning)
      // expecting a tuple with a pid & a message (binary)
      (var arity, var pos) = m.tuple_arity_at(m.beginning)
      if arity != 2 then
        _env.out.print("Didn't expect tuple arity of " + arity.string())
        return
      end
      // print_string_or_none(a, s)
      // (a, s) = m.atom_at(m.header_size + s)
      // print_string_or_none(a, s)
      // m.debug_type_at(m.header_size + s + s)

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
