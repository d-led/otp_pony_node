use "pony_test"

use "../erl_interface_pony"

class ErlInterfaceTest is TestList
  fun name(): String => "the C node itself"

  fun tag tests(test: PonyTest) =>
    test(_TraceLevelTest)
    test(_CompatibilityTest)
    test(_NodeIdentityTest)
    test(_NotConnectedTest)
    test(_PidComparisonTest)

class iso _TraceLevelTest is UnitTest
  fun name(): String => "the trace level is a setting erl_interface keeps"

  fun apply(h: TestHelper) =>
    let erl = EInterface("pony_test_node", "cookie")
    erl.set_tracelevel(3)
    h.assert_eq[I32](3, erl.get_tracelevel())
    erl.set_tracelevel(0)
    h.assert_eq[I32](0, erl.get_tracelevel())

class iso _CompatibilityTest is UnitTest
  fun name(): String => "asking for an older distribution release is accepted"

  fun apply(h: TestHelper) =>
    let erl = EInterface("pony_test_node", "cookie")
    erl.set_compat_rel(26)

class iso _NodeIdentityTest is UnitTest
  fun name(): String => "a node knows its own name before it is connected"

  fun apply(h: TestHelper) =>
    let erl = EInterface("pony_test_node", "cookie")
    h.assert_false(erl.connected())
    h.assert_eq[String]("pony_test_node", erl.this_alivename(),
      "the alive name is the one the node was created with")
    h.assert_true(erl.this_nodename().size() > 0,
      "the full node name is resolved from the host name")

class iso _NotConnectedTest is UnitTest
  fun name(): String => "a node that is not connected does not pretend to send"

  fun apply(h: TestHelper) =>
    let erl = EInterface("pony_test_node", "cookie")
    let message = EMessage.begin()

    match erl.send_to(ErlangPid("nobody@localhost"), message, 10)
    | SendFailed => h.assert_true(true)
    else h.fail("sending without a connection must fail")
    end

    match erl.receive_with_timeout(10)
    | ReceiveFailed => h.assert_true(true)
    else h.fail("receiving without a connection must fail")
    end

    match erl.connect("")
    | ConnectionFailed => h.assert_true(true)
    else h.fail("connecting to nothing must fail")
    end

class iso _PidComparisonTest is UnitTest
  fun name(): String => "pids compare by node, number, serial and creation"

  fun apply(h: TestHelper) =>
    let pid = ErlangPid("node1@localhost", 1, 2, 3)
    let same = ErlangPid("node1@localhost", 1, 2, 3)
    let other_node = ErlangPid("node2@localhost", 1, 2, 3)
    let other_number = ErlangPid("node1@localhost", 5, 2, 3)

    h.assert_true(pid == same, "equal pids are equal")
    h.assert_true(pid < other_number, "numbers order pids")
    h.assert_true(other_node > pid, "nodes order pids")
    h.assert_true(pid <= same)
    h.assert_true(pid >= same)
    h.assert_true(pid != other_node)

    h.assert_eq[String]("<1.2.3@node1@localhost>", pid.string())
