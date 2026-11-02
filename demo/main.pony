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

  new create(env: Env, alive_name: String) =>
    _env = env
    _erl = EInterface(alive_name, "secretcookie")

  be demo() =>
    match _erl.connect("demo@localhost")
    | ConnectionFailed =>
      _env.out.print("Pony: connection failed (" + _erl.last_error() + ")")
      return
    | ConnectionSucceeded =>
      _env.out.print("Pony: connected as " + _erl.this_nodename())
    end

    receive_loop(_erl, 5_000)

  be serve(port: U32) =>
    """
    Publishes this node, so that an Elixir node can call it instead of the
    other way round.
    """
    match _erl.publish(port)
    | PublishFailed =>
      _env.out.print("Pony: cannot be reached (" + _erl.last_error() + ")")
      _env.out.flush()
      return
    | Published =>
      _env.out.print("Pony: " + _erl.this_nodename() + " listening on port "
        + _erl.published_port().string())
      // The name is what the other side calls, and a pipe would hold the line
      // until the process has written enough or has ended.
      _env.out.flush()
    end

    accept_loop()

  fun ref accept_loop() =>
    match _erl.accept_with_timeout(30_000)
    | let connection: EInterface =>
      _env.out.print("Pony: " + connection.peer_nodename() + " called in")
      // A served connection is read for as long as the caller may be quiet.
      // The other side polls a connection it has nothing to say on, and this
      // node answers those polls whenever it is reading; a connection that
      // nobody reads for longer than the other side's net_ticktime is dropped.
      receive_loop(connection, 60_000)
      accept_loop()
    | AcceptTimedOut =>
      _env.out.print("Pony: nobody called")
    | AcceptFailed =>
      _env.out.print("Pony: accepting failed (" + _erl.last_error() + ")")
    end

  fun ref receive_loop(connection: EInterface, patience_ms: U32) =>
    match connection.receive_with_timeout(patience_ms)
    | ReceiveFailed =>
      _env.out.print("Pony: connection closed or unusable ("
        + _erl.last_error() + ")")
      return
    | ReceiveTimedOut =>
      _env.out.print("Pony: no more messages")
      return
    | let message: EMessage =>
      answer(connection, message)
    end

    receive_loop(connection, patience_ms)

  fun ref answer(connection: EInterface, message: EMessage ref) =>
    match CallDecoder(message)
    | let call: Call => reply_to(connection, call)
    else
      _env.out.print("Pony: not a {Pid, Binary} call, ignoring it")
    end

  fun ref reply_to(connection: EInterface, call: Call) =>
    _env.out.print("Pony: \"" + call.text + "\" from " + call.sender.string())

    _reply_number = _reply_number + 1
    let reply: Array[ErlangTerm] val = [
      ErlangAtom("reply")
      ErlangBinary("hello from Pony " + _reply_number.string() + "!")
      call.sender
    ]

    try
      let encoded = EMessage.begin()
      encoded.encode(ErlangTuple(reply))?

      match connection.send_to(call.sender, encoded, 500)
      | SentOk => None
      | SendFailed =>
        _env.out.print("Pony: the reply did not go out (" + _erl.last_error() + ")")
      | SendTimedOut =>
        _env.out.print("Pony: sending the reply timed out")
      end
    else
      _env.out.print("Pony: the reply could not be built")
    end

class val Call
  """
  A `{Pid, Binary}` call, decoded once so that no handler deals in terms.
  """
  let sender: ErlangPid
  let text: String

  new val create(sender': ErlangPid, text': String) =>
    sender = sender'
    text = text'

primitive CallDecoder
  """One place where the shape of a message is checked."""

  fun apply(message: EMessage ref): (Call | None) =>
    match ErlangTermDecoder.decode(message)
    | let term: ErlangTerm =>
      match ErlangShapes.pair(term)
      | (let sender: ErlangPid, let text: ErlangBinary) =>
        Call(sender, text.value)
      else None
      end
    else None
    end

actor Main
  new create(env: Env) =>
    if _argument(env, 1) == "--listen" then
      // A node that is called is a node of its own, named apart from the one
      // that calls out: epmd lets go of a name a moment after the process that
      // published it has ended, and the name it lets go of is the one a node
      // started in between has just registered.
      PonyNode(env, "pony_server").serve(_port(env))
    else
      PonyNode(env, "pony").demo()
    end

  fun _argument(env: Env, index: USize): String =>
    try env.args(index)? else "" end

  fun _port(env: Env): U32 =>
    """The port after `--listen`, or the one the demo always uses."""
    try env.args(2)?.u32()? else 47_001 end
