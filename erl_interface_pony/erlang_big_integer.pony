class val ErlangBigInteger is Stringable
  """
  An integer that does not fit into 64 bits.

  It is kept the way the external format keeps it - a sign and a magnitude in
  base 256, least significant byte first - so nothing is lost on the way in or
  out, and `decimal()` is only computed when a person needs to read it.
  """

  let negative: Bool
  let digits: Array[U8] val

  new val create(negative': Bool, digits': Array[U8] val) =>
    negative = negative'
    digits = digits'

  fun is_zero(): Bool =>
    for digit in digits.values() do
      if digit != 0 then return false end
    end
    true

  fun decimal(): String iso^ =>
    """The value in base 10, with a leading minus sign when negative."""
    recover
      let magnitude: Array[U8] ref = Array[U8]
      for digit in digits.values() do
        magnitude.push(digit)
      end

      // Repeated long division by ten; the remainders are the digits of the
      // answer, least significant first.
      let reversed: Array[U8] ref = Array[U8]
      var remaining = not is_zero()
      while remaining do
        var carry: U32 = 0
        try
          var i = magnitude.size()
          while i > 0 do
            i = i - 1
            let current = (carry * 256) + magnitude(i)?.u32()
            magnitude.update(i, (current / 10).u8())?
            carry = current % 10
          end
        end
        reversed.push('0' + carry.u8())

        remaining = false
        for digit in magnitude.values() do
          if digit != 0 then remaining = true end
        end
      end

      let text = String
      if reversed.size() == 0 then
        text.push('0')
      else
        if negative then text.push('-') end
        var i = reversed.size()
        while i > 0 do
          i = i - 1
          try text.push(reversed(i)?) end
        end
      end
      text
    end

  fun string(): String iso^ => decimal()
