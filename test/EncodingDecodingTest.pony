use "pony_test"

use "../erl_interface_pony"

class EncodingDecodingTest is TestList
  fun name(): String => "encoding and decoding messages"

  fun tag tests(test: PonyTest) =>
    test(_EmptyMessageTest)
    test(_AtomTest)
    test(_IntegerTest)
    test(_DoubleTest)
    test(_BinaryTest)
    test(_BinaryWithNulBytesTest)
    test(_EmptyBinaryTest)
    test(_PidTest)
    test(_PortTest)
    test(_ReferenceTest)
    test(_TupleHeaderTest)
    test(_ListHeaderTest)
    test(_MapHeaderTest)
    test(_NullMessageTest)
    test(_DecodingTheWrongTypeTest)

class iso _EmptyMessageTest is UnitTest
  fun name(): String => "a fresh message carries only the protocol version"

  fun apply(h: TestHelper) =>
    let message = EMessage.begin()
    h.assert_true(message.valid())
    h.assert_eq[USize](1, message.length(),
      "only the version byte is written")

    (let type_tag, _) = message.type_at(message.beginning)
    h.assert_eq[I32](TermType.none(), type_tag,
      "there is no term to describe yet")

class iso _AtomTest is UnitTest
  fun name(): String => "an atom is written and read back"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_atom("hello"))

    (let type_tag, _) = message.type_at(message.beginning)
    h.assert_eq[I32](TermType.atom(), type_tag)

    (let atom, let next) = message.decode_atom(message.beginning)
    h.assert_eq[String]("hello", atom as String)
    h.assert_true(next > message.beginning, "the position moves past the atom")
    h.assert_eq[USize](message.length(), next.usize(),
      "the atom is the whole message")

class iso _IntegerTest is UnitTest
  fun name(): String => "integers of every width are written and read back"

  fun apply(h: TestHelper) ? =>
    let values: Array[I64] val = [
      0
      1
      -1
      65
      -300
      2_147_483_648
      I64.max_value()
      I64.min_value()
    ]

    for value in values.values() do
      let message = EMessage.begin()
      h.assert_eq[I32](0, message.encode_int(value))

      (let decoded, let _) = message.decode_int(message.beginning)
      h.assert_eq[I64](value, decoded as I64)
    end

class iso _DoubleTest is UnitTest
  fun name(): String => "doubles are written and read back"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_double(1.5))

    (let decoded, let _) = message.decode_double(message.beginning)
    h.assert_eq[F64](1.5, decoded as F64)

class iso _BinaryTest is UnitTest
  fun name(): String => "a binary is written and read back"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_binary("an Ö test"))

    (let decoded, let _) = message.decode_binary(message.beginning)
    h.assert_eq[String]("an Ö test", decoded as String)

class iso _BinaryWithNulBytesTest is UnitTest
  fun name(): String => "a binary keeps bytes after a NUL"

  fun apply(h: TestHelper) ? =>
    let bytes = recover String end
    bytes.push('a')
    bytes.push(0)
    bytes.push('b')

    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_binary(consume bytes))

    (let decoded, let _) = message.decode_binary(message.beginning)
    h.assert_eq[String]("a\x00b", decoded as String,
      "the length on the wire decides, not the first NUL")

class iso _EmptyBinaryTest is UnitTest
  fun name(): String => "an empty binary is a binary"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_binary(""))

    (let type_tag, _) = message.type_at(message.beginning)
    h.assert_eq[I32](TermType.binary(), type_tag)

    (let decoded, let _) = message.decode_binary(message.beginning)
    h.assert_eq[String]("", decoded as String)

class iso _PidTest is UnitTest
  fun name(): String => "a pid keeps node, number, serial and creation"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_pid("me@localhost", 1, 2, 3))

    (let decoded, let _) = message.decode_pid(message.beginning)
    let pid = decoded as ErlangPid
    h.assert_eq[String]("me@localhost", pid.node)
    h.assert_eq[U32](1, pid.num)
    h.assert_eq[U32](2, pid.serial)
    h.assert_eq[U32](3, pid.creation)

