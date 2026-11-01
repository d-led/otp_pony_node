primitive Strings
  """
  Moving bytes between Pony and C without guessing at their length.

  Binaries may contain NUL bytes, so anything decoded from a message is
  trimmed by the length the C layer reports and never by `strlen`.
  """

  fun buffer(size: USize): Array[U8] val =>
    """A zeroed byte buffer of `size` bytes for the C layer to fill."""
    recover Array[U8].init(0, size) end

  fun from_bytes(source: Array[U8] val, len: USize): String val^ =>
    """Takes the first `len` bytes of `source` as a String."""
    String.from_array(recover source.slice(0, len) end)

  fun null_trimmed(source: Array[U8] val): String val^ =>
    """Takes the bytes before the first NUL, for C strings that are NUL terminated."""
    var len: USize = 0
    for byte in source.values() do
      if byte == 0 then
        return from_bytes(source, len)
      end
      len = len + 1
    end
    from_bytes(source, source.size())
