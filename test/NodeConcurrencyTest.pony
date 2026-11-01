use "collections"
use "pony_test"

use "../erl_interface_pony"

class NodeConcurrencyTest is TestList
  fun name(): String => "nodes made at the same time"

  fun tag tests(test: PonyTest) =>
    test(_NodesCanBeMadeAtOnceTest)

class iso _NodesCanBeMadeAtOnceTest is UnitTest
  """
  erl_interface keeps process globals and initialises them on first use.  Two
  actors creating a node at the same moment met in its host name lookup, which
  left one of them waiting for a lock nothing would release.
  """

  fun name(): String => "several nodes can be created at the same time"

  fun apply(h: TestHelper) =>
    h.long_test(20_000_000_000)

    let made = _NodeMaking(h, _how_many())
    for index in Range[USize](0, _how_many()) do
      _NodeMaker(made, index).create_node()
    end

  fun _how_many(): USize => 8

actor _NodeMaker
  let _made: _NodeMaking
  let _index: USize

  new create(made: _NodeMaking, index: USize) =>
    _made = made
    _index = index

  be create_node() =>
    let node = EInterface("pony_test_node_" + _index.string(), "cookie")
    _made.made(node.this_alivename())

actor _NodeMaking
  let _h: TestHelper
  var _left: USize

  new create(h: TestHelper, expected: USize) =>
    _h = h
    _left = expected

  be made(alive_name: String) =>
    if alive_name.size() == 0 then
      _h.fail("a node reports the alive name it was created with")
    end

    _left = _left - 1
    if _left == 0 then _h.complete(true) end
