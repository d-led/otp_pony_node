use "pony_test"

use "../erl_interface_pony"

class ReachableTest is TestList
  fun name(): String => "being reachable"

  fun tag tests(test: PonyTest) =>
    test(_AcceptWithoutPublishTest)
    test(_PublishOnceTest)
    test(_CallFromAnotherNodeTest)
    test(_AcceptedConnectionSharesTheNodeTest)

primitive _NeedsEpmd
  """
  Publishing talks to epmd, which Erlang starts for itself; a machine that only
  has the library needs `epmd -daemon` first.
  """
  fun fail(h: TestHelper, node: EInterface) =>
    h.fail("publishing needs epmd running ("
      + node.last_error() + "); start it with `epmd -daemon`")

actor _CallingNode
  """
  Another node connecting in, as an Erlang node would.

  The connect is bounded: a caller that cannot finish the handshake stops
  waiting instead of holding the node it was made from, and the process wide
  lock the C library needs, for as long as the peer stays silent.
  """

  let _name: String
  let _target: String
  let _h: TestHelper
  let _say: (String | None)

  new create(name: String, target: String, h: TestHelper,
    say: (String | None) = None)
  =>
    _name = name
    _target = target
    _h = h
    _say = say

  be call() =>
    let node = EInterface(_name, "cookie")

    match node.connect_with_timeout(_target, 10_000)
    | ConnectionFailed =>
      _h.fail("a caller could not reach the server ("
        + node.last_error() + ")")
      _h.complete(false)
      return
    | ConnectionSucceeded => None
    end

    match _say
    | let text: String => ask(node, text)
    else None
    end

  fun ask(node: EInterface, text: String) =>
    try
      let body: Array[ErlangTerm] val = [node.self_pid()?; ErlangBinary(text)]
      let message = EMessage.begin()
      message.encode(ErlangTuple(body))?

      match node.send_to_registered("any", message, 500)
      | SentOk => None
      else
        _h.fail("the call did not go out")
        _h.complete(false)
        return
      end

      match node.receive_with_timeout(10_000)
      | let reply: EMessage =>
        match ErlangShapes.triple(ErlangTermDecoder.decode(reply))
        | (let kind: ErlangAtom, let answer: ErlangBinary,
           let sender: ErlangPid)
        =>
          _h.assert_eq[String]("reply", kind.name)
          _h.assert_eq[String]("pong: " + text, answer.value)
          _h.assert_true(sender == node.self_pid()?,
            "the answer carries the pid that asked")
          _h.complete(true)
        else
          _h.fail("the answer was not {reply, Binary, Pid}")
          _h.complete(false)
        end
      | ReceiveTimedOut =>
        _h.fail("no answer came back")
        _h.complete(false)
      | ReceiveFailed =>
        _h.fail("the connection to the server broke")
        _h.complete(false)
      end
    end

class iso _AcceptWithoutPublishTest is UnitTest
  fun name(): String => "a node that has not published accepts nothing"

  fun apply(h: TestHelper) =>
    let node = EInterface("pony_test_unpublished", "cookie")

    match node.accept_with_timeout(10)
    | AcceptFailed => h.assert_true(true)
    else h.fail("accepting without publishing must fail")
    end

    node.dispose()

class iso _PublishOnceTest is UnitTest
  fun name(): String => "a published node has a port and listens once"

  fun apply(h: TestHelper) =>
    let node = EInterface("pony_test_publisher", "cookie")

    match node.publish(0)
    | Published =>
      h.assert_true(node.published_port() > 0,
        "a port of the system's choosing was bound")
      h.assert_true(node.this_nodename().contains("@"),
        "the name other nodes connect to")
    else
      _NeedsEpmd.fail(h, node)
      return
    end

    match node.publish(0)
    | Published => h.fail("a node listens once")
    | PublishFailed => h.assert_true(true)
    end

    node.dispose()
    h.assert_eq[U32](0, node.published_port())

