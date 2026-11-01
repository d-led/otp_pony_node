use "lib:otp_pony_node_c"

use @opn_ei_message_new[Pointer[None]]()
use @opn_ei_message_destroy[None](message: Pointer[None] tag)
use @opn_ei_message_length[I32](message: Pointer[None] tag)
use @opn_ei_message_beginning[I32](message: Pointer[None] tag)
use @opn_ei_message_type_at[I32](message: Pointer[None] tag, position: I32,
  type_tag: Pointer[I32] tag, size: Pointer[I32] tag)
use @opn_ei_message_skip_term[I32](message: Pointer[None] tag, position: I32,
  next: Pointer[I32] tag)
use @opn_ei_message_copy[I32](message: Pointer[None] tag, from: I32, to: I32,
  buffer: Pointer[U8] tag, capacity: USize)
use @opn_ei_message_append_raw[I32](message: Pointer[None] tag,
  bytes: Pointer[U8] tag, length: I32)

use @opn_ei_message_decode_atom[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, buffer: Pointer[U8] tag, capacity: USize)
use @opn_ei_message_decode_int[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, value: Pointer[I64] tag)
use @opn_ei_message_decode_double[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, value: Pointer[F64] tag)
use @opn_ei_message_decode_binary[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, buffer: Pointer[U8] tag, capacity: USize,
  length: Pointer[I64] tag)
use @opn_ei_message_decode_bitstring[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, buffer: Pointer[U8] tag, capacity: USize,
  length: Pointer[I64] tag, used_bits: Pointer[I32] tag)
use @opn_ei_message_decode_string[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, buffer: Pointer[U8] tag, capacity: USize)
use @opn_ei_message_decode_list_header[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, arity: Pointer[I32] tag)
use @opn_ei_message_decode_tuple_header[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, arity: Pointer[I32] tag)
use @opn_ei_message_decode_map_header[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, arity: Pointer[I32] tag)
use @opn_ei_message_decode_pid[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, node: Pointer[U8] tag, node_capacity: USize,
  num: Pointer[U32] tag, serial: Pointer[U32] tag, creation: Pointer[U32] tag)
use @opn_ei_message_decode_port[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, node: Pointer[U8] tag, node_capacity: USize,
  id: Pointer[U64] tag, creation: Pointer[U32] tag)
use @opn_ei_message_decode_ref[I32](message: Pointer[None] tag,
  index: Pointer[I32] tag, node: Pointer[U8] tag, node_capacity: USize,
  ids: Pointer[U32] tag, ids_capacity: I32, id_count: Pointer[I32] tag,
  creation: Pointer[U32] tag)

use @opn_ei_message_encode_atom[I32](message: Pointer[None] tag,
  what: Pointer[U8] tag)
use @opn_ei_message_encode_int[I32](message: Pointer[None] tag, value: I64)
use @opn_ei_message_encode_double[I32](message: Pointer[None] tag, value: F64)
use @opn_ei_message_encode_binary[I32](message: Pointer[None] tag,
  what: Pointer[U8] tag, length: I32)
use @opn_ei_message_encode_bitstring[I32](message: Pointer[None] tag,
  what: Pointer[U8] tag, length: I32, used_bits_in_last_byte: I32)
use @opn_ei_message_encode_string[I32](message: Pointer[None] tag,
  what: Pointer[U8] tag, length: I32)
use @opn_ei_message_encode_list_header[I32](message: Pointer[None] tag,
  arity: I32)
use @opn_ei_message_encode_empty_list[I32](message: Pointer[None] tag)
use @opn_ei_message_encode_tuple_header[I32](message: Pointer[None] tag,
  arity: I32)
use @opn_ei_message_encode_map_header[I32](message: Pointer[None] tag,
  arity: I32)
use @opn_ei_message_encode_pid[I32](message: Pointer[None] tag,
  node: Pointer[U8] tag, num: U32, serial: U32, creation: U32)
use @opn_ei_message_encode_port[I32](message: Pointer[None] tag,
  node: Pointer[U8] tag, id: U64, creation: U32)
use @opn_ei_message_encode_ref[I32](message: Pointer[None] tag,
  node: Pointer[U8] tag, ids: Pointer[U32] tag, id_count: I32, creation: U32)

