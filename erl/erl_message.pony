use "lib:otp_pony_node_c"
use "debug"

class EMessage
    var _message: Pointer[None]
    let header_size: I32 = 4 // message header size

    new create(message': Pointer[None]) =>
        _message = message'

    fun ref length(): USize =>
        @opn_ei_message_length[USize](_message)

    // returns a TermType & size
    fun ref type_at(pos: I32): (U8, I32) =>
        var type': U8 = 0
        var size': I32 = 0
        let res = @opn_ei_message_type_at[I32](_message, pos, addressof type', addressof size')

        if res != 0 then
            return (TermType.none(), 0)
        end

        (type', size')

    // t_ERL_ATOM_EXT
    // returns string or nothing, and the number of bytes read
    fun ref atom_at(pos: I32): ((String | None), I32) =>
        (let t, let s) = type_at(pos)
        if t != TermType.t_ERL_ATOM_EXT() then
            return (None, 0)
        end

        let buffer: Array[U8] val = recover Array[U8].init(0, s.usize() + 1 /*null*/) end

        let res = @opn_ei_message_atom_at[I32](_message, pos, buffer.cpointer())

        if res < 0 then
            return (None, 0)
        end

        (String.from_array(buffer), s)

    fun _final() =>
        if _message != Pointer[None] then
            @opn_ei_message_destroy[None](addressof _message)
        end
