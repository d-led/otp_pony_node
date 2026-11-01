use "pony_test"

use "../erl_interface_pony"

class TermPrinterTest is TestList
  fun name(): String => "printing terms the way Erlang writes them"

  fun tag tests(test: PonyTest) =>
    test(_AtomPrintingTest)
    test(_ContainerPrintingTest)
    test(_BinaryPrintingTest)
    test(_NumberPrintingTest)
    test(_ProcessPrintingTest)

class iso _AtomPrintingTest is UnitTest
  fun name(): String => "atoms are quoted only when they have to be"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("ok", ErlangTermPrinter.string(ErlangAtom("ok")))
    h.assert_eq[String]("'a test'",
      ErlangTermPrinter.string(ErlangAtom("a test")))
    h.assert_eq[String]("'fun'",
      ErlangTermPrinter.string(ErlangAtom("fun")),
      "reserved words need quoting")
    h.assert_eq[String]("'Upper'",
      ErlangTermPrinter.string(ErlangAtom("Upper")),
      "atoms start with a lower case letter")

class iso _ContainerPrintingTest is UnitTest
  fun name(): String => "tuples, lists and maps print as they are read"

  fun apply(h: TestHelper) =>
    let numbers: Array[ErlangTerm] val = [ErlangInteger(1); ErlangInteger(2)]
    h.assert_eq[String]("{a, 1}",
      ErlangTermPrinter.string(ErlangTuple([ErlangAtom("a"); ErlangInteger(1)])))

    h.assert_eq[String]("[1, 2]", ErlangTermPrinter.string(ErlangList(numbers)))
    h.assert_eq[String]("[1 | 2]",
      ErlangTermPrinter.string(ErlangList(
        [ErlangInteger(1)], ErlangInteger(2))),
      "an improper list shows its tail")
    h.assert_eq[String]("[]",
      ErlangTermPrinter.string(ErlangList(recover Array[ErlangTerm] end)))

    let pairs: Array[(ErlangTerm, ErlangTerm)] val =
      [(ErlangAtom("a"), ErlangInteger(1))]
    h.assert_eq[String]("#{a => 1}",
      ErlangTermPrinter.string(ErlangMap(pairs)))

class iso _BinaryPrintingTest is UnitTest
  fun name(): String => "binaries are quoted and escaped"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("<<\"hi\">>",
      ErlangTermPrinter.string(ErlangBinary("hi")))
    h.assert_eq[String]("<<\"a\\x00b\">>",
      ErlangTermPrinter.string(ErlangBinary("a\x00b")),
      "bytes that are not printable are escaped")
    h.assert_eq[String]("<<\"a\\\"b\">>",
      ErlangTermPrinter.string(ErlangBinary("a\"b")))

class iso _NumberPrintingTest is UnitTest
  fun name(): String => "numbers keep their kind"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("-42", ErlangTermPrinter.string(ErlangInteger(-42)))
    h.assert_eq[String]("3.0",
      ErlangTermPrinter.string(ErlangFloat(3.0)),
      "a float keeps its decimal point")
    h.assert_eq[String]("1.5", ErlangTermPrinter.string(ErlangFloat(1.5)))
    h.assert_eq[String]("18446744073709551616",
      ErlangTermPrinter.string(
        ErlangBigInteger(false, [0; 0; 0; 0; 0; 0; 0; 0; 1])))

class iso _ProcessPrintingTest is UnitTest
  fun name(): String => "processes print with their node"

  fun apply(h: TestHelper) =>
    h.assert_eq[String]("<1.2.3@me@localhost>",
      ErlangTermPrinter.string(ErlangPid("me@localhost", 1, 2, 3)))
    h.assert_eq[String]("<1.2.3>",
      ErlangTermPrinter.string(ErlangPid("", 1, 2, 3)),
      "a pid without a node says so")
