use "ponytest"
use "../erl_interface_pony"

class EncodingDecodingTest is TestList
  fun name(): String => "encoding and decoding Erlang messages"

  fun tag tests(test: PonyTest) =>
    test(_ConstructingMessageFromNullPtr)

class iso _ConstructingMessageFromNullPtr is UnitTest
  fun name(): String => "constructing a messsage from a null pointer should not crash the program"

  fun apply(h: TestHelper) =>
    let bad_message = EMessage.from_cpointer(Pointer[None])
    h.assert_eq[USize](
        bad_message.length(),
        0
    )

    (let t, let s) = bad_message.type_at(bad_message.beginning)
    h.assert_eq[U8](
        t,
        TermType.none()
    )
