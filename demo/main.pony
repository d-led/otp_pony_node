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
      m.debug_type_at(m.beginning)
      // expecting a tuple with a pid & a message (binary)
      (var arity, var pos) = m.tuple_arity_at(m.beginning)
      if arity != 2 then
        _env.out.print("Pony: didn't expect tuple arity of " + arity.string())
        return
      end
      m.debug_type_at(pos)
      (var pid, pos) = m.pid_at(pos)
      print_pid_or_none(pid)
      m.debug_type_at(pos)
      (let msg, pos) = m.binary_at(pos)
      print_string_or_none(msg)

      match pid
      | let p: ErlangPid =>
        // reply
        _env.out.print("Pony: elixir target: " + p.string())
        let r = EMessage.begin()
        // r.encode_pid(erl.self_pid())
        _reply_nr = _reply_nr + 1
        r.encode_binary("hello from Pony " + _reply_nr.string() + "!")
        _env.out.print("Pony: sending a reply")
        erl.send_with_timeout(p, r, 500)
      else
        _env.out.print("Pony: no Pid to send the answer to")
      end

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
