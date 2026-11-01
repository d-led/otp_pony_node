use "pony_test"

use "../erl_interface_pony"

class TermShapeTest is TestList
  fun name(): String => "matching the shape of a message"

  fun tag tests(test: PonyTest) =>
    test(_PairBindsBothElementsTest)
    test(_PairAcceptsNoOtherShapeTest)
    test(_TripleBindsAllThreeElementsTest)
    test(_TripleAcceptsNoOtherShapeTest)
    test(_AtomIsRecognisedByNameTest)
    test(_NoTermAtAllIsNoShapeTest)

class iso _PairBindsBothElementsTest is UnitTest
  fun name(): String => "a match on a pair binds both elements with their types"

  fun apply(h: TestHelper) =>
    let call = ErlangTuple([ErlangAtom("reply"); ErlangBinary("hi")])

    match ErlangShapes.pair(call)
    | (let kind: ErlangAtom, let body: ErlangBinary) =>
      h.assert_true(kind.name == "reply")
      h.assert_true(body.value == "hi")
    else h.fail("a two element tuple binds as a pair")
    end

class iso _PairAcceptsNoOtherShapeTest is UnitTest
  fun name(): String => "a pair is a two element tuple and nothing else"

  fun apply(h: TestHelper) =>
    h.assert_false(
      _binds(ErlangTuple([ErlangAtom("only")])),
      "a one element tuple is not a pair")
    h.assert_false(
      _binds(ErlangTuple(
        [ErlangAtom("a"); ErlangAtom("b"); ErlangAtom("c")])),
      "a three element tuple is not a pair")
    h.assert_false(_binds(ErlangAtom("reply")), "an atom is not a pair")
    h.assert_false(_binds(ErlangBinary("reply")), "a binary is not a pair")

  fun _binds(term: ErlangTerm): Bool =>
    match ErlangShapes.pair(term)
    | (let left: ErlangTerm, let right: ErlangTerm) => true
    else false
    end

class iso _TripleBindsAllThreeElementsTest is UnitTest
  fun name(): String => "a match on a triple binds all three elements"

  fun apply(h: TestHelper) =>
    let call = ErlangTuple(
      [ErlangAtom("put"); ErlangBinary("k"); ErlangInteger(7)])

    match ErlangShapes.triple(call)
    | (let kind: ErlangAtom, let key: ErlangBinary, let value: ErlangInteger) =>
      h.assert_true(kind.name == "put")
      h.assert_true(key.value == "k")
      h.assert_true(value.value == 7)
    else h.fail("a three element tuple binds as a triple")
    end

class iso _TripleAcceptsNoOtherShapeTest is UnitTest
  fun name(): String => "a triple is a three element tuple and nothing else"

  fun apply(h: TestHelper) =>
    h.assert_false(
      _binds(ErlangTuple([ErlangAtom("a"); ErlangAtom("b")])),
      "a two element tuple is not a triple")
    h.assert_false(_binds(ErlangList([])), "a list is not a triple")

  fun _binds(term: ErlangTerm): Bool =>
    match ErlangShapes.triple(term)
    | (let first: ErlangTerm, let second: ErlangTerm, let third: ErlangTerm) =>
      true
    else false
    end

class iso _AtomIsRecognisedByNameTest is UnitTest
  fun name(): String => "an atom is recognised by name and no other term is"

  fun apply(h: TestHelper) =>
    h.assert_true(ErlangTerms.is_atom(ErlangAtom("reply"), "reply"))
    h.assert_false(ErlangTerms.is_atom(ErlangAtom("reply"), "replyx"))
    h.assert_false(
      ErlangTerms.is_atom(ErlangBinary("reply"), "reply"),
      "a binary with the same bytes is not the atom")

class iso _NoTermAtAllIsNoShapeTest is UnitTest
  fun name(): String => "a message that did not decode has no shape"

  fun apply(h: TestHelper) =>
    match ErlangShapes.pair(None)
    | (let left: ErlangTerm, let right: ErlangTerm) =>
      h.fail("nothing decoded is not a pair")
    else None
    end

    match ErlangShapes.triple(None)
    | (let first: ErlangTerm, let second: ErlangTerm, let third: ErlangTerm) =>
      h.fail("nothing decoded is not a triple")
    else None
    end
