use "../erl_interface_pony"

use "path:../"

actor PonyNode
  """
  Answers `{Pid, Binary}` messages from an Elixir node with
  `{reply, Binary, Pid}` until the other side stops talking.
  """

  let _env: Env
  let _erl: EInterface
  var _reply_number: U32 = 0

  new create(env: Env) =>
    _env = env
    _erl = EInterface("pony", "secretcookie")

  be demo() =>
    match _erl.connect("demo@localhost")
    | ConnectionFailed =>
      _env.out.print("Pony: connection failed (" + _erl.last_error() + ")")
      return
    | ConnectionSucceeded =>
      _env.out.print("Pony: connected as " + _erl.this_nodename())
    end

    receive_loop()

  be receive_loop() =>
    match _erl.receive_with_timeout(5_000)
    | ReceiveFailed =>
      _env.out.print("Pony: connection closed or unusable ("
        + _erl.last_error() + ")")
      return
    | ReceiveTimedOut =>
      _env.out.print("Pony: no more messages")
      return
    | let message: EMessage =>
      answer(message)
    end

    receive_loop()

  fun ref answer(message: EMessage ref) =>
    match ErlangTermDecoder.decode(message)
    | let call: ErlangTuple => reply_to(call)
    else
      _env.out.print("Pony: not a tuple, ignoring it")
    end

  fun ref reply_to(call: ErlangTuple) =>
    try
      let sender = call.elements(0)? as ErlangPid
      let text = call.elements(1)? as ErlangBinary
      _env.out.print("Pony: \"" + text.value + "\" from " + sender.string())

      _reply_number = _reply_number + 1
      let self_pid = _erl.self_pid()?
      let reply: Array[ErlangTerm] val = [
        ErlangAtom("reply")
        ErlangBinary("hello from Pony " + _reply_number.string() + "!")
        self_pid
      ]

      let encoded = EMessage.begin()
      encoded.encode(ErlangTuple(reply))?

      match _erl.send_to(sender, encoded, 500)
      | SentOk => None
      | SendFailed =>
        _env.out.print("Pony: the reply did not go out (" + _erl.last_error() + ")")
      | SendTimedOut =>
        _env.out.print("Pony: sending the reply timed out")
      end
    else
      _env.out.print("Pony: that was not a {Pid, Binary} call")
    end

actor Main
  new create(env: Env) =>
    PonyNode(env).demo()
