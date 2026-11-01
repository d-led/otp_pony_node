primitive ErlangShapes
  """
  Reads the leading elements of a tuple so that one `match` binds all of them
  with their types.

  Pony matches on types and not on values, so a message shape is checked by
  naming the types its elements must have.  A term that is not that shape comes
  back as `None`s and falls to the `else` clause:

  ```pony
  match ErlangShapes.pair(term)
  | (let kind: ErlangAtom, let body: ErlangBinary) => handle(kind, body)
  else not_this_message()
  end
  ```

  The tag of a tagged tuple is a value, so it is read and compared after the
  shape is known: `ErlangTerms.is_atom(kind_term, "reply")`.
  """

  fun pair(term: ErlangTerm): ((ErlangTerm | None), (ErlangTerm | None)) =>
    """
    Both elements of a two element tuple, and two `None`s for anything else.
    """
    match term
    | let tuple: ErlangTuple =>
      if tuple.size() == 2 then
        (tuple.at(0), tuple.at(1))
      else
        (None, None)
      end
    else
      (None, None)
    end

  fun triple(term: ErlangTerm)
    : ((ErlangTerm | None), (ErlangTerm | None), (ErlangTerm | None))
  =>
    """
    All three elements of a three element tuple, and three `None`s for anything
    else.
    """
    match term
    | let tuple: ErlangTuple =>
      if tuple.size() == 3 then
        (tuple.at(0), tuple.at(1), tuple.at(2))
      else
        (None, None, None)
      end
    else
      (None, None, None)
    end
