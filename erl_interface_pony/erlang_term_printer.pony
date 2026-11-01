primitive ErlangTermPrinter
  """
  Renders a term in Erlang syntax, for logs, error messages and tests.

  This is a reading aid, not a serialiser: use an `EMessage` to put a term on
  the wire.
  """

  fun string(term: ErlangTerm): String iso^ =>
    recover
      let text = String
      _write(text, term)
      text
    end

  fun _write(text: String ref, term: ErlangTerm) =>
    match term
    | let t: ErlangAtom => _write_atom(text, t.name)
    | let t: ErlangInteger =>
      text.append(t.value.string())
    | let t: ErlangBigInteger =>
      text.append(t.decimal())
    | let t: ErlangFloat => _write_float(text, t.value)
    | let t: ErlangBinary =>
      text.append("<<")
      _write_quoted(text, t.value)
      text.append(">>")
    | let t: ErlangBitstring => _write_bitstring(text, t)
    | let t: ErlangString => _write_quoted(text, t.value)
    | let t: ErlangList => _write_list(text, t)
    | let t: ErlangTuple => _write_elements(text, "{", t.elements, "}")
    | let t: ErlangMap => _write_map(text, t)
    | let t: ErlangPid => text.append(t.string())
    | let t: ErlangPort =>
      text.append("#Port<")
      text.append(t.id.string())
      text.push('.')
      text.append(t.creation.string())
      text.push('>')
    | let t: ErlangReference => _write_reference(text, t)
    | let t: ErlangOpaque =>
      text.append("#<")
      text.append(t.type_name)
      text.append(", ")
      text.append(t.raw.size().string())
      text.append(" bytes>")
    end

  fun _write_atom(text: String ref, name: String) =>
    if _is_bare_atom(name) then
      text.append(name)
    else
      text.push('\'')
      for byte in name.values() do
        if (byte == '\'') or (byte == '\\') then text.push('\\') end
        text.push(byte)
      end
      text.push('\'')
    end

  fun _write_float(text: String ref, value: F64) =>
    let printed: String ref = value.string()
    text.append(printed)

    // Erlang needs a decimal point to read a literal as a float.
    var plain = printed.size() > 0
    for byte in printed.values() do
      if not (((byte >= '0') and (byte <= '9')) or (byte == '-')) then
        plain = false
      end
    end
    if plain then text.append(".0") end

  fun _write_bitstring(text: String ref, bitstring: ErlangBitstring) =>
    text.append("<<")
    if bitstring.used_bits_in_last_byte == 8 then
      _write_quoted(text, bitstring.value)
    else
      var index: USize = 0
      for byte in bitstring.value.values() do
        if index > 0 then text.append(", ") end
        text.append(byte.string())
        index = index + 1
      end
      if index > 0 then
        text.push(':')
        text.append(bitstring.used_bits_in_last_byte.string())
      end
    end
    text.append(">>")

  fun _write_list(text: String ref, list: ErlangList) =>
    text.push('[')
    _write_terms(text, list.elements)
    match list.tail
    | let tail: ErlangTerm =>
      text.append(" | ")
      _write(text, tail)
    end
    text.push(']')

  fun _write_map(text: String ref, map: ErlangMap) =>
    text.append("#{")
    var index: USize = 0
    for (key, value) in map.pairs.values() do
      if index > 0 then text.append(", ") end
      _write(text, key)
      text.append(" => ")
      _write(text, value)
      index = index + 1
    end
    text.push('}')

  fun _write_reference(text: String ref, reference: ErlangReference) =>
    text.append("#Ref<")
    if reference.node != "" then
      text.append(reference.node)
      text.push('.')
    end
    var index: USize = 0
    for word in reference.ids.values() do
      if index > 0 then text.push('.') end
      text.append(word.string())
      index = index + 1
    end
    if index > 0 then text.push('.') end
    text.append(reference.creation.string())
    text.push('>')

  fun _write_elements(text: String ref, opening: String,
    elements: Array[ErlangTerm] val, closing: String)
  =>
    text.append(opening)
    _write_terms(text, elements)
    text.append(closing)

  fun _write_terms(text: String ref, elements: Array[ErlangTerm] val) =>
    var index: USize = 0
    for element in elements.values() do
      if index > 0 then text.append(", ") end
      _write(text, element)
      index = index + 1
    end

  fun _write_quoted(text: String ref, value: String) =>
    text.push('"')
    for byte in value.values() do
      match byte
      | '"' => text.append("\\\"")
      | '\\' => text.append("\\\\")
      | '\n' => text.append("\\n")
      | '\r' => text.append("\\r")
      | '\t' => text.append("\\t")
      else
        if (byte >= 32) and (byte < 127) then
          text.push(byte)
        else
          text.append("\\x")
          text.push(_hex_digit(byte >> 4))
          text.push(_hex_digit(byte and 0x0f))
        end
      end
    end
    text.push('"')

  fun _hex_digit(value: U8): U8 =>
    if value < 10 then '0' + value else 'A' + (value - 10) end

  fun _is_bare_atom(name: String): Bool =>
    var first = true
    for byte in name.values() do
      if first then
        if (byte < 'a') or (byte > 'z') then return false end
        first = false
      elseif not _is_atom_char(byte) then
        return false
      end
    end
    (not first) and (not _is_reserved(name))

  fun _is_atom_char(byte: U8): Bool =>
    ((byte >= 'a') and (byte <= 'z'))
      or ((byte >= 'A') and (byte <= 'Z'))
      or ((byte >= '0') and (byte <= '9'))
      or (byte == '_')
      or (byte == '@')

  fun _is_reserved(name: String): Bool =>
    match name
    | "after" | "and" | "andalso" | "band" | "begin" | "bnot" | "bor"
    | "bsl" | "bsr" | "bxor" | "case" | "catch" | "cond" | "div" | "end"
    | "fun" | "if" | "let" | "not" | "of" | "or" | "orelse" | "receive"
    | "rem" | "try" | "when" | "xor" => true
    else false
    end
