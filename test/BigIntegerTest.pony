use "pony_test"

use "../erl_interface_pony"

class BigIntegerTest is TestList
  fun name(): String => "big integers read as decimal numbers"

  fun tag tests(test: PonyTest) =>
    test(_SmallValuesTest)
    test(_TwoToTheSixtyFourTest)
    test(_NegativeTest)

class iso _SmallValuesTest is UnitTest
  fun name(): String => "values that fit in a byte"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("0",
      ErlangBigInteger(false, recover Array[U8] end).decimal())
    h.assert_eq[String]("255", ErlangBigInteger(false, [0xff]).decimal())
    h.assert_eq[String]("256", ErlangBigInteger(false, [0x00; 0x01]).decimal(),
      "digits are least significant first")

class iso _TwoToTheSixtyFourTest is UnitTest
  fun name(): String => "a value past the end of a signed 64 bit integer"

  fun apply(h: TestHelper) =>
    let two_to_the_64: Array[U8] val = [0; 0; 0; 0; 0; 0; 0; 0; 1]
    h.assert_eq[String]("18446744073709551616",
      ErlangBigInteger(false, two_to_the_64).decimal())

class iso _NegativeTest is UnitTest
  fun name(): String => "a negative value keeps its sign"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("-18446744073709551616",
      ErlangBigInteger(true, [0; 0; 0; 0; 0; 0; 0; 0; 1]).decimal())
