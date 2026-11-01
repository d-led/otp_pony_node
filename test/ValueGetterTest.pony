use "pony_test"

use "../erl_interface_pony"

class ValueGetterTest is TestList
  fun name(): String => "taking a value out of a term"

  fun tag tests(test: PonyTest) =>
    test(_AtomGivesItsNameTest)
    test(_BinaryGivesItsBytesTest)
    test(_StringGivesItsCharsTest)
    test(_IntegerGivesItsValueTest)
    test(_FloatGivesItsValueTest)
    test(_PidGivesItselfTest)
    test(_OtherKindsGiveNothingTest)
    test(_BigIntegersDoNotNarrowTest)
    test(_LookupAndReadInOneExpressionTest)

class iso _AtomGivesItsNameTest is UnitTest
  fun name(): String => "an atom gives its name"

  fun apply(h: TestHelper) =>
    match ErlangValues.atom_name(ErlangAtom("reply"))
    | let found: String => h.assert_eq[String]("reply", found)
    else h.fail("an atom gives its name")
    end

class iso _BinaryGivesItsBytesTest is UnitTest
  fun name(): String => "a binary gives its bytes"

  fun apply(h: TestHelper) =>
    match ErlangValues.bytes(ErlangBinary("hi\0there"))
    | let bytes: String => h.assert_eq[String]("hi\0there", bytes)
    else h.fail("a binary gives its bytes")
    end

class iso _StringGivesItsCharsTest is UnitTest
  fun name(): String => "a string gives its chars"

  fun apply(h: TestHelper) =>
    match ErlangValues.chars(ErlangString("abc"))
    | let chars: String => h.assert_eq[String]("abc", chars)
    else h.fail("a string gives its chars")
    end

class iso _IntegerGivesItsValueTest is UnitTest
  fun name(): String => "an integer gives its value"

  fun apply(h: TestHelper) =>
    match ErlangValues.integer(ErlangInteger(-7))
    | let value: I64 => h.assert_eq[I64](-7, value)
    else h.fail("an integer gives its value")
    end

class iso _FloatGivesItsValueTest is UnitTest
  fun name(): String => "a float gives its value"

  fun apply(h: TestHelper) =>
    match ErlangValues.float(ErlangFloat(2.5))
    | let value: F64 => h.assert_eq[F64](2.5, value)
    else h.fail("a float gives its value")
    end

class iso _PidGivesItselfTest is UnitTest
  fun name(): String => "a pid gives the pid"

  fun apply(h: TestHelper) =>
    match ErlangValues.pid(ErlangPid("n@localhost", 1, 2, 3))
    | let found: ErlangPid =>
      h.assert_eq[String]("<1.2.3@n@localhost>", found.string())
    else h.fail("a pid gives the pid")
    end

class iso _OtherKindsGiveNothingTest is UnitTest
  fun name(): String => "a term of another kind gives nothing"

  fun apply(h: TestHelper) =>
    h.assert_true(ErlangValues.integer(ErlangBinary("5000")) is None,
      "a binary is not an integer")
    h.assert_true(ErlangValues.bytes(ErlangInteger(1)) is None)
    h.assert_true(ErlangValues.atom_name(ErlangString("reply")) is None,
      "a charlist with the same bytes is not an atom")
    h.assert_true(ErlangValues.float(ErlangInteger(1)) is None,
      "an integer is not a float")
    h.assert_true(ErlangValues.pid(ErlangAtom("reply")) is None)

class iso _BigIntegersDoNotNarrowTest is UnitTest
  fun name(): String => "a wide integer does not narrow to 64 bits"

  fun apply(h: TestHelper) =>
    let wide = ErlangBigInteger(true, [1; 0; 0; 0; 0; 0; 0; 0; 0; 0])

    h.assert_true(ErlangValues.integer(wide) is None,
      "a wide integer answers nothing rather than losing digits")

class iso _LookupAndReadInOneExpressionTest is UnitTest
  fun name(): String => "a lookup and the read that follows are one expression"

  fun apply(h: TestHelper) =>
    let config = ErlangMap(
      [ (ErlangBinary("timeout"), ErlangInteger(5_000))
        (ErlangBinary("name"), ErlangBinary("pony")) ])

    h.assert_eq[I64](5_000, _timeout_of(config, "timeout"))
    h.assert_eq[I64](250, _timeout_of(config, "missing"),
      "an absent key takes the default")
    h.assert_eq[I64](250, _timeout_of(config, "name"),
      "a value of another kind takes the default")

  fun _timeout_of(config: ErlangMap, key: String): I64 =>
    match ErlangValues.integer(config.get(ErlangBinary(key)))
    | let timeout: I64 => timeout
    | None => 250
    end