actor _AnsweringNode
  """
  Publishes itself, invites a caller in, and answers what it says.

  The waiting happens here rather than in `apply`, because `apply` runs on the
  test runner's thread: an actor that was only told to call in waits for a
  scheduler to pick it up, and with the runner's thread taken by the accept,
  the call would wait for the accept that waits for the call.
  """

  let _h: TestHelper
  let _caller_name: String
  let _text: String

  new create(h: TestHelper, caller_name: String, text: String) =>
    _h = h
    _caller_name = caller_name
    _text = text

  be serve() =>
    let node = EInterface("pony_test_server", "cookie")

    match node.publish(0)
    | Published => None
    else
      _NeedsEpmd.fail(_h, node)
      _h.complete(false)
      return
    end

    _CallingNode(_caller_name, node.this_nodename(), _h, _text).call()

    match node.accept_with_timeout(15_000)
    | let connection: EInterface =>
      _h.assert_true(connection.peer_nodename().contains(_caller_name),
        "the accepted connection knows who called")

      answer(connection)
      connection.dispose()
    | AcceptTimedOut =>
      _h.fail("nobody was accepted")
      _h.complete(false)
    | AcceptFailed =>
      _h.fail("accepting failed (" + node.last_error() + ")")
      _h.complete(false)
    end

    node.dispose()

  fun ref answer(connection: EInterface) =>
    match connection.receive_with_timeout(10_000)
    | let message: EMessage =>
      match ErlangShapes.pair(ErlangTermDecoder.decode(message))
      | (let sender: ErlangPid, let text: ErlangBinary) =>
        _h.assert_eq[String](_text, text.value)

        let body: Array[ErlangTerm] val = [
          ErlangAtom("reply")
          ErlangBinary("pong: " + text.value)
          sender
        ]
        let reply = EMessage.begin()
        try reply.encode(ErlangTuple(body))? end
        connection.send_to(sender, reply, 500)
      else
        _h.fail("the call was not {Pid, Binary}")
        _h.complete(false)
      end
    | ReceiveTimedOut =>
      _h.fail("the call never arrived")
      _h.complete(false)
    | ReceiveFailed =>
      _h.fail("the accepted connection broke")
      _h.complete(false)
    end

actor _NodeThatOutlivesItsPublisher
  """
  Publishes itself, invites a caller in, and then lets go of the interface
  that published the node while the accepted connection is still in use.
  """

  let _h: TestHelper
  let _caller_name: String

  new create(h: TestHelper, caller_name: String) =>
    _h = h
    _caller_name = caller_name

  be serve() =>
    let node = EInterface("pony_test_shared", "cookie")

    match node.publish(0)
    | Published => None
    else
      _NeedsEpmd.fail(_h, node)
      _h.complete(false)
      return
    end

    _CallingNode(_caller_name, node.this_nodename(), _h).call()

    match node.accept_with_timeout(15_000)
    | let connection: EInterface =>
      let published_name = node.this_nodename()

      node.dispose()

      _h.assert_eq[String](published_name, connection.this_nodename(),
        "the node outlives the interface that published it")

      connection.dispose()
      _h.complete(true)
    | AcceptTimedOut =>
      _h.fail("nobody was accepted")
      _h.complete(false)
    | AcceptFailed =>
      _h.fail("accepting failed (" + node.last_error() + ")")
      _h.complete(false)
    end

class iso _CallFromAnotherNodeTest is UnitTest
  """
  The server answers what a caller sends, so both directions are seen working
  over a connection this package never opened itself.
  """

  fun name(): String => "a node answers a call from another node"

  fun apply(h: TestHelper) =>
    h.long_test(30_000_000_000)
    _AnsweringNode(h, "pony_test_caller", "hi from a calling node").serve()

class iso _AcceptedConnectionSharesTheNodeTest is UnitTest
  fun name(): String => "an accepted connection keeps its node alive"

  fun apply(h: TestHelper) =>
    h.long_test(30_000_000_000)
    _NodeThatOutlivesItsPublisher(h, "pony_test_shared_caller").serve()
