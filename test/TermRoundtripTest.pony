use "pony_test"

use "../erl_interface_pony"

class TermRoundtripTest is TestList
  fun name(): String => "terms survive a round trip through the external format"

  fun tag tests(test: PonyTest) =>
    test(_AtomsTest)
    test(_IntegersTest)
    test(_BigIntegersTest)
    test(_FloatsTest)
    test(_BinariesTest)
    test(_BitstringsTest)
    test(_StringsTest)
    test(_ListsTest)
    test(_TuplesTest)
    test(_MapsTest)
    test(_PidsPortsAndReferencesTest)
    test(_NestedTermsTest)

primitive _Roundtrip
  """
  Encodes a term, decodes it back and holds the two against each other.
  """

  fun check(h: TestHelper, term: ErlangTerm) =>
    let message = EMessage.begin()
    try
      message.encode(term)?
    else
      h.fail("could not encode " + describe(term))
      return
    end

    match ErlangTermDecoder.decode(message)
    | let decoded: ErlangTerm =>
      h.assert_true(ErlangTerms.eq(term, decoded),
        "encoded " + describe(term) + ", got back " + describe(decoded))
    else
      h.fail("could not decode " + describe(term))
    end

  fun describe(term: ErlangTerm): String =>
    """The printed term together with what it is, so a mismatch reads clearly."""
    type_name(term) + " " + ErlangTermPrinter.string(term)

  fun type_name(term: ErlangTerm): String =>
    match term
    | let _: ErlangAtom => "atom"
    | let _: ErlangInteger => "integer"
    | let _: ErlangBigInteger => "big integer"
    | let _: ErlangFloat => "float"
    | let _: ErlangBinary => "binary"
    | let _: ErlangBitstring => "bitstring"
    | let _: ErlangString => "string"
    | let _: ErlangList => "list"
    | let _: ErlangTuple => "tuple"
    | let _: ErlangMap => "map"
    | let _: ErlangPid => "pid"
    | let _: ErlangPort => "port"
    | let _: ErlangReference => "reference"
    | let _: ErlangOpaque => "opaque"
    end

class iso _AtomsTest is UnitTest
  fun name(): String => "atoms, bare and quoted"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangAtom("ok"))
    _Roundtrip.check(h, ErlangAtom("a test"))
    _Roundtrip.check(h, ErlangAtom("with'quote"))
    _Roundtrip.check(h, ErlangAtom(""))

class iso _IntegersTest is UnitTest
  fun name(): String => "integers of every width"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangInteger(0))
    _Roundtrip.check(h, ErlangInteger(42))
    _Roundtrip.check(h, ErlangInteger(-42))
    _Roundtrip.check(h, ErlangInteger(2_147_483_648))
    _Roundtrip.check(h, ErlangInteger(I64.max_value()))
    _Roundtrip.check(h, ErlangInteger(I64.min_value()))

class iso _BigIntegersTest is UnitTest
  fun name(): String => "integers wider than 64 bits"

  fun apply(h: TestHelper) =>
    // 2^64: one byte of magnitude, eight bytes up.
    let two_to_the_64: Array[U8] val = [0; 0; 0; 0; 0; 0; 0; 0; 1]
    _Roundtrip.check(h, ErlangBigInteger(false, two_to_the_64))
    _Roundtrip.check(h, ErlangBigInteger(true, two_to_the_64))

class iso _FloatsTest is UnitTest
  fun name(): String => "floats"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangFloat(0.5))
    _Roundtrip.check(h, ErlangFloat(-1.25))
    _Roundtrip.check(h, ErlangFloat(3.0))

class iso _BinariesTest is UnitTest
  fun name(): String => "binaries, including empty ones and ones with NUL bytes"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangBinary(""))
    _Roundtrip.check(h, ErlangBinary("hello"))
    _Roundtrip.check(h, ErlangBinary("a\x00b"))
    _Roundtrip.check(h, ErlangBinary("ünïcode"))

class iso _BitstringsTest is UnitTest
  fun name(): String => "bitstrings round trip, and byte aligned ones are binaries"

  fun apply(h: TestHelper) ? =>
    _Roundtrip.check(h, ErlangBitstring("a", 3))

    // Twenty-four bits are a binary on the wire, so that is what comes back.
    let message = EMessage.begin()
    message.encode(ErlangBitstring("abc"))?

    match ErlangTermDecoder.decode(message)
    | let binary: ErlangBinary =>
      h.assert_eq[String]("abc", binary.value)
    else
      h.fail("a byte aligned bitstring should decode as a binary")
    end

class iso _StringsTest is UnitTest
  fun name(): String => "strings"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangString("abc"))
    _Roundtrip.check(h, ErlangString("with space"))

class iso _ListsTest is UnitTest
  fun name(): String => "lists, proper, empty, improper and nested"

  fun apply(h: TestHelper) =>
    let empty: Array[ErlangTerm] val = []
    _Roundtrip.check(h, ErlangList(empty))

    let numbers: Array[ErlangTerm] val = [ErlangInteger(1); ErlangInteger(2)]
    _Roundtrip.check(h, ErlangList(numbers))

    let head: Array[ErlangTerm] val = [ErlangInteger(1)]
    _Roundtrip.check(h, ErlangList(head, ErlangInteger(2)))

    let nested: Array[ErlangTerm] val = [ErlangList(head); ErlangList(empty)]
    _Roundtrip.check(h, ErlangList(nested))

class iso _TuplesTest is UnitTest
  fun name(): String => "tuples, empty and nested"

  fun apply(h: TestHelper) =>
    let empty: Array[ErlangTerm] val = []
    _Roundtrip.check(h, ErlangTuple(empty))

    let pair: Array[ErlangTerm] val = [ErlangAtom("reply"); ErlangInteger(1)]
    _Roundtrip.check(h, ErlangTuple(pair))

    let call: Array[ErlangTerm] val = [ErlangAtom("call"); ErlangTuple(pair)]
    _Roundtrip.check(h, ErlangTuple(call))

class iso _MapsTest is UnitTest
  fun name(): String => "maps, empty and with several pairs"

  fun apply(h: TestHelper) =>
    let empty: Array[(ErlangTerm, ErlangTerm)] val = []
    _Roundtrip.check(h, ErlangMap(empty))

    let pairs: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangFloat(2.5))]
    _Roundtrip.check(h, ErlangMap(pairs))

class iso _PidsPortsAndReferencesTest is UnitTest
  fun name(): String => "pids, ports and references"

  fun apply(h: TestHelper) =>
    _Roundtrip.check(h, ErlangPid("me@localhost", 1, 2, 3))
    _Roundtrip.check(h, ErlangPort("me@localhost", 42, 7))

    let ids: Array[U32] val = [1; 2; 3]
    _Roundtrip.check(h, ErlangReference("me@localhost", ids, 4))

class iso _NestedTermsTest is UnitTest
  fun name(): String => "a message shaped like a real one"

  fun apply(h: TestHelper) =>
    let list: Array[ErlangTerm] val = [ErlangInteger(1); ErlangInteger(2)]
    let map: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangFloat(1.5))]
    let message: Array[ErlangTerm] val = [
      ErlangAtom("reply")
      ErlangBinary("hi")
      ErlangList(list, ErlangInteger(3))
      ErlangMap(map)
    ]

    _Roundtrip.check(h, ErlangTuple(message))
