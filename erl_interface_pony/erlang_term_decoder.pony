primitive ErlangTermDecoder
  """
  Reads terms out of an `EMessage`.

  `decode` is the usual entry point.  Decoding either returns a complete term
  or `None`: a half decoded term is never handed out.
  """

  fun decode(message: EMessage ref): (ErlangTerm | None) =>
    (let term, _) = decode_at(message, message.beginning)
    term

  fun decode_at(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let type_tag, _) = message.type_at(position)

    match type_tag
    | TermType.none() => (None, position)
    | TermType.atom() | TermType.small_atom() | TermType.atom_utf8()
    | TermType.small_atom_utf8()
    =>
      _decode_atom(message, position)
    | TermType.small_integer() | TermType.integer() =>
      _decode_int(message, position)
    | TermType.small_big() | TermType.large_big() =>
      _decode_int_or_big_integer(message, position, type_tag)
    | TermType.float() | TermType.new_float() =>
      _decode_float(message, position)
    | TermType.binary() => _decode_binary(message, position)
    | TermType.bit_binary() => _decode_bitstring(message, position)
    | TermType.string() => _decode_string(message, position)
    | TermType.nil() =>
      (ErlangList(recover Array[ErlangTerm] end), position + 1)
    | TermType.list() => _decode_list(message, position)
    | TermType.small_tuple() | TermType.large_tuple() =>
      _decode_tuple(message, position)
    | TermType.map() => _decode_map(message, position)
    | TermType.pid() | TermType.new_pid() => _decode_pid(message, position)
    | TermType.port() | TermType.new_port() | TermType.v4_port() =>
      _decode_port(message, position)
    | TermType.reference() | TermType.new_reference()
    | TermType.newer_reference()
    =>
      _decode_reference(message, position)
    else
      _decode_verbatim(message, position, type_tag)
    end

  fun _decode_atom(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let name, let next) = message.decode_atom(position)
    match name
    | let atom: String => (ErlangAtom(atom), next)
    else (None, position)
    end

  fun _decode_int(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_int(position)
    match value
    | let integer: I64 => (ErlangInteger(integer), next)
    else (None, position)
    end

  fun _decode_int_or_big_integer(message: EMessage ref, position: I32,
    type_tag: I32)
    : ((ErlangTerm | None), I32)
  =>
    match _decode_int(message, position)
    | (let integer: ErlangInteger, let next: I32) => (integer, next)
    else _decode_big_integer(message, position, type_tag)
    end

  fun _decode_big_integer(message: EMessage ref, position: I32, type_tag: I32)
    : ((ErlangTerm | None), I32)
  =>
    let next = message.skip_term(position)
    if next < 0 then return (None, position) end

    match message.copy_bytes(position, next)
    | let raw: String =>
      try
        let large = type_tag == TermType.large_big()
        let count: USize = if large then
          (raw(1)?.usize() << 24) + (raw(2)?.usize() << 16)
            + (raw(3)?.usize() << 8) + raw(4)?.usize()
        else
          raw(1)?.usize()
        end
        let sign_at: USize = if large then 5 else 2 end
        let negative = raw(sign_at)? != 0

        let digits: Array[U8] trn = recover trn Array[U8] end
        var i: USize = 0
        while i < count do
          digits.push(raw(sign_at + 1 + i)?)
          i = i + 1
        end

        (ErlangBigInteger(negative, consume digits), next)
      else
        (None, position)
      end
    else
      (None, position)
    end

  fun _decode_float(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_double(position)
    match value
    | let number: F64 => (ErlangFloat(number), next)
    else (None, position)
    end

  fun _decode_binary(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_binary(position)
    match value
    | let bytes: String => (ErlangBinary(bytes), next)
    else (None, position)
    end

  fun _decode_bitstring(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_bitstring(position)
    match value
    | let bits: ErlangBitstring => (bits, next)
    else (None, position)
    end

  fun _decode_string(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_string(position)
    match value
    | let text: String => (ErlangString(text), next)
    else (None, position)
    end

  fun _decode_pid(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_pid(position)
    match value
    | let pid: ErlangPid => (pid, next)
    else (None, position)
    end

  fun _decode_port(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_port(position)
    match value
    | let port: ErlangPort => (port, next)
    else (None, position)
    end

  fun _decode_reference(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let value, let next) = message.decode_reference(position)
    match value
    | let reference: ErlangReference => (reference, next)
    else (None, position)
    end

  fun _decode_tuple(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let arity, let after_header) = message.decode_tuple_header(position)
    if not _plausible_arity(message, arity) then return (None, position) end

    let elements: Array[ErlangTerm] trn = recover trn Array[ErlangTerm] end
    var at = after_header
    var i: I32 = 0
    while i < arity do
      (let element, let next) = decode_at(message, at)
      match element
      | let term: ErlangTerm =>
        elements.push(term)
        at = next
      else
        return (None, position)
      end
      i = i + 1
    end

    (ErlangTuple(consume elements), at)

  fun _decode_list(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let arity, let after_header) = message.decode_list_header(position)
    if not _plausible_arity(message, arity) then return (None, position) end

    let elements: Array[ErlangTerm] trn = recover trn Array[ErlangTerm] end
    var at = after_header
    var i: I32 = 0
    while i < arity do
      (let element, let next) = decode_at(message, at)
      match element
      | let term: ErlangTerm =>
        elements.push(term)
        at = next
      else
        return (None, position)
      end
      i = i + 1
    end

    // A list is terminated by the empty list when it is proper.
    (let terminator, _) = message.type_at(at)
    if terminator == TermType.nil() then
      (ErlangList(consume elements), at + 1)
    else
      (let tail, let next) = decode_at(message, at)
      match tail
      | let term: ErlangTerm => (ErlangList(consume elements, term), next)
      else (None, position)
      end
    end

  fun _decode_map(message: EMessage ref, position: I32)
    : ((ErlangTerm | None), I32)
  =>
    (let arity, let after_header) = message.decode_map_header(position)
    if not _plausible_arity(message, arity) then return (None, position) end

    let pairs: Array[(ErlangTerm, ErlangTerm)] trn =
      recover trn Array[(ErlangTerm, ErlangTerm)] end
    var at = after_header
    var i: I32 = 0
    while i < arity do
      (let key, let after_key) = decode_at(message, at)
      match key
      | let key_term: ErlangTerm =>
        (let value, let after_value) = decode_at(message, after_key)
        match value
        | let value_term: ErlangTerm =>
          pairs.push((key_term, value_term))
          at = after_value
        else
          return (None, position)
        end
      else
        return (None, position)
      end
      i = i + 1
    end

    (ErlangMap(consume pairs), at)

  fun _decode_verbatim(message: EMessage ref, position: I32, type_tag: I32)
    : ((ErlangTerm | None), I32)
  =>
    """Keeps a term this library does not model, so it can still be forwarded."""
    let next = message.skip_term(position)
    if next < 0 then return (None, position) end

    match message.copy_bytes(position, next)
    | let raw: String => (ErlangOpaque(TermType.name(type_tag), raw), next)
    else (None, position)
    end

  fun _plausible_arity(message: EMessage ref, arity: I32): Bool =>
    """
    Guards against a header that claims more elements than the message can hold,
    so a corrupt message cannot make us allocate without bound.
    """
    (arity >= 0) and (arity.i64() <= message.length().i64())
