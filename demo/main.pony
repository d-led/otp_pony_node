use "../erl_interface_pony"
use "debug"

use "path:../"

actor PonyNode
    let _env : Env
    let erl: EInterface
    var _reply_nr: U8 = 0

    new create(env: Env) =>
        _env = env
        erl = EInterface("pony", "secretcookie")
        // erl.set_tracelevel(5)

    be demo() =>
        let connected = erl.connect("demo@localhost")
        match connected
        | ConnectionFailed => 
            _env.out.print("Pony: connection failed. Exiting")
            return
        | ConnectionSucceeded =>
            _env.out.print("Pony: connection successful")
        end

        receive_loop()

    be receive_loop() =>
        // todo: receive with timeout
        let receved = erl.receive_with_timeout(5_000/*ms*/)
        match receved
        | ReceiveFailed =>
            _env.out.print("Pony: receive failed. Disconnecting")
            erl.disconnect()
            return
        | ReceiveTimedOut =>
            _env.out.print("Pony: receive timed out. Disconnecting")
            erl.disconnect()
            return
        | let m: EMessage =>
            handle_message(m)
        end

        // until failure
        receive_loop()
    
    fun print_string_or_none(a: (String | None)) =>
      match a
        | let text: String =>
          _env.out.print("Pony: atom: " + text)
        else
          _env.out.print("Pony: expected a string...:(")
        end

    fun print_pid_or_none(a: (ErlangPid | None)) =>
      match a
        | let p: ErlangPid =>
          _env.out.print("Pony: pid: " + p.node)
        else
          _env.out.print("Pony: expected a Pid...:(")
        end
    
    fun ref handle_message(m: EMessage ref) =>
      _env.out.print("Pony: received: " + m.length().string() + "bytes")
      
      // Keep original debug_type_at calls to print the type info for the tests/demo logs
      m.debug_type_at(m.beginning)
      (var arity, var pos) = m.tuple_arity_at(m.beginning)
      if arity == 2 then
        m.debug_type_at(pos)
        (var pid, var pos2) = m.pid_at(pos)
        m.debug_type_at(pos2)
      end

      match ErlangTermDecoder.decode(m)
      | let root_tuple: ErlangTuple =>
        try
          let pid = root_tuple.elements(0)? as ErlangPid
          let msg = root_tuple.elements(1)? as ErlangBinary

          _env.out.print("Pony: pid: " + pid.node)
          _env.out.print("Pony: atom: " + msg.value)

          _env.out.print("Pony: elixir target: " + pid.string())
          let r = EMessage.begin()
          r.encode_tuple_header(3)
          r.encode_atom("reply")
          _reply_nr = _reply_nr + 1
          r.encode_binary("hello from Pony " + _reply_nr.string() + "!")
          r.encode_pid(erl.self_pid())
          _env.out.print("Pony: sending a reply")
          erl.send_with_timeout(pid, r, 500)
        else
          _env.out.print("Pony: no Pid to send the answer to")
        end
      else
        _env.out.print("Pony: failed to decode root term as tuple")
      end

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
