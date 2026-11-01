use "collections"
use "pony_test"

use "../erl_interface_pony"

class TermValueTest is TestList
  fun name(): String => "terms behave like values"

  fun tag tests(test: PonyTest) =>
    test(_AtomsAreValuesTest)
    test(_NestedTermsAreValuesTest)
    test(_DifferentTermsAreNotEqualTest)
    test(_FloatsCompareByBitsTest)
    test(_MapsCompareIgnoringOrderTest)
    test(_BigIntegersNormaliseTest)
    test(_EqualTermsHashAlikeTest)
    test(_TermsAsMapKeysTest)

class iso _AtomsAreValuesTest is UnitTest
  fun name(): String => "two atoms with the same name are equal"

  fun apply(h: TestHelper) =>
    h.assert_true(ErlangAtom("ok") == ErlangAtom("ok"))
    h.assert_true(ErlangAtom("ok") != ErlangAtom("error"))

class iso _NestedTermsAreValuesTest is UnitTest
  fun name(): String => "equality reaches into tuples, lists and maps"

  fun apply(h: TestHelper) =>
    let numbers: Array[ErlangTerm] val = [ErlangInteger(1); ErlangInteger(2)]

    h.assert_true(
      ErlangTuple(numbers) == ErlangTuple(numbers),
      "the same tuple contents are equal")
    h.assert_true(ErlangList(numbers) == ErlangList(numbers))

    let pairs: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangList(numbers))]
    h.assert_true(ErlangMap(pairs) == ErlangMap(pairs))

    h.assert_false(
      ErlangList(numbers, ErlangInteger(3)) == ErlangList(numbers),
      "a tail is part of the value")

class iso _DifferentTermsAreNotEqualTest is UnitTest
  fun name(): String => "terms of different types are never equal"

  fun apply(h: TestHelper) =>
    h.assert_false(ErlangTerms.eq(ErlangAtom("1"), ErlangInteger(1)))
    h.assert_false(
      ErlangTerms.eq(ErlangBinary("abc"), ErlangString("abc")),
      "a binary is not a charlist")
    h.assert_false(ErlangTerms.eq(ErlangInteger(1), ErlangFloat(1.0)))

class iso _FloatsCompareByBitsTest is UnitTest
  fun name(): String => "floats compare bit for bit, as =:= does"

  fun apply(h: TestHelper) =>
    h.assert_true(ErlangFloat(1.5) == ErlangFloat(1.5))
    h.assert_false(
      ErlangFloat(0.0) == ErlangFloat(-0.0),
      "zero and negative zero are different values")
    h.assert_false(
      ErlangFloat(0.0).hash() == ErlangFloat(-0.0).hash(),
      "and they hash differently, so a set keeps both")

class iso _MapsCompareIgnoringOrderTest is UnitTest
  fun name(): String => "two maps with the same pairs are equal however they were written"

  fun apply(h: TestHelper) =>
    let one: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangInteger(2))]
    let other: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("b"), ErlangInteger(2)); (ErlangAtom("a"), ErlangInteger(1))]

    h.assert_true(ErlangMap(one) == ErlangMap(other))
    h.assert_eq[USize](ErlangMap(one).hash(), ErlangMap(other).hash(),
      "equal maps hash alike")

    let different: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangInteger(1)); (ErlangAtom("b"), ErlangInteger(3))]
    h.assert_false(ErlangMap(one) == ErlangMap(different))

class iso _BigIntegersNormaliseTest is UnitTest
  fun name(): String => "a big integer is stored one way per value"

  fun apply(h: TestHelper) =>
    let no_digits: Array[U8] val = []
    h.assert_true(ErlangBigInteger(false, [0]) == ErlangBigInteger(false, no_digits),
      "zero has one spelling")
    h.assert_true(ErlangBigInteger(true, [0]) == ErlangBigInteger(false, no_digits),
      "and no negative zero")
    h.assert_true(ErlangBigInteger(false, [1; 0]) == ErlangBigInteger(false, [1]),
      "trailing zero digits carry no value")
    h.assert_eq[USize](ErlangBigInteger(false, [1; 0]).hash(),
      ErlangBigInteger(false, [1]).hash())

class iso _EqualTermsHashAlikeTest is UnitTest
  fun name(): String => "equal terms hash the same, so a set can look them up"

  fun apply(h: TestHelper) =>
    let numbers: Array[ErlangTerm] val = [ErlangInteger(1); ErlangInteger(2)]
    let first: ErlangTerm = ErlangTuple(numbers)
    let second: ErlangTerm = ErlangTuple(numbers)

    h.assert_true(ErlangTerms.eq(first, second))
    h.assert_eq[USize](ErlangTerms.hash(first), ErlangTerms.hash(second))

    let seen = Set[ErlangTuple]
    seen.set(ErlangTuple(numbers))
    h.assert_true(seen.contains(ErlangTuple(numbers)),
      "a set of one sees its own member")

class iso _TermsAsMapKeysTest is UnitTest
  fun name(): String => "a term can be a map key"

  fun apply(h: TestHelper) =>
    let ids: Array[U32] val = [1; 2]
    let counts = Map[ErlangReference, I64]
    counts(ErlangReference("ref@localhost", ids, 3)) = 1

    try
      h.assert_eq[I64](1, counts(ErlangReference("ref@localhost", ids, 3))?,
        "the key is found by value, not by identity")
    else
      h.fail("an equal reference was not found in the map")
    end
