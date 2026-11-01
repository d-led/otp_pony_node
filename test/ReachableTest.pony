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

  The handshake needs both ends moving at once, so the caller runs in an actor
  while the test accepts.
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

    match node.connect(_target)
    | ConnectionFailed =>
      _h.fail("a caller could not reach the server ("
        + node.last_error() + ")")
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
        end
      | ReceiveTimedOut => _h.fail("no answer came back")
      | ReceiveFailed => _h.fail("the connection to the server broke")
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

class iso _CallFromAnotherNodeTest is UnitTest
  """
  The server answers what a caller sends, so both directions are seen working
  over a connection this package never opened itself.
  """

  fun name(): String => "a node answers a call from another node"

  fun apply(h: TestHelper) =>
    let server = EInterface("pony_test_server", "cookie")

    match server.publish(0)
    | Published => None
    else
      _NeedsEpmd.fail(h, server)
      return
    end

    h.long_test(20_000_000_000)
    _CallingNode("pony_test_caller", server.this_nodename(), h,
      "hi from a calling node").call()

    match server.accept_with_timeout(10_000)
    | let connection: EInterface =>
      h.assert_true(connection.peer_nodename().contains("pony_test_caller"),
        "the accepted connection knows who called")

      match connection.receive_with_timeout(10_000)
      | let message: EMessage =>
        match ErlangShapes.pair(ErlangTermDecoder.decode(message))
        | (let sender: ErlangPid, let text: ErlangBinary) =>
          h.assert_eq[String]("hi from a calling node", text.value)

          let body: Array[ErlangTerm] val = [
            ErlangAtom("reply")
            ErlangBinary("pong: " + text.value)
            sender
          ]
          let answer = EMessage.begin()
          try answer.encode(ErlangTuple(body))? end
          connection.send_to(sender, answer, 500)
        else h.fail("the call was not {Pid, Binary}")
        end
      | ReceiveTimedOut => h.fail("the call never arrived")
      | ReceiveFailed => h.fail("the accepted connection broke")
      end

      connection.dispose()
    | AcceptTimedOut => h.fail("nobody was accepted")
    | AcceptFailed => h.fail("accepting failed (" + server.last_error() + ")")
    end

    server.dispose()

class iso _AcceptedConnectionSharesTheNodeTest is UnitTest
  fun name(): String => "an accepted connection keeps its node alive"

  fun apply(h: TestHelper) =>
    let server = EInterface("pony_test_shared", "cookie")

    match server.publish(0)
    | Published => None
    else
      _NeedsEpmd.fail(h, server)
      return
    end

    h.long_test(20_000_000_000)
    _CallingNode("pony_test_shared_caller", server.this_nodename(), h).call()

    match server.accept_with_timeout(10_000)
    | let connection: EInterface =>
      let published_name = server.this_nodename()

      server.dispose()

      h.assert_eq[String](published_name, connection.this_nodename(),
        "the node outlives the interface that published it")

      connection.dispose()
      h.complete(true)
    | AcceptTimedOut =>
      h.fail("nobody was accepted")
      h.complete(false)
    | AcceptFailed =>
      h.fail("accepting failed (" + server.last_error() + ")")
      h.complete(false)
    end
