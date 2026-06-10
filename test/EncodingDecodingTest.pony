use "pony_test"
use "debug"

use "../erl_interface_pony"

class EncodingDecodingTest is TestList
  fun name(): String => "encoding and decoding Erlang messages"

  fun tag tests(test: PonyTest) =>
    test(_EncodingRoundtripTest)
    test(_ConstructingMessageFromNullPtr)
    test(_RecursiveDecodingTest)
    test(_ErlInterfaceHelpersTest)

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

    // tuples
    h.assert_eq[I32](m.encode_tuple_header(2), 0)
    (var arity, read_pos) = m.tuple_arity_at(read_pos)
    h.assert_eq[I32](2, arity)
    h.assert_eq[I32](m.encode_binary("part 1"), 0)
    h.assert_eq[I32](m.encode_atom("part 2"), 0)
    (b, read_pos) = m.binary_at(read_pos)
    (a, read_pos) = m.atom_at(read_pos)
    h.assert_eq[String](b as String, "part 1")
    h.assert_eq[String](a as String, "part 2")

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

class iso _RecursiveDecodingTest is UnitTest
  fun name(): String => "recursive decoding of nested Erlang terms"

  fun apply(h: TestHelper) ? =>
    let m = EMessage.begin()
    h.assert_true(m.valid())

    // Structure we want to encode: {hello, test@localhost, {"nested binary", nested_atom}}
    h.assert_eq[I32](m.encode_tuple_header(3), 0)
    h.assert_eq[I32](m.encode_atom("hello"), 0)
    let pid = ErlangPid.create("test@localhost", 1, 2, 3)
    h.assert_eq[I32](m.encode_pid(pid), 0)
    
    h.assert_eq[I32](m.encode_tuple_header(2), 0)
    h.assert_eq[I32](m.encode_binary("nested binary"), 0)
    h.assert_eq[I32](m.encode_atom("nested atom"), 0)

    match ErlangTermDecoder.decode(m)
    | let root_tuple: ErlangTuple =>
      h.assert_eq[USize](root_tuple.elements.size(), 3)
      
      // Match element 1: Atom "hello"
      match root_tuple.elements(0)?
      | let a: ErlangAtom =>
        h.assert_eq[String](a.name, "hello")
      else
        h.fail("element 0 is not an ErlangAtom")
      end

      // Match element 2: Pid "test@localhost"
      match root_tuple.elements(1)?
      | let p: ErlangPid =>
        h.assert_eq[String](p.node, "test@localhost")
        h.assert_eq[U32](p.num, 1)
        h.assert_eq[U32](p.serial, 2)
        h.assert_eq[U32](p.creation, 3)
      else
        h.fail("element 1 is not an ErlangPid")
      end

      // Match element 3: Nested Tuple {"nested binary", nested_atom}
      match root_tuple.elements(2)?
      | let nested_tuple: ErlangTuple =>
        h.assert_eq[USize](nested_tuple.elements.size(), 2)
        
        match nested_tuple.elements(0)?
        | let b: ErlangBinary =>
          h.assert_eq[String](b.value, "nested binary")
        else
          h.fail("nested element 0 is not an ErlangBinary")
        end

        match nested_tuple.elements(1)?
        | let a2: ErlangAtom =>
          h.assert_eq[String](a2.name, "nested atom")
        else
          h.fail("nested element 1 is not an ErlangAtom")
        end
      else
        h.fail("element 2 is not an ErlangTuple")
      end
    else
      h.fail("decoded term is not an ErlangTuple")
    end

class iso _ErlInterfaceHelpersTest is UnitTest
  fun name(): String => "testing erl_interface helper wrappers"

  fun apply(h: TestHelper) =>
    // 1. Tracelevel
    let erl = EInterface("pony_test_node", "cookie")
    erl.set_tracelevel(3)
    h.assert_eq[I32](erl.get_tracelevel(), 3)
    erl.set_tracelevel(0)
    h.assert_eq[I32](erl.get_tracelevel(), 0)

    // 2. Compatibility setting
    erl.set_compat_rel(26) // Just verify it doesn't crash

    // 3. Node names (unconnected should be empty)
    h.assert_eq[String](erl.this_nodename(), "")
    h.assert_eq[String](erl.this_hostname(), "")
    h.assert_eq[String](erl.this_alivename(), "")

    // 4. Pid comparison
    let pid1 = ErlangPid.create("node1@localhost", 1, 2, 3)
    let pid2 = ErlangPid.create("node1@localhost", 1, 2, 3)
    let pid3 = ErlangPid.create("node2@localhost", 1, 2, 3)
    let pid4 = ErlangPid.create("node1@localhost", 5, 2, 3)

    h.assert_true(pid1.eq(pid2))
    h.assert_true(pid2.eq(pid1))
    h.assert_false(pid1.eq(pid3))
    h.assert_false(pid1.eq(pid4))
