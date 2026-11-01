use "collections"
use "pony_test"

use "../erl_interface_pony"

class TermAccessTest is TestList
  fun name(): String => "reading a term without try"

  fun tag tests(test: PonyTest) =>
    test(_TupleElementAtTest)
    test(_TuplePastItsEndTest)
    test(_ListElementAtTest)
    test(_ListTailIsNotAnElementTest)
    test(_MapLookupTest)
    test(_MapKeysMatchByValueTest)
    test(_BinaryKeyLookupTest)
    test(_AtomKeyLookupTest)
    test(_KeyKindsDoNotMixTest)

class iso _TupleElementAtTest is UnitTest
  fun name(): String => "a tuple gives the element at an index it has"

  fun apply(h: TestHelper) =>
    let call = ErlangTuple([ErlangAtom("reply"); ErlangBinary("hi")])

    match call.at(0)
    | let first: ErlangAtom => h.assert_true(first.name == "reply")
    else h.fail("the first element is there and is an atom")
    end

    match call.at(1)
    | let second: ErlangBinary => h.assert_true(second.value == "hi")
    else h.fail("the second element is there and is a binary")
    end

class iso _TuplePastItsEndTest is UnitTest
  fun name(): String => "a tuple says nothing rather than raising past its end"

  fun apply(h: TestHelper) =>
    let call = ErlangTuple([ErlangAtom("reply")])
    h.assert_true(call.at(1) is None, "a one element tuple has no second")
    h.assert_true(call.at(99) is None)

    let empty = ErlangTuple(recover Array[ErlangTerm] end)
    h.assert_true(empty.at(0) is None, "an empty tuple has no first")

class iso _ListElementAtTest is UnitTest
  fun name(): String => "a list gives the element at an index it has"

  fun apply(h: TestHelper) =>
    let numbers = ErlangList([ErlangInteger(10); ErlangInteger(20)])

    match numbers.at(1)
    | let second: ErlangInteger => h.assert_true(second.value == 20)
    else h.fail("the second element is there and is an integer")
    end

    h.assert_true(numbers.at(2) is None, "the list has only two elements")

class iso _ListTailIsNotAnElementTest is UnitTest
  fun name(): String => "the tail of an improper list is not an element"

  fun apply(h: TestHelper) =>
    let improper = ErlangList([ErlangInteger(1)], ErlangInteger(2))

    h.assert_true(improper.at(1) is None)

    match improper.tail
    | let tail: ErlangInteger =>
      h.assert_true(tail.value == 2, "the tail is reached through `tail`")
    else h.fail("the tail is the integer 2")
    end

class iso _MapLookupTest is UnitTest
  fun name(): String => "a map gives the value for a key it has"

  fun apply(h: TestHelper) =>
    let map = ErlangMap(
      [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangBinary("two"))])

    match map.get(ErlangAtom("b"))
    | let value: ErlangBinary => h.assert_true(value.value == "two")
    else h.fail("the key b is there and holds a binary")
    end

    h.assert_true(map.get(ErlangAtom("missing")) is None, "an absent key gives nothing")

class iso _MapKeysMatchByValueTest is UnitTest
  fun name(): String => "a map key finds its value by structure, as Erlang does"

  fun apply(h: TestHelper) =>
    let key = ErlangTuple([ErlangAtom("k"); ErlangInteger(1)])
    let map = ErlangMap([(key, ErlangBinary("found"))])

    match map.get(ErlangTuple([ErlangAtom("k"); ErlangInteger(1)]))
    | let value: ErlangBinary => h.assert_true(value.value == "found")
    else h.fail("a structurally equal key finds its value")
    end

class iso _BinaryKeyLookupTest is UnitTest
  fun name(): String => "a map keyed by binaries reads back by name"

  fun apply(h: TestHelper) =>
    let map = ErlangMap.binary_keyed([("timeout", ErlangInteger(7))])

    match ErlangValues.integer(map.get_binary("timeout"))
    | let value: I64 => h.assert_eq[I64](7, value)
    else h.fail("the key timeout is there and holds an integer")
    end

    h.assert_true(map.get_binary("missing") is None, "an absent key gives nothing")

class iso _AtomKeyLookupTest is UnitTest
  fun name(): String => "a map keyed by atoms reads back by name"

  fun apply(h: TestHelper) =>
    let map = ErlangMap.atom_keyed([("count", ErlangInteger(3))])

    match ErlangValues.integer(map.get_atom("count"))
    | let value: I64 => h.assert_eq[I64](3, value)
    else h.fail("the key count is there and holds an integer")
    end

    h.assert_true(map.get_atom("missing") is None, "an absent key gives nothing")

class iso _KeyKindsDoNotMixTest is UnitTest
  fun name(): String => "a binary key and an atom of one name are two keys"

  fun apply(h: TestHelper) =>
    let binaries = ErlangMap.binary_keyed([("timeout", ErlangInteger(7))])

    h.assert_true(binaries.get_atom("timeout") is None,
      "asking as an atom does not find a binary key")
    h.assert_true(binaries.get_binary("timeout") isnt None,
      "asking as a binary does")
