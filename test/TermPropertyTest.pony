use "pony_test"

use "../erl_interface_pony"

class TermPropertyTest is TestList
  fun name(): String => "generated terms survive the external format"

  fun tag tests(test: PonyTest) =>
    test.property[ErlangTerm](_TermProperty)

class iso _TermProperty is Property[ErlangTerm]
  """
  A generated term, encoded and decoded again, is the term it started as.
  """

  fun name(): String => "a generated term decodes back to itself"

  fun params(): PropertyParams =>
    // A fixed seed keeps a failure reproducible; the count is enough to reach
    // every branch of the generator several times over.
    PropertyParams(300, 20_261_102)

  fun gen(): Generator[ErlangTerm] => _TermGen.at(3)

  fun ref property(term: ErlangTerm, h: PropertyHelper) ? =>
    h.collect(_Roundtrip.type_name(term))

    let message = EMessage.begin()
    message.encode(term)?

    match ErlangTermDecoder.decode(message)
    | let decoded: ErlangTerm =>
      if not ErlangTerms.eq(term, decoded) then
        h.fail("wrote " + _Roundtrip.describe(term) + ", read back "
          + _Roundtrip.describe(decoded))
      end
    else
      h.fail("wrote " + _Roundtrip.describe(term) + ", which did not decode")
    end

