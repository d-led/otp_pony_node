"""
The Erlang term model.

Every term that can travel over the distribution protocol has a class here,
so a decoder can hand back a value that can be pattern matched and a printer
can render it back to Erlang syntax.  `ErlangOpaque` carries the encoded bytes
of the few types that cannot be modelled as ordinary values (funs, exports and
anything a future OTP invents) so decoding never loses data.
"""

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

class val ErlangAtom
  """An atom, e.g. `ok` or `'a name with spaces'`."""
  let name: String

  new val create(name': String) =>
    name = name'

class val ErlangInteger
  """An integer that fits into 64 bits."""
  let value: I64

  new val create(value': I64) =>
    value = value'

class val ErlangFloat
  """A floating point number."""
  let value: F64

  new val create(value': F64) =>
    value = value'

class val ErlangBinary
  """A binary: raw bytes, which may contain NUL bytes."""
  let value: String

  new val create(value': String) =>
    value = value'

class val ErlangBitstring
  """
  A bitstring that is not a whole number of bytes.

  `used_bits_in_last_byte` is 1..7 for a partial bitstring.  Only those bits
  travel: the unused low bits of the last byte are cleared on construction, so
  a value always matches what comes back off the wire.

  A bitstring that *is* a whole number of bytes is an `ErlangBinary` on the
  wire, and decodes as one.
  """
  let value: String
  let used_bits_in_last_byte: U8

  new val create(value': String, used_bits_in_last_byte': U8 = 8) =>
    let used: U8 =
      if used_bits_in_last_byte' == 0 then 8 else used_bits_in_last_byte' end
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

class val ErlangString
  """
  A string, i.e. a list of bytes in the external format (`"abc"` in Erlang).

  The bytes are kept as they are: this is not a unicode abstraction.
  """
  let value: String

  new val create(value': String) =>
    value = value'

class val ErlangList
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

class val ErlangTuple
  """A tuple of fixed arity."""
  let elements: Array[ErlangTerm] val

  new val create(elements': Array[ErlangTerm] val) =>
    elements = elements'

  fun size(): USize => elements.size()

class val ErlangMap
  """
  A map, kept as key/value pairs in the order they were encoded.
  """
  let pairs: Array[(ErlangTerm, ErlangTerm)] val

  new val create(pairs': Array[(ErlangTerm, ErlangTerm)] val) =>
    pairs = pairs'

  fun size(): USize => pairs.size()

class val ErlangPort
  """A port identifier."""
  let node: String
  let id: U64
  let creation: U32

  new val create(node': String, id': U64, creation': U32 = 0) =>
    node = node'
    id = id'
    creation = creation'

class val ErlangReference
  """A reference: a node, up to five words and a creation number."""
  let node: String
  let ids: Array[U32] val
  let creation: U32

  new val create(node': String, ids': Array[U32] val, creation': U32 = 0) =>
    node = node'
    ids = ids'
    creation = creation'

  fun size(): USize => ids.size()

class val ErlangOpaque
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

primitive ErlangTerms
  """
  Structural equality for terms.

  `ErlangMap` compares pairs in order, because a map keeps the order it was
  encoded in; two maps with the same entries in a different order are not
  equal here.
  """

  fun eq(a: ErlangTerm, b: ErlangTerm): Bool =>
    match (a, b)
    | (let x: ErlangAtom, let y: ErlangAtom) => x.name == y.name
    | (let x: ErlangInteger, let y: ErlangInteger) => x.value == y.value
    | (let x: ErlangBigInteger, let y: ErlangBigInteger) =>
      (x.negative == y.negative) and _bytes_eq(x.digits, y.digits)
    | (let x: ErlangFloat, let y: ErlangFloat) => x.value == y.value
    | (let x: ErlangBinary, let y: ErlangBinary) => x.value == y.value
    | (let x: ErlangBitstring, let y: ErlangBitstring) =>
      (x.used_bits_in_last_byte == y.used_bits_in_last_byte)
        and (x.value == y.value)
    | (let x: ErlangString, let y: ErlangString) => x.value == y.value
    | (let x: ErlangTuple, let y: ErlangTuple) =>
      _terms_eq(x.elements, y.elements)
    | (let x: ErlangList, let y: ErlangList) =>
      _terms_eq(x.elements, y.elements) and _tail_eq(x.tail, y.tail)
    | (let x: ErlangMap, let y: ErlangMap) => _pairs_eq(x.pairs, y.pairs)
    | (let x: ErlangPid, let y: ErlangPid) => x.eq(y)
    | (let x: ErlangPort, let y: ErlangPort) =>
      (x.node == y.node) and (x.id == y.id) and (x.creation == y.creation)
    | (let x: ErlangReference, let y: ErlangReference) =>
      (x.node == y.node)
        and (x.creation == y.creation)
        and _words_eq(x.ids, y.ids)
    | (let x: ErlangOpaque, let y: ErlangOpaque) =>
      (x.type_name == y.type_name) and (x.raw == y.raw)
    else false
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
    let others = b.values()
    for (key, value) in a.values() do
      try
        (let other_key, let other_value) = others.next()?
        if not (eq(key, other_key) and eq(value, other_value)) then
          return false
        end
      else
        return false
      end
    end
    true

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
