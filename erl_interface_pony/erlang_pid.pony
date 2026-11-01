use "collections"

class val ErlangPid is (Comparable[ErlangPid] & Hashable & Stringable)
  """
  An Erlang process identifier.

  A pid is a plain value: node name, number, serial and creation.  Nothing is
  allocated on the C side, so pids can be created, copied, compared and hashed
  freely.
  """

  let node: String
  let num: U32
  let serial: U32
  let creation: U32

  new val create(node': String, num': U32 = 0, serial': U32 = 0,
    creation': U32 = 0)
  =>
    node = node'
    num = num'
    serial = serial'
    creation = creation'

  fun eq(that: box->ErlangPid): Bool =>
    (node == that.node)
      and (num == that.num)
      and (serial == that.serial)
      and (creation == that.creation)

  fun lt(that: box->ErlangPid): Bool =>
    if node != that.node then return node < that.node end
    if num != that.num then return num < that.num end
    if serial != that.serial then return serial < that.serial end
    creation < that.creation

  fun hash(): USize =>
    node.hash() xor (num.hash() << 1) xor (serial.hash() << 2)
      xor (creation.hash() << 3)

  fun string(): String iso^ =>
    recover
      let text = String
      text.push('<')
      text.append(num.string())
      text.push('.')
      text.append(serial.string())
      text.push('.')
      text.append(creation.string())
      if node != "" then
        text.push('@')
        text.append(node)
      end
      text.push('>')
      text
    end
