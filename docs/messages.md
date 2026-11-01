# Reading messages

Pony matches on types, not on values. A decoded message is a union of term
classes, so a message is read by naming the types its parts must have. Nothing
here casts, and nothing raises.

## The shape

`ErlangShapes.pair` and `ErlangShapes.triple` hand back a tuple's leading
elements, so one `match` binds each of them with its type. Both take the result
of the decoder directly.

```pony
match ErlangShapes.pair(ErlangTermDecoder.decode(message))
| (let sender: ErlangPid, let text: ErlangBinary) =>
  _env.out.print(text.value + " from " + sender.string())
else
  _env.out.print("not a {Pid, Binary}")
end
```

A term of another arity, another kind, or no term at all falls to `else`.

## The values

`ErlangValues` takes a payload out of a term. Each function answers `None` for a
term of another kind and for no term, so a lookup and the read that follows stay
one expression with two clauses.

```pony
let timeout: I64 =
  match ErlangValues.integer(config.get_binary("timeout"))
  | let found: I64 => found
  | None => 5_000   // no such key, or a value of another kind
  end
```

The same functions: `atom_name`, `bytes`, `chars`, `integer`, `float`, `pid`.

## The keys

A binary and an atom of one name are two different keys, so a lookup says which
kind it means.

```pony
let config = ErlangMap.binary_keyed([("timeout", ErlangInteger(5_000))])

config.get_binary("timeout")   // ErlangInteger(5000)
config.get_atom("timeout")     // None: that is another key
```

`ErlangMap.atom_keyed` builds the other kind, `get` takes a term as the key, and
`ErlangTuple.at` and `ErlangList.at` read a position.

## Decode once, then keep no terms

A handler is easier to read when it never sees a term. Decode into a value of
your own in one function:

```pony
class val Call
  let sender: ErlangPid
  let text: String

  new val create(sender': ErlangPid, text': String) =>
    sender = sender'
    text = text'

primitive CallDecoder
  fun apply(message: EMessage ref): (Call | None) =>
    match ErlangShapes.pair(ErlangTermDecoder.decode(message))
    | (let sender: ErlangPid, let text: ErlangBinary) =>
      Call(sender, text.value)
    else None
    end
```

```pony
match CallDecoder(message)
| let call: Call => _env.out.print("asking: " + call.text)
else _env.out.print("not a {Pid, Binary}")
end
```

One more thing worth knowing: `ErlangTerms.eq(term, ErlangAtom("reply"))` and
`ErlangTerms.is_atom(term, "reply")` compare a tag, which a type pattern cannot
do.