primitive _TermGen
  """
  Terms to round trip, built from the shapes the external format keeps apart: a
  bitstring with a partial last byte, an improper list whose tail is not a
  list, a map whose keys are distinct, and a wide integer whose magnitude no
  sixty-four bit integer holds.
  """

  fun at(depth: USize): Generator[ErlangTerm] =>
    if depth == 0 then
      leaves()
    else
      Generators.frequency[ErlangTerm]([
        as WeightedGenerator[ErlangTerm]:
        (4, leaves())
        (2, _list(at(depth - 1)))
        (2, _tuple(at(depth - 1)))
        (1, _map_by_index(at(depth - 1)))
        (1, _map_by_atom(at(depth - 1)))
      ])
    end

  fun leaves(): Generator[ErlangTerm] =>
    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (3, _atom())
      (3, _integer())
      (1, _wide_integer(false))
      (1, _wide_integer(true))
      (2, _float())
      (2, _binary())
      (1, _bitstring())
      (1, _string())
      (1, _process())
    ])

  fun _frozen(items: Array[ErlangTerm]): Array[ErlangTerm] val =>
    let built: Array[ErlangTerm] trn = recover trn Array[ErlangTerm] end
    for item in items.values() do built.push(item) end
    consume built

  fun _frozen_bytes(digits: Array[U8]): Array[U8] val =>
    let built: Array[U8] trn = recover trn Array[U8] end
    for digit in digits.values() do built.push(digit) end
    consume built

  fun _atom(): Generator[ErlangTerm] =>
    Generators.ascii_letters(0, 8)
      .map[ErlangTerm]({(name: String): ErlangTerm => ErlangAtom(name)})

  fun _integer(): Generator[ErlangTerm] =>
    let edges: Array[I64] val = [
      I64(0)
      I64(1)
      I64(-1)
      I64(127)
      I64(-128)
      I64(32_767)
      I64(2_147_483_647)
      I64(-2_147_483_648)
      I64.max_value()
      I64.min_value()
    ]

    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (6, Generators.i64()
        .map[ErlangTerm]({(value: I64): ErlangTerm => ErlangInteger(value)}))
      (2, Generators.one_of[I64](edges)
        .map[ErlangTerm]({(value: box->I64): ErlangTerm =>
          ErlangInteger(value)}))
    ])

  fun _wide_integer(negative: Bool): Generator[ErlangTerm] =>
    // Nine digits is a magnitude no sixty-four bit integer holds, so the value
    // comes back as a wide integer and not as an integer that fits.
    Generators.array_of[U8](Generators.u8(1, 255), 9, 12)
      .map[ErlangTerm]({(digits: Array[U8]): ErlangTerm =>
        ErlangBigInteger(negative, _TermGen._frozen_bytes(digits))})

  fun _float(): Generator[ErlangTerm] =>
    let edges: Array[U64] val = [
      0x0000_0000_0000_0000  // zero
      0x8000_0000_0000_0000  // minus zero
      0x7FF0_0000_0000_0000  // positive infinity
      0xFFF0_0000_0000_0000  // negative infinity
      0x7FF8_0000_0000_0000  // not a number
      0x0000_0000_0000_0001  // the smallest denormal
      0x7FEF_FFFF_FFFF_FFFF  // the largest finite value
    ]

    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (6, Generators.f64(-1.0e300, 1.0e300)
        .map[ErlangTerm]({(value: F64): ErlangTerm => ErlangFloat(value)}))
      (2, Generators.one_of[U64](edges)
        .map[ErlangTerm]({(bits: box->U64): ErlangTerm =>
          ErlangFloat(F64.from_bits(bits))}))
    ])

  fun _binary(): Generator[ErlangTerm] =>
    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (4, _bytes(0, 8))
      (2, _bytes(0, 40))
      (1, _bytes(250, 300))
    ])

  fun _bytes(from: USize, to: USize): Generator[ErlangTerm] =>
    Generators.byte_string(Generators.u8(), from, to)
      .map[ErlangTerm]({(value: String): ErlangTerm => ErlangBinary(value)})

  fun _bitstring(): Generator[ErlangTerm] =>
    // Bits the last byte does not fill are the only bitstrings the format
    // keeps apart from a binary.
    Generators.zip2[String, U8](Generators.byte_string(Generators.u8(), 1, 4),
      Generators.u8(1, 7))
      .map[ErlangTerm]({(both: (String, U8)): ErlangTerm =>
        (let bytes, let used) = both
        ErlangBitstring(bytes, used)})

  fun _string(): Generator[ErlangTerm] =>
    Generators.ascii_printable(1, 10)
      .map[ErlangTerm]({(value: String): ErlangTerm => ErlangString(value)})

  fun _process(): Generator[ErlangTerm] =>
    // A pid number, a port number and a reference's words are drawn within
    // what the format holds, so the values generated are the ones a peer can
    // write down again.
    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (1, Generators.zip2[String, U32](
          Generators.ascii_letters(1, 6), Generators.u32(1, 10_000))
        .map[ErlangTerm]({(both: (String, U32)): ErlangTerm =>
          (let node, let num) = both
          ErlangPid(node, num, 0, 0)}))
      (1, Generators.zip2[String, U64](
          Generators.ascii_letters(1, 6), Generators.u64(0, 268_435_455))
        .map[ErlangTerm]({(both: (String, U64)): ErlangTerm =>
          (let node, let id) = both
          ErlangPort(node, id, 0)}))
      (1, Generators.zip2[String, USize](
          Generators.ascii_letters(1, 6), Generators.usize(1, 5))
        .map[ErlangTerm]({(both: (String, USize)): ErlangTerm =>
          (let node, let words) = both
          let ids: Array[U32] trn = recover trn Array[U32] end
          var i: USize = 0
          while i < words do
            ids.push((i + 1).u32())
            i = i + 1
          end
          ErlangReference(node, consume ids, 0)}))
    ])

  fun _list(item: Generator[ErlangTerm]): Generator[ErlangTerm] =>
    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (3, Generators.array_of[ErlangTerm](item, 0, 3)
        .map[ErlangTerm]({(items: Array[ErlangTerm]): ErlangTerm =>
          ErlangList(_TermGen._frozen(items))}))
      // A tail that is not a list, otherwise the format writes one longer list
      // and the tail is not a separate value any more.
      (1, Generators.zip2[Array[ErlangTerm], ErlangTerm](
          Generators.array_of[ErlangTerm](item, 1, 3), _tail())
        .map[ErlangTerm]({(both: (Array[ErlangTerm], ErlangTerm)): ErlangTerm =>
          (let items, let tail) = both
          ErlangList(_TermGen._frozen(items), tail)}))
    ])

  fun _tail(): Generator[ErlangTerm] =>
    Generators.frequency[ErlangTerm]([
      as WeightedGenerator[ErlangTerm]:
      (1, _atom())
      (1, _integer())
      (1, _binary())
    ])

  fun _tuple(item: Generator[ErlangTerm]): Generator[ErlangTerm] =>
    Generators.array_of[ErlangTerm](item, 0, 3)
      .map[ErlangTerm]({(items: Array[ErlangTerm]): ErlangTerm =>
        ErlangTuple(_TermGen._frozen(items))})

  fun _map_by_index(item: Generator[ErlangTerm]): Generator[ErlangTerm] =>
    // A map cannot hold one key twice, so the keys are counted up instead of
    // drawn.
    Generators.array_of[ErlangTerm](item, 0, 3)
      .map[ErlangTerm]({(values: Array[ErlangTerm]): ErlangTerm =>
        _TermGen._map(values, {(index: USize): ErlangTerm =>
          ErlangInteger(index.i64())})})

  fun _map_by_atom(item: Generator[ErlangTerm]): Generator[ErlangTerm] =>
    Generators.array_of[ErlangTerm](item, 0, 3)
      .map[ErlangTerm]({(values: Array[ErlangTerm]): ErlangTerm =>
        _TermGen._map(values, {(index: USize): ErlangTerm =>
          ErlangAtom("k" + index.string())})})

  fun _map(values: Array[ErlangTerm], key: {(USize): ErlangTerm} box)
    : ErlangTerm
  =>
    let pairs: Array[(ErlangTerm, ErlangTerm)] trn =
      recover trn Array[(ErlangTerm, ErlangTerm)] end
    var index: USize = 0
    for value in values.values() do
      pairs.push((key(index), value))
      index = index + 1
    end
    ErlangMap(consume pairs)
