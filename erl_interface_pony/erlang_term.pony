"""
The Erlang term model.

Every term that can travel over the distribution protocol has a class here,
so a decoder can hand back a value that can be pattern matched and a printer
can render it back to Erlang syntax.  `ErlangOpaque` carries the encoded bytes
of the few types that cannot be modelled as ordinary values (funs, exports and
anything a future OTP invents) so decoding never loses data.

All of them are value classes: `==` compares contents, `hash()` agrees with
`==`, and instances can be used as `Map` and `Set` keys.
"""

use "collections"

type ErlangTerm is
  ( ErlangAtom
  | ErlangInteger
  | ErlangBigInteger
  | ErlangFloat
  | ErlangBinary
  | ErlangBitstring
  | ErlangString
  | ErlangList
  | ErlangTuple
  | ErlangMap
  | ErlangPid
  | ErlangPort
  | ErlangReference
  | ErlangOpaque )

class val ErlangAtom is (Equatable[ErlangAtom] & Hashable)
  """An atom, e.g. `ok` or `'a name with spaces'`."""
  let name: String

  new val create(name': String) =>
    name = name'

  fun eq(that: box->ErlangAtom): Bool =>
    name == that.name

  fun hash(): USize =>
    name.hash()

class val ErlangInteger is (Equatable[ErlangInteger] & Hashable)
  """An integer that fits into 64 bits."""
  let value: I64

  new val create(value': I64) =>
    value = value'

  fun eq(that: box->ErlangInteger): Bool =>
    value == that.value

  fun hash(): USize =>
    value.hash()

class val ErlangFloat is (Equatable[ErlangFloat] & Hashable)
  """
  A floating point number.

  Floats compare bit for bit, as Erlang's `=:=` does: `0.0` and `-0.0` are
  different values, and a NaN equals itself.  Comparing the bits is also what
  keeps `==` and `hash()` in agreement, which a `Map` or `Set` key needs.
  """
  let value: F64

  new val create(value': F64) =>
    value = value'

  fun eq(that: box->ErlangFloat): Bool =>
    value.bits() == that.value.bits()

  fun hash(): USize =>
    value.bits().hash()

class val ErlangBinary is (Equatable[ErlangBinary] & Hashable)
  """A binary: raw bytes, which may contain NUL bytes."""
  let value: String

  new val create(value': String) =>
    value = value'

  fun eq(that: box->ErlangBinary): Bool =>
    value == that.value

  fun hash(): USize =>
    value.hash()

class val ErlangBitstring is (Equatable[ErlangBitstring] & Hashable)
  """
  A bitstring that is not a whole number of bytes.

  `used_bits_in_last_byte` is 1..7 for a partial bitstring.  Only those bits
  travel: the unused low bits of the last byte are cleared on construction, so
  a value always matches what comes back off the wire.

  A bitstring that *is* a whole number of bytes is an `ErlangBinary` on the
  wire, and decodes as one.  An empty value has no last byte to count, so it is
  stored as a whole byte too.
  """
  let value: String
  let used_bits_in_last_byte: U8

  new val create(value': String, used_bits_in_last_byte': U8 = 8) =>
    let used: U8 =
      if (value'.size() == 0) or (used_bits_in_last_byte' == 0) then
        8
      else
        used_bits_in_last_byte'
      end
    used_bits_in_last_byte = used

    if (used >= 8) or (value'.size() == 0) then
      value = value'
    else
      let keep: U8 = 0xFF << (8 - used)
      let masked: Array[U8] trn = recover trn Array[U8] end
      var index: USize = 0
      let last: USize = value'.size() - 1
      for byte in value'.values() do
        if index == last then
          masked.push(byte and keep)
        else
          masked.push(byte)
        end
        index = index + 1
      end
      value = String.from_array(consume masked)
    end

  fun eq(that: box->ErlangBitstring): Bool =>
    (value == that.value)
      and (used_bits_in_last_byte == that.used_bits_in_last_byte)

  fun hash(): USize =>
    value.hash() xor (used_bits_in_last_byte.hash() << 1)

class val ErlangString is (Equatable[ErlangString] & Hashable)
  """
  A string, i.e. a list of bytes in the external format (`"abc"` in Erlang).

  The bytes are kept as they are: this is not a unicode abstraction.
  """
  let value: String

  new val create(value': String) =>
    value = value'

  fun eq(that: box->ErlangString): Bool =>
    value == that.value

  fun hash(): USize =>
    value.hash()

class val ErlangList is (Equatable[ErlangList] & Hashable)
  """
  A list, proper when `tail` is `None`, improper otherwise.

  `[1, 2]` is `ErlangList([1, 2])`, `[1 | 2]` is
  `ErlangList([1], 2)`.  The empty list has no elements and no tail.
  """
  let elements: Array[ErlangTerm] val
  let tail: (ErlangTerm | None)

  new val create(elements': Array[ErlangTerm] val,
    tail': (ErlangTerm | None) = None)
  =>
    elements = elements'
    tail = tail'

  fun is_proper(): Bool => tail is None

  fun size(): USize => elements.size()

  fun eq(that: box->ErlangList): Bool =>
    ErlangTerms._terms_eq(elements, that.elements)
      and ErlangTerms._tail_eq(tail, that.tail)

  fun hash(): USize =>
    let combined = (ErlangTerms._terms_hash(elements) * 31) + 3
    match tail
    | let term: ErlangTerm => (combined * 31) + ErlangTerms.hash(term)
    else combined
    end

class val ErlangTuple is (Equatable[ErlangTuple] & Hashable)
  """A tuple of fixed arity."""
  let elements: Array[ErlangTerm] val

  new val create(elements': Array[ErlangTerm] val) =>
    elements = elements'

  fun size(): USize => elements.size()

  fun eq(that: box->ErlangTuple): Bool =>
    ErlangTerms._terms_eq(elements, that.elements)

  fun hash(): USize =>
    ErlangTerms._terms_hash(elements) + 5

class val ErlangMap is (Equatable[ErlangMap] & Hashable)
  """
  A map, kept as key/value pairs in the order they were encoded.

  Equality ignores that order, as Erlang's does: two maps with the same pairs
  are the same value however they were written, and they hash alike.  The
  order is kept so that printing a map shows the order it arrived in.
  """
  let pairs: Array[(ErlangTerm, ErlangTerm)] val

  new val create(pairs': Array[(ErlangTerm, ErlangTerm)] val) =>
    pairs = pairs'

  fun size(): USize => pairs.size()

  fun eq(that: box->ErlangMap): Bool =>
    ErlangTerms._pairs_eq(pairs, that.pairs)

  fun hash(): USize =>
    var combined: USize = 7
    for (key, value) in pairs.values() do
      let pair = (ErlangTerms.hash(key) * 31) + ErlangTerms.hash(value)
      combined = combined + pair
    end
    combined

class val ErlangPort is (Equatable[ErlangPort] & Hashable)
  """A port identifier."""
  let node: String
  let id: U64
  let creation: U32

  new val create(node': String, id': U64, creation': U32 = 0) =>
    node = node'
    id = id'
    creation = creation'

  fun eq(that: box->ErlangPort): Bool =>
    (node == that.node) and (id == that.id) and (creation == that.creation)

  fun hash(): USize =>
    node.hash() xor (id.hash() << 1) xor (creation.hash() << 2)

class val ErlangReference is (Equatable[ErlangReference] & Hashable)
  """A reference: a node, up to five words and a creation number."""
  let node: String
  let ids: Array[U32] val
  let creation: U32

  new val create(node': String, ids': Array[U32] val, creation': U32 = 0) =>
    node = node'
    ids = ids'
    creation = creation'

  fun size(): USize => ids.size()

  fun eq(that: box->ErlangReference): Bool =>
    (node == that.node)
      and (creation == that.creation)
      and ErlangTerms._words_eq(ids, that.ids)

  fun hash(): USize =>
    node.hash() xor (ErlangTerms._words_hash(ids) << 1)
      xor (creation.hash() << 2)

class val ErlangOpaque is (Equatable[ErlangOpaque] & Hashable)
  """
  A term this library does not model, kept as its encoded bytes.

  Funs, exports and any term type a newer OTP introduces arrive this way;
  they can be forwarded unchanged but not looked into.
  """
  let type_name: String
  let raw: String

  new val create(type_name': String, raw': String) =>
    type_name = type_name'
    raw = raw'

  fun eq(that: box->ErlangOpaque): Bool =>
    (type_name == that.type_name) and (raw == that.raw)

  fun hash(): USize =>
    type_name.hash() xor (raw.hash() << 1)

primitive ErlangTerms
  """
  Equality and hashing for a value whose static type is the `ErlangTerm` union.

  Each term class compares with `==`.  `ErlangTerm` is a union of classes whose
  `eq` methods take different types, so `==` does not apply to the union.  A
  value known only as an `ErlangTerm` compares through `eq` and hashes through
  `hash`.
  """

  fun eq(a: ErlangTerm, b: ErlangTerm): Bool =>
    match (a, b)
    | (let x: ErlangAtom, let y: ErlangAtom) => x == y
    | (let x: ErlangInteger, let y: ErlangInteger) => x == y
    | (let x: ErlangBigInteger, let y: ErlangBigInteger) => x == y
    | (let x: ErlangFloat, let y: ErlangFloat) => x == y
    | (let x: ErlangBinary, let y: ErlangBinary) => x == y
    | (let x: ErlangBitstring, let y: ErlangBitstring) => x == y
    | (let x: ErlangString, let y: ErlangString) => x == y
    | (let x: ErlangTuple, let y: ErlangTuple) => x == y
    | (let x: ErlangList, let y: ErlangList) => x == y
    | (let x: ErlangMap, let y: ErlangMap) => x == y
    | (let x: ErlangPid, let y: ErlangPid) => x == y
    | (let x: ErlangPort, let y: ErlangPort) => x == y
    | (let x: ErlangReference, let y: ErlangReference) => x == y
    | (let x: ErlangOpaque, let y: ErlangOpaque) => x == y
    else false
    end

  fun hash(term: ErlangTerm): USize =>
    match term
    | let t: ErlangAtom => t.hash()
    | let t: ErlangInteger => t.hash()
    | let t: ErlangBigInteger => t.hash()
    | let t: ErlangFloat => t.hash()
    | let t: ErlangBinary => t.hash()
    | let t: ErlangBitstring => t.hash()
    | let t: ErlangString => t.hash()
    | let t: ErlangTuple => t.hash()
    | let t: ErlangList => t.hash()
    | let t: ErlangMap => t.hash()
    | let t: ErlangPid => t.hash()
    | let t: ErlangPort => t.hash()
    | let t: ErlangReference => t.hash()
    | let t: ErlangOpaque => t.hash()
    end

  fun _terms_eq(a: Array[ErlangTerm] val, b: Array[ErlangTerm] val): Bool =>
    if a.size() != b.size() then return false end
    let others = b.values()
    for term in a.values() do
      try
        if not eq(term, others.next()?) then return false end
      else
        return false
      end
    end
    true

  fun _terms_hash(elements: Array[ErlangTerm] val): USize =>
    var combined: USize = 17
    for element in elements.values() do
      combined = (combined * 31) + hash(element)
    end
    combined

  fun _tail_eq(a: (ErlangTerm | None), b: (ErlangTerm | None)): Bool =>
    match (a, b)
    | (None, None) => true
    | (let x: ErlangTerm, let y: ErlangTerm) => eq(x, y)
    else false
    end

  fun _pairs_eq(a: Array[(ErlangTerm, ErlangTerm)] val,
    b: Array[(ErlangTerm, ErlangTerm)] val)
    : Bool
  =>
    if a.size() != b.size() then return false end

    // Each pair of `a` takes one pair of `b` with it, so repeated pairs are
    // counted rather than matched twice against the same partner.
    let unmatched: Array[(ErlangTerm, ErlangTerm)] trn =
      recover trn Array[(ErlangTerm, ErlangTerm)] end
    for pair in b.values() do
      unmatched.push(pair)
    end

    for (key, value) in a.values() do
      var index: USize = 0
      var found = false
      try
        while (index < unmatched.size()) and not found do
          (let other_key, let other_value) = unmatched(index)?
          if eq(key, other_key) and eq(value, other_value) then
            unmatched.delete(index)?
            found = true
          else
            index = index + 1
          end
        end
      end
      if not found then return false end
    end
    true

  fun _canonical_digits(digits: Array[U8] val, negative: Bool)
    : (Array[U8] val, Bool)
  =>
    var last: USize = digits.size()
    while (last > 0) and (try digits(last - 1)? == 0 else false end) do
      last = last - 1
    end

    if last == 0 then
      (recover Array[U8] end, false)
    elseif last == digits.size() then
      (digits, negative)
    else
      (recover digits.slice(0, last) end, negative)
    end

  fun _words_eq(a: Array[U32] val, b: Array[U32] val): Bool =>
    if a.size() != b.size() then return false end
    let others = b.values()
    for word in a.values() do
      try
        if word != others.next()? then return false end
      else
        return false
      end
    end
    true

  fun _words_hash(words: Array[U32] val): USize =>
    var combined: USize = 11
    for word in words.values() do
      combined = (combined * 31) + word.hash()
    end
    combined

  fun _bytes_eq(a: Array[U8] val, b: Array[U8] val): Bool =>
    if a.size() != b.size() then return false end
    let others = b.values()
    for byte in a.values() do
      try
        if byte != others.next()? then return false end
      else
        return false
      end
    end
    true

  fun _bytes_hash(bytes: Array[U8] val): USize =>
    var combined: USize = 13
    for byte in bytes.values() do
      combined = (combined * 31) + byte.hash()
    end
    combined
