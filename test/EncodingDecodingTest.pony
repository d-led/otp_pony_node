use "ponytest"
use "debug"

use "../erl_interface_pony"

class EncodingDecodingTest is TestList
  fun name(): String => "encoding and decoding Erlang messages"

  fun tag tests(test: PonyTest) =>
    test(_EncodingRoundtripTest)
    test(_ConstructingMessageFromNullPtr)

class iso _EncodingRoundtripTest is UnitTest
  fun name(): String => "encoding a representative message and decoding it"

  fun apply(h: TestHelper) ? =>
    let m = EMessage.begin()
    h.assert_true(m.valid())

    // before encoding
    (var t, var s) = m.type_at(m.beginning)
    h.assert_eq[U8](
        t,
        TermType.none()
    )

    // atoms
    h.assert_eq[I32](m.encode_atom("hello"), 0)
    (t, s) = m.type_at(m.beginning)
    h.assert_eq[U8](
        t,
        TermType.t_ERL_ATOM_EXT()
    )
    h.assert_eq[I32](m.encode_atom("a test"), 0)
    (var a, var read_pos) = m.atom_at(m.beginning)
    h.assert_eq[String](a as String, "hello")
    (a, read_pos) = m.atom_at(read_pos)
    h.assert_eq[String](a as String, "a test")

    // binaries
    h.assert_eq[I32](m.encode_binary("an Ö test"), 0)
    (var b, read_pos) = m.binary_at(read_pos)
    h.assert_eq[String](b as String, "an Ö test")

    // pids
    let pid = ErlangPid.create("me@localhost", 1, 2 ,3)
    h.assert_eq[I32](m.encode_pid(pid), 0)
    (var p, read_pos) = m.pid_at(read_pos)
    let pid2 = p as ErlangPid
    h.assert_eq[String](pid2.node, pid.node)
    h.assert_eq[U32](pid2.num, pid.num)
    h.assert_eq[U32](pid2.serial, pid.serial)
    h.assert_eq[U32](pid2.creation, pid.creation)


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
