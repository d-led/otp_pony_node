use "debug"

type ErlangTerm is
  ( ErlangAtom
  | ErlangPid
  | ErlangBinary
  | ErlangTuple
  | ErlangNil
  )

class val ErlangAtom
  let name: String
  new val create(name': String) =>
    name = name'

class val ErlangBinary
  let value: String
  new val create(value': String) =>
    value = value'

primitive ErlangNil

class val ErlangTuple
  let elements: Array[ErlangTerm] val
  new val create(elements': Array[ErlangTerm] val) =>
    elements = elements'

primitive ErlangTermDecoder
  fun decode(m: EMessage ref): (ErlangTerm | None) =>
    (let term, _) = _decode_at(m, m.beginning)
    term

  fun _decode_at(m: EMessage ref, pos: I32): ((ErlangTerm | None), I32) =>
    (let t, let s) = m.type_at(pos)
    match t
    | TermType.t_ERL_ATOM_EXT() =>
      (let name_or_none, let next_pos) = m.atom_at(pos)
      match name_or_none
      | let name: String =>
        (ErlangAtom(name), next_pos)
      else
        (None, next_pos)
      end
    | TermType.t_ERL_BINARY_EXT() =>
      (let val_or_none, let next_pos) = m.binary_at(pos)
      match val_or_none
      | let value: String =>
        (ErlangBinary(value), next_pos)
      else
        (None, next_pos)
      end
    | TermType.t_ERL_PID_EXT() =>
      (let pid_or_none, let next_pos) = m.pid_at(pos)
      match pid_or_none
      | let pid: ErlangPid =>
        (pid, next_pos)
      else
        (None, next_pos)
      end
    | TermType.t_ERL_SMALL_TUPLE_EXT()
    | TermType.t_ERL_LARGE_TUPLE_EXT() =>
      (let arity, var current_pos) = m.tuple_arity_at(pos)
      if arity < 0 then
        return (None, current_pos)
      end
      let arr = recover trn Array[ErlangTerm](arity.usize()) end
      var i: I32 = 0
      var error_occurred: Bool = false
      while i < arity do
        (let term, let next_pos) = _decode_at(m, current_pos)
        match term
        | let et: ErlangTerm =>
          arr.push(et)
        else
          error_occurred = true
        end
        current_pos = next_pos
        i = i + 1
      end
      if error_occurred then
        (None, current_pos)
      else
        (ErlangTuple(consume arr), current_pos)
      end
    | TermType.t_ERL_NIL_EXT() =>
      // ERL_NIL is an empty list, size is 0
      (ErlangNil, pos + 1)
    else
      // Unknown or unsupported type
      (None, pos)
    end
