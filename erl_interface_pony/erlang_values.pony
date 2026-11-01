primitive ErlangValues
  """
  Takes a value out of a term, keeping the term model out of the caller's code.

  Each function answers `None` when the term is of another kind, or when there
  is no term at all, so a lookup and the read that follows are one expression
  and two clauses:

  ```pony
  match ErlangValues.integer(config.get(ErlangBinary("timeout")))
  | let timeout: I64 => use(timeout)
  | None => use(5_000)
  end
  ```

  Nothing here casts: the type is known once the second clause is reached, and
  a value of the wrong kind is a `None` rather than an error.
  """

  fun atom_name(term: (ErlangTerm | None)): (String | None) =>
    """The name of an atom."""
    match term
    | let atom: ErlangAtom => atom.name
    else None
    end

  fun bytes(term: (ErlangTerm | None)): (String | None) =>
    """The bytes of a binary, as they arrived."""
    match term
    | let binary: ErlangBinary => binary.value
    else None
    end

  fun chars(term: (ErlangTerm | None)): (String | None) =>
    """The bytes of a string, which is a charlist on the wire."""
    match term
    | let string: ErlangString => string.value
    else None
    end

  fun integer(term: (ErlangTerm | None)): (I64 | None) =>
    """
    The value of an integer that fits into 64 bits.

    A wider integer is an `ErlangBigInteger` and answers `None` here; read it
    through `decimal()` instead of narrowing it silently.
    """
    match term
    | let number: ErlangInteger => number.value
    else None
    end

  fun float(term: (ErlangTerm | None)): (F64 | None) =>
    """The value of a float."""
    match term
    | let number: ErlangFloat => number.value
    else None
    end

  fun pid(term: (ErlangTerm | None)): (ErlangPid | None) =>
    """The pid itself, ready to send to."""
    match term
    | let found: ErlangPid => found
    else None
    end
