use "pony_test"

use "path:../"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None
  
  fun tag tests(test: PonyTest) =>
    EncodingDecodingTest.tests(test)
