use "pony_test"

use "path:../"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    EncodingDecodingTest.tests(test)
    TermRoundtripTest.tests(test)
    TermPrinterTest.tests(test)
    TermValueTest.tests(test)
    TermAccessTest.tests(test)
    TermShapeTest.tests(test)
    ValueGetterTest.tests(test)
    BigIntegerTest.tests(test)
    ErlInterfaceTest.tests(test)
    NodeConcurrencyTest.tests(test)
    ResourceLifecycleTest.tests(test)