class iso _PortTest is UnitTest
  fun name(): String => "a port keeps node, id and creation"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_port("me@localhost", 42, 7))

    (let decoded, let _) = message.decode_port(message.beginning)
    let port = decoded as ErlangPort
    h.assert_eq[String]("me@localhost", port.node)
    h.assert_eq[U64](42, port.id)
    h.assert_eq[U32](7, port.creation)

class iso _ReferenceTest is UnitTest
  fun name(): String => "a reference keeps its words"

  fun apply(h: TestHelper) ? =>
    let ids: Array[U32] val = [1; 2; 3]
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_reference("ref@localhost", ids, 4))

    (let decoded, let _) = message.decode_reference(message.beginning)
    let reference = decoded as ErlangReference
    h.assert_eq[String]("ref@localhost", reference.node)
    h.assert_eq[USize](3, reference.size())
    h.assert_eq[U32](4, reference.creation)
    h.assert_true(
      ErlangTerms.eq(ErlangReference("ref@localhost", ids, 4), reference),
      "every word survives")

class iso _TupleHeaderTest is UnitTest
  fun name(): String => "a tuple header announces its arity"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_tuple_header(2))
    h.assert_eq[I32](0, message.encode_atom("first"))
    h.assert_eq[I32](0, message.encode_atom("second"))

    (let arity, let after_header) =
      message.decode_tuple_header(message.beginning)
    h.assert_eq[I32](2, arity)

    (let first, let after_first) = message.decode_atom(after_header)
    h.assert_eq[String]("first", first as String)
    (let second, let _) = message.decode_atom(after_first)
    h.assert_eq[String]("second", second as String)

class iso _ListHeaderTest is UnitTest
  fun name(): String => "a two element list announces two elements"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_list_header(2))
    h.assert_eq[I32](0, message.encode_int(1))
    h.assert_eq[I32](0, message.encode_int(2))
    h.assert_eq[I32](0, message.encode_empty_list())

    (let arity, let after_header) =
      message.decode_list_header(message.beginning)
    h.assert_eq[I32](2, arity)

    (let first, let after_first) = message.decode_int(after_header)
    h.assert_eq[I64](1, first as I64)

    (let second, let after_second) = message.decode_int(after_first)
    h.assert_eq[I64](2, second as I64)

    (let terminator, _) = message.decode_list_header(after_second)
    h.assert_eq[I32](0, terminator, "the empty list ends it")

class iso _MapHeaderTest is UnitTest
  fun name(): String => "a map header announces its number of pairs"

  fun apply(h: TestHelper) ? =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_map_header(1))
    h.assert_eq[I32](0, message.encode_atom("key"))
    h.assert_eq[I32](0, message.encode_int(7))

    (let arity, let after_header) =
      message.decode_map_header(message.beginning)
    h.assert_eq[I32](1, arity)

    (let key, let after_key) = message.decode_atom(after_header)
    h.assert_eq[String]("key", key as String)
    (let value, let _) = message.decode_int(after_key)
    h.assert_eq[I64](7, value as I64)

class iso _NullMessageTest is UnitTest
  fun name(): String => "a message built from a null pointer is empty, and says so"

  fun apply(h: TestHelper) =>
    let message = EMessage.from_cpointer(Pointer[None])
    h.assert_false(message.valid())
    h.assert_eq[USize](0, message.length())

    match ErlangTermDecoder.decode(message)
    | let term: ErlangTerm =>
      h.fail("a null message decoded to " + ErlangTermPrinter.string(term))
    else
      h.assert_true(true, "there is nothing to decode")
    end

class iso _DecodingTheWrongTypeTest is UnitTest
  fun name(): String => "decoding a term as the wrong type fails and stays put"

  fun apply(h: TestHelper) =>
    let message = EMessage.begin()
    h.assert_eq[I32](0, message.encode_atom("not a binary"))

    (let decoded, let next) = message.decode_binary(message.beginning)
    h.assert_true(decoded is None, "an atom is not a binary")
    h.assert_eq[I32](message.beginning, next,
      "a failed decode leaves the position where it was")
