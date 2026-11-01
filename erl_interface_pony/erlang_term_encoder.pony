primitive ErlangTermEncoder
  """
  Writes a term into an `EMessage`.

  The functions are partial: an encoding can fail when the message cannot grow
  or when a value cannot be represented in the external format.
  """

  fun encode(message: EMessage ref, term: ErlangTerm) ? =>
    match term
    | let t: ErlangAtom => _check(message.encode_atom(t.name))?
    | let t: ErlangInteger => _check(message.encode_int(t.value))?
    | let t: ErlangBigInteger =>
      _check(message.append_raw(_big_integer_bytes(t)))?
    | let t: ErlangFloat => _check(message.encode_double(t.value))?
    | let t: ErlangBinary => _check(message.encode_binary(t.value))?
    | let t: ErlangBitstring =>
      _check(message.encode_bitstring(t.value, t.used_bits_in_last_byte))?
    | let t: ErlangString => _check(message.encode_string(t.value))?
    | let t: ErlangList => _encode_list(message, t)?
    | let t: ErlangTuple => _encode_tuple(message, t)?
    | let t: ErlangMap => _encode_map(message, t)?
    | let t: ErlangPid =>
      _check(message.encode_pid(t.node, t.num, t.serial, t.creation))?
    | let t: ErlangPort =>
      _check(message.encode_port(t.node, t.id, t.creation))?
    | let t: ErlangReference =>
      _check(message.encode_reference(t.node, t.ids, t.creation))?
    | let t: ErlangOpaque => _check(message.append_raw(t.raw))?
    end

  fun _encode_list(message: EMessage ref, list: ErlangList) ? =>
    if list.elements.size() == 0 then
      // An element-less list can only be the tail of an improper list.
      match list.tail
      | let tail: ErlangTerm => encode(message, tail)?
      else _check(message.encode_empty_list())?
      end
      return
    end

    _check(message.encode_list_header(list.elements.size()))?
    for element in list.elements.values() do
      encode(message, element)?
    end

    match list.tail
    | let tail: ErlangTerm => encode(message, tail)?
    else _check(message.encode_empty_list())?
    end

  fun _encode_tuple(message: EMessage ref, tuple: ErlangTuple) ? =>
    _check(message.encode_tuple_header(tuple.elements.size()))?
    for element in tuple.elements.values() do
      encode(message, element)?
    end

  fun _encode_map(message: EMessage ref, map: ErlangMap) ? =>
    _check(message.encode_map_header(map.pairs.size()))?
    for (key, value) in map.pairs.values() do
      encode(message, key)?
      encode(message, value)?
    end

  fun _big_integer_bytes(big: ErlangBigInteger): String val^ =>
    """
    The external format for a big integer: a length, a sign byte and the
    magnitude in base 256, least significant byte first.
    """
    let bytes: Array[U8] trn = recover trn Array[U8] end
    let count = big.digits.size()
    if count <= 255 then
      bytes.push(TermType.small_big().u8())
      bytes.push(count.u8())
    else
      bytes.push(TermType.large_big().u8())
      bytes.push((count >> 24).u8())
      bytes.push((count >> 16).u8())
      bytes.push((count >> 8).u8())
      bytes.push(count.u8())
    end

    bytes.push(if big.negative then 1 else 0 end)
    for digit in big.digits.values() do
      bytes.push(digit)
    end

    String.from_array(consume bytes)

  fun _check(result: I32) ? =>
    if result != 0 then error end
