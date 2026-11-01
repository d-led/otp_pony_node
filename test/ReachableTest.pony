use "pony_test"

use "../erl_interface_pony"

class ReachableTest is TestList
  """
  Publishing, and what a published node does with its name once it is let go.

  A call between two of this library's own nodes in one process is not what
  this suite drives: the C library keeps state per process, and a node that
  answers another node of the same program meets that state.  A call in is
  proved where the other side really is another program, in `integration.sh`,
  where an Elixir node calls the demo and waits for its answer.
  """

  fun name(): String => "being reachable"

  fun tag tests(test: PonyTest) =>
    test(_AcceptWithoutPublishTest)
    test(_PublishOnceTest)
    test(_ADisposedNodeCannotBeCalledTest)

primitive _NeedsEpmd
  """
  Publishing talks to epmd, which Erlang starts for itself; a machine that only
  has the library needs `epmd -daemon` first.
  """
  fun fail(h: TestHelper, node: EInterface) =>
    h.fail("publishing needs epmd running ("
      + node.last_error() + "); start it with `epmd -daemon`")

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

class iso _ADisposedNodeCannotBeCalledTest is UnitTest
  """
  Letting go of a published node closes the socket it listened on, so a caller
  is turned away at once, whatever epmd still remembers of the name.
  """

  fun name(): String => "a disposed node cannot be called"

  fun apply(h: TestHelper) =>
    let node = EInterface("pony_test_disposed", "cookie")

    match node.publish(0)
    | Published => None
    else
      _NeedsEpmd.fail(h, node)
      return
    end

    let published_name = node.this_nodename()
    node.dispose()

    let late_caller = EInterface("pony_test_late_caller", "cookie")

    match late_caller.connect_with_timeout(published_name, 2_000)
    | ConnectionFailed => h.assert_true(true)
    | ConnectionSucceeded =>
      h.fail("a disposed node took a call after it was let go")
    end

    late_caller.dispose()