class EMessage
  """
  An encoded Erlang message: the bytes of one term in the external format.

  `EMessage.begin()` starts an empty message to encode into, `encode(term)`
  writes a whole term into it, and the `decode_*` functions read terms out at a
  position.  For the usual "bytes in, term out" direction see
  `ErlangTermDecoder`.
  """

  var _message: Pointer[None]
  let beginning: I32

  new begin() =>
    _message = @opn_ei_message_new()
    beginning = _beginning_of(_message)

  new from_cpointer(message': Pointer[None]) =>
    """Takes ownership of a message received from the C layer."""
    _message = message'
    beginning = _beginning_of(_message)

  fun ref valid(): Bool =>
    not _message.is_null()

  fun ref length(): USize =>
    if valid() then @opn_ei_message_length(_message).usize() else 0 end

  fun ref cpointer(): Pointer[None] =>
    _message

  fun ref type_at(position: I32): (I32, I32) =>
    """The external format type tag and payload size of the term at `position`."""
    if not valid() then return (TermType.none(), 0) end

    var type_tag: I32 = 0
    var size: I32 = 0
    let result = @opn_ei_message_type_at(_message, position, addressof type_tag,
      addressof size)
    if result != 0 then return (TermType.none(), 0) end

    (type_tag, size)

  fun ref skip_term(position: I32): I32 =>
    """The position just past the term at `position`, -1 for an invalid term."""
    if not valid() then return -1 end

    var next: I32 = 0
    let result = @opn_ei_message_skip_term(_message, position, addressof next)
    if result != 0 then return -1 end

    next

  fun ref copy_bytes(from: I32, to: I32): (String | None) =>
    """The raw encoded bytes of a term, which is how unmodelled terms are kept."""
    if not valid() or (to <= from) then return None end

    let size = to - from
    let buffer = Strings.buffer(size.usize())
    let copied = @opn_ei_message_copy(_message, from, to, buffer.cpointer(),
      buffer.size())
    if copied != size then return None end

    Strings.from_bytes(buffer, size.usize())

  fun ref append_raw(encoded: String): I32 =>
    """Appends bytes that are already in the external format."""
    if not valid() then return -1 end

    @opn_ei_message_append_raw(_message, encoded.cpointer(),
      encoded.size().i32())

  // -- decoding ------------------------------------------------------------

  fun ref decode_atom(position: I32): (String | None, I32) =>
    (let type_tag, let size) = type_at(position)
    if not TermType.is_atom(type_tag) then return (None, position) end

    let buffer = _buffer(size + 1)
    var index: I32 = position
    let result = @opn_ei_message_decode_atom(_message, addressof index,
      buffer.cpointer(), buffer.size())
    if result != 0 then return (None, position) end

    (Strings.null_trimmed(buffer), index)

  fun ref decode_int(position: I32): (I64 | None, I32) =>
    (let type_tag, _) = type_at(position)
    if not ((type_tag == TermType.small_integer())
      or (type_tag == TermType.integer())
      or (type_tag == TermType.small_big())
      or (type_tag == TermType.large_big()))
    then
      return (None, position)
    end

    var value: I64 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_int(_message, addressof index,
      addressof value)
    if result != 0 then return (None, position) end

    (value, index)

  fun ref decode_double(position: I32): (F64 | None, I32) =>
    (let type_tag, _) = type_at(position)
    if (type_tag != TermType.float()) and (type_tag != TermType.new_float()) then
      return (None, position)
    end

    var value: F64 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_double(_message, addressof index,
      addressof value)
    if result != 0 then return (None, position) end

    (value, index)

  fun ref decode_binary(position: I32): (String | None, I32) =>
    (let type_tag, let size) = type_at(position)
    if type_tag != TermType.binary() then return (None, position) end

    let buffer = _buffer(size + 1)
    var byte_count: I64 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_binary(_message, addressof index,
      buffer.cpointer(), buffer.size(), addressof byte_count)
    if result != 0 then return (None, position) end

    (Strings.from_bytes(buffer, byte_count.usize()), index)

  fun ref decode_bitstring(position: I32): (ErlangBitstring | None, I32) =>
    (let type_tag, let size) = type_at(position)
    if type_tag != TermType.bit_binary() then return (None, position) end

    let buffer = _buffer(size + 1)
    var byte_count: I64 = 0
    var used_bits: I32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_bitstring(_message, addressof index,
      buffer.cpointer(), buffer.size(), addressof byte_count,
      addressof used_bits)
    if result != 0 then return (None, position) end

    (ErlangBitstring(Strings.from_bytes(buffer, byte_count.usize()),
      used_bits.u8()), index)

  fun ref decode_string(position: I32): (String | None, I32) =>
    (let type_tag, let size) = type_at(position)
    if type_tag != TermType.string() then return (None, position) end

    let buffer = _buffer(size + 1)
    var index: I32 = position
    let result = @opn_ei_message_decode_string(_message, addressof index,
      buffer.cpointer(), buffer.size())
    if result != 0 then return (None, position) end

    (Strings.null_trimmed(buffer), index)

  fun ref decode_list_header(position: I32): (I32, I32) =>
    (let type_tag, _) = type_at(position)
    if (type_tag != TermType.list()) and (type_tag != TermType.nil()) then
      return (-1, position)
    end

    var arity: I32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_list_header(_message, addressof index,
      addressof arity)
    if result != 0 then return (-1, position) end

    (arity, index)

  fun ref decode_tuple_header(position: I32): (I32, I32) =>
    (let type_tag, _) = type_at(position)
    if (type_tag != TermType.small_tuple())
      and (type_tag != TermType.large_tuple())
    then
      return (-1, position)
    end

    var arity: I32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_tuple_header(_message, addressof index,
      addressof arity)
    if result != 0 then return (-1, position) end

    (arity, index)

  fun ref decode_map_header(position: I32): (I32, I32) =>
    (let type_tag, _) = type_at(position)
    if type_tag != TermType.map() then return (-1, position) end

    var arity: I32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_map_header(_message, addressof index,
      addressof arity)
    if result != 0 then return (-1, position) end

    (arity, index)

  fun ref decode_pid(position: I32): (ErlangPid | None, I32) =>
    (let type_tag, _) = type_at(position)
    if (type_tag != TermType.pid()) and (type_tag != TermType.new_pid()) then
      return (None, position)
    end

    let node = _buffer(_node_capacity())
    var num: U32 = 0
    var serial: U32 = 0
    var creation: U32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_pid(_message, addressof index,
      node.cpointer(), node.size(), addressof num, addressof serial,
      addressof creation)
    if result != 0 then return (None, position) end

    (ErlangPid(Strings.null_trimmed(node), num, serial, creation), index)

  fun ref decode_port(position: I32): (ErlangPort | None, I32) =>
    (let type_tag, _) = type_at(position)
    if not ((type_tag == TermType.port()) or (type_tag == TermType.new_port())
      or (type_tag == TermType.v4_port()))
    then
      return (None, position)
    end

    let node = _buffer(_node_capacity())
    var id: U64 = 0
    var creation: U32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_port(_message, addressof index,
      node.cpointer(), node.size(), addressof id, addressof creation)
    if result != 0 then return (None, position) end

    (ErlangPort(Strings.null_trimmed(node), id, creation), index)

  fun ref decode_reference(position: I32): (ErlangReference | None, I32) =>
    (let type_tag, _) = type_at(position)
    if not ((type_tag == TermType.reference())
      or (type_tag == TermType.new_reference())
      or (type_tag == TermType.newer_reference()))
    then
      return (None, position)
    end

    let node = _buffer(_node_capacity())
    let ids: Array[U32] val = recover Array[U32].init(0, _max_reference_words()) end
    var id_count: I32 = 0
    var creation: U32 = 0
    var index: I32 = position
    let result = @opn_ei_message_decode_ref(_message, addressof index,
      node.cpointer(), node.size(), ids.cpointer(), _max_reference_words().i32(),
      addressof id_count, addressof creation)
    if result != 0 then return (None, position) end

    let used = recover ids.slice(0, id_count.usize()) end
    (ErlangReference(Strings.null_trimmed(node), consume used, creation), index)

  // -- encoding ------------------------------------------------------------

  fun ref encode(term: ErlangTerm) ? =>
    """Writes a whole term into the message."""
    ErlangTermEncoder.encode(this, term)?

  fun ref encode_atom(name: String): I32 =>
    @opn_ei_message_encode_atom(_message, name.cstring())

  fun ref encode_int(value: I64): I32 =>
    @opn_ei_message_encode_int(_message, value)

  fun ref encode_double(value: F64): I32 =>
    @opn_ei_message_encode_double(_message, value)

  fun ref encode_binary(value: String): I32 =>
    @opn_ei_message_encode_binary(_message, value.cpointer(),
      value.size().i32())

  fun ref encode_bitstring(value: String, used_bits_in_last_byte: U8): I32 =>
    @opn_ei_message_encode_bitstring(_message, value.cpointer(),
      value.size().i32(), used_bits_in_last_byte.i32())

  fun ref encode_string(value: String): I32 =>
    @opn_ei_message_encode_string(_message, value.cpointer(),
      value.size().i32())

  fun ref encode_list_header(arity: USize): I32 =>
    @opn_ei_message_encode_list_header(_message, arity.i32())

  fun ref encode_empty_list(): I32 =>
    @opn_ei_message_encode_empty_list(_message)

  fun ref encode_tuple_header(arity: USize): I32 =>
    @opn_ei_message_encode_tuple_header(_message, arity.i32())

  fun ref encode_map_header(arity: USize): I32 =>
    @opn_ei_message_encode_map_header(_message, arity.i32())

  fun ref encode_pid(node: String, num: U32, serial: U32, creation: U32): I32 =>
    @opn_ei_message_encode_pid(_message, node.cstring(), num, serial, creation)

  fun ref encode_port(node: String, id: U64, creation: U32): I32 =>
    @opn_ei_message_encode_port(_message, node.cstring(), id, creation)

  fun ref encode_reference(node: String, ids: Array[U32] val,
    creation: U32)
    : I32
  =>
    @opn_ei_message_encode_ref(_message, node.cstring(), ids.cpointer(),
      ids.size().i32(), creation)

  // -- internals -----------------------------------------------------------

  fun ref _buffer(size: I32): Array[U8] val =>
    let requested: I32 = if size < 1 then 1 else size end
    Strings.buffer(requested.usize())

  fun tag _beginning_of(message: Pointer[None]): I32 =>
    if message.is_null() then 0 else @opn_ei_message_beginning(message) end

  fun _node_capacity(): I32 =>
    """`MAXATOMLEN_UTF8` from `ei.h`: a node name, NUL included."""
    (255 * 4) + 1

  fun _max_reference_words(): USize =>
    """A reference carries at most five words in the external format."""
    5

  fun _final() =>
    if not _message.is_null() then
      @opn_ei_message_destroy(_message)
    end
