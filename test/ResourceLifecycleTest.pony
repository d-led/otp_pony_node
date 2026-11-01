use "pony_test"

use "../erl_interface_pony"

class ResourceLifecycleTest is TestList
  fun name(): String => "the C handles are released and then refuse work"

  fun tag tests(test: PonyTest) =>
    test(_DisposedMessageTest)
    test(_FailedEncodeLeavesTheMessageAloneTest)
    test(_DisposedNodeTest)

class iso _DisposedMessageTest is UnitTest
  fun name(): String => "a disposed message is empty and refuses work instead of crashing"

  fun apply(h: TestHelper) =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_atom("hello"))

    message.dispose()
    h.assert_false(message.valid())
    h.assert_eq[USize](0, message.length())

    (let type_tag, _) = message.type_at(message.beginning)
    h.assert_eq[I32](TermType.none(), type_tag)

    (let atom, _) = message.decode_atom(message.beginning)
    h.assert_true(atom is None, "there is nothing to decode")

    h.assert_ne[I32](0, message.encode_atom("too late"),
      "encoding into a disposed message reports failure")

    message.dispose()
    h.assert_true(true, "disposing twice is a no-op")

class iso _FailedEncodeLeavesTheMessageAloneTest is UnitTest
  fun name(): String => "a term that cannot be encoded leaves the message as it was"

  fun apply(h: TestHelper) =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_atom("ok"))
    let before = message.length()

    let long_node: String val = recover
      let text = String
      var index: USize = 0
      while index < 2000 do
        text.push('a')
        index = index + 1
      end
      text
    end

    try
      message.encode(ErlangPid(long_node, 1, 2, 3))?
      h.fail("a node name longer than ei accepts must not encode")
    end

    h.assert_eq[USize](before, message.length(),
      "the part that was written is not left behind")

    match ErlangTermDecoder.decode(message)
    | let term: ErlangTerm =>
      h.assert_true(ErlangTerms.eq(term, ErlangAtom("ok")),
        "the message still holds what it held before")
    else
      h.fail("the message should still decode to the atom")
    end

class iso _DisposedNodeTest is UnitTest
  fun name(): String => "a disposed node stops sending and cannot come back"

  fun apply(h: TestHelper) =>
    let erl = EInterface("pony_test_node", "cookie")
    h.assert_eq[String]("pony_test_node", erl.this_alivename(),
      "the node exists before it is disposed")

    erl.dispose()
    h.assert_false(erl.connected())
    h.assert_eq[String]("", erl.this_alivename(),
      "a disposed node does not build a new one on demand")

    match erl.send_to(ErlangPid("nobody@localhost"), EMessage.begin(), 10)
    | SendFailed => h.assert_true(true)
    else h.fail("a disposed node must not send")
    end

    match erl.connect("demo@localhost")
    | ConnectionFailed => h.assert_true(true)
    else h.fail("a disposed node must not connect again")
    end

    erl.dispose()
    h.assert_true(true, "disposing twice is a no-op")
