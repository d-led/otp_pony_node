use "lib:otp_pony_node_c"
use "debug"

class EMessage
    var _message: Pointer[None]
    let beginning: I32 // after the message header size

    new begin() =>
        let message' = @opn_ei_message_new[Pointer[None]]()
        _message = message'

        if message' != Pointer[None] then
            beginning = @opn_ei_message_beginning[I32](_message)
        else
            beginning = 0
        end

    new from_cpointer(message': Pointer[None]) =>        
        _message = message'

        if message' != Pointer[None] then
            beginning = @opn_ei_message_beginning[I32](_message)
        else
            beginning = 0
        end

    fun ref length(): USize =>
        if not valid() then
            return 0
        end

        @opn_ei_message_length[USize](_message)
    
    fun ref cpointer(): Pointer[None] =>
        _message

    // returns a TermType & size
    fun ref type_at(pos: I32): (U8, I32) =>
        if not valid() then
            return (TermType.none(), 0)
        end

        var type': U8 = 0
        var size': I32 = 0
        let res = @opn_ei_message_type_at[I32](_message, pos, addressof type', addressof size')

        // Debug.out("p:"+pos.string()+" t:"+type'.string()+" s:"+size'.string())

        if res != 0 then
            return (TermType.none(), 0)
        end

        (type', size')

    fun ref encode_atom(what: String): I32 =>
        @opn_ei_message_encode_atom[I32](_message, what.cstring())

    // t_ERL_ATOM_EXT
    // returns string or nothing, and the next position
    fun ref atom_at(pos: I32): ((String | None), I32) =>
        if not valid() then
            return (None, 0)
        end

        (let t, let s) = type_at(pos)
        if t != TermType.t_ERL_ATOM_EXT() then
            return (None, 0)
        end

        let buffer: Array[U8] val = recover Array[U8].init(0, s.usize() + 1 /*null*/) end

        var index: I32 = pos
        let res = @opn_ei_message_atom_at[I32](_message, addressof index, buffer.cpointer())

        if res < 0 then
            return (None, 0)
        end

        (Strings.null_trimmed(buffer), index)

    fun ref encode_binary(what: String): I32 =>
        @opn_ei_message_encode_binary[I32](_message, what.cpointer(), what.size())

    // returns string or nothing, and the next position
    fun ref binary_at(pos: I32): ((String | None), I32) =>
        if not valid() then
            return (None, 0)
        end

        (let t, let s) = type_at(pos)
        if t != TermType.t_ERL_BINARY_EXT() then
            return (None, 0)
        end

        let buffer: Array[U8] val = recover Array[U8].init(0, s.usize() + 1 /*null*/) end

        var index: I32 = pos
        var read_bytes: I64 = 0
        let res = @opn_ei_message_binary_at[I32](_message, addressof index, buffer.cpointer(), addressof read_bytes)

        if res < 0 then
            return (None, 0)
        end

        if read_bytes != s.i64() then
            Debug.out("binary_at: size mismatch "+read_bytes.string()+"!="+s.string())
        end

        (Strings.null_trimmed(buffer), index)

    fun ref encode_pid(pid: ErlangPid): I32 =>
        @opn_ei_message_encode_pid[I32](_message, pid.cpointer())

    // returns (None, 0) if not a Pid
    // otherwise: arity, next position
    fun ref pid_at(pos: I32): ((ErlangPid | None), I32) =>
        if not valid() then
            return (None, 0)
        end

        (let t, let s) = type_at(pos)
        if t != TermType.t_ERL_PID_EXT() then
            return (None, 0)
        end

        let buffer: Array[U8] val = recover Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1 /*null*/) end

        var index: I32 = pos
        var num: U32 = 0
        var serial: U32 = 0
        var creation: U32 = 0
        let res = @opn_ei_message_pid_at[I32](_message, addressof index, buffer.cpointer(), addressof num, addressof serial, addressof creation)

        if res < 0 then
            return (None, 0)
        end

        let pid: ErlangPid val = recover ErlangPid(Strings.null_trimmed(buffer), num, serial, creation) end
        (pid, index)

    fun ref encode_tuple_header(arity: I32): I32 =>
        @opn_ei_message_encode_tuple_header[I32](_message, arity)

    // returns (-1, 0) if not a tuple
    // otherwise: arity, next position
    fun ref tuple_arity_at(pos: I32): (I32, I32) =>
        if not valid() then
            return (-1, 0)
        end

        (let t, let s) = type_at(pos)
        if (t != TermType.t_ERL_SMALL_TUPLE_EXT()) and (t != TermType.t_ERL_LARGE_TUPLE_EXT()) then
            return (-1, 0)
        end

        var index: I32 = pos
        var arity: I32 = -1
        let res = @opn_ei_message_tuple_arity_at[I32](_message, addressof index, addressof arity)

        if res < 0 then
            return (-1, 0)
        end

        (arity, index)

    fun ref debug_type_at(pos: I32) =>
        (let t, let s) = type_at(pos)
        match t
        | TermType.t_ERL_SMALL_INTEGER_EXT() =>
            Debug.out(pos.string()+": ERL_SMALL_INTEGER " + s.string() + "bytes")
        | TermType.t_ERL_INTEGER_EXT() =>
            Debug.out(pos.string()+": ERL_INTEGER " + s.string() + "bytes")
        | TermType.t_ERL_FLOAT_EXT() =>
            Debug.out(pos.string()+": ERL_FLOAT " + s.string() + "bytes")
        | TermType.t_NEW_FLOAT_EXT() =>
            Debug.out(pos.string()+": NEW_FLOAT " + s.string() + "bytes")
        | TermType.t_ERL_ATOM_EXT() =>
            Debug.out(pos.string()+": ERL_ATOM " + s.string() + "bytes")
        | TermType.t_ERL_SMALL_ATOM_EXT() =>
            Debug.out(pos.string()+": ERL_SMALL_ATOM " + s.string() + "bytes")
        | TermType.t_ERL_ATOM_UTF8_EXT() =>
            Debug.out(pos.string()+": ERL_ATOM_UTF8 " + s.string() + "bytes")
        | TermType.t_ERL_SMALL_ATOM_UTF8_EXT() =>
            Debug.out(pos.string()+": ERL_SMALL_ATOM_UTF8 " + s.string() + "bytes")
        | TermType.t_ERL_REFERENCE_EXT() =>
            Debug.out(pos.string()+": ERL_REFERENCE " + s.string() + "bytes")
        | TermType.t_ERL_NEW_REFERENCE_EXT() =>
            Debug.out(pos.string()+": ERL_NEW_REFERENCE " + s.string() + "bytes")
        | TermType.t_ERL_NEWER_REFERENCE_EXT() =>
            Debug.out(pos.string()+": ERL_NEWER_REFERENCE " + s.string() + "bytes")
        | TermType.t_ERL_PORT_EXT() =>
            Debug.out(pos.string()+": ERL_PORT " + s.string() + "bytes")
        | TermType.t_ERL_NEW_PORT_EXT() =>
            Debug.out(pos.string()+": ERL_NEW_PORT " + s.string() + "bytes")
        | TermType.t_ERL_PID_EXT() =>
            Debug.out(pos.string()+": ERL_PID " + s.string() + "bytes")
        | TermType.t_ERL_NEW_PID_EXT() =>
            Debug.out(pos.string()+": ERL_NEW_PID " + s.string() + "bytes")
        | TermType.t_ERL_SMALL_TUPLE_EXT() =>
            Debug.out(pos.string()+": ERL_SMALL_TUPLE " + s.string() + "bytes")
        | TermType.t_ERL_LARGE_TUPLE_EXT() =>
            Debug.out(pos.string()+": ERL_LARGE_TUPLE " + s.string() + "bytes")
        | TermType.t_ERL_NIL_EXT() =>
            Debug.out(pos.string()+": ERL_NIL " + s.string() + "bytes")
        | TermType.t_ERL_STRING_EXT() =>
            Debug.out(pos.string()+": ERL_STRING " + s.string() + "bytes")
        | TermType.t_ERL_LIST_EXT() =>
            Debug.out(pos.string()+": ERL_LIST " + s.string() + "bytes")
        | TermType.t_ERL_BINARY_EXT() =>
            Debug.out(pos.string()+": ERL_BINARY " + s.string() + "bytes")
        | TermType.t_ERL_SMALL_BIG_EXT() =>
            Debug.out(pos.string()+": ERL_SMALL_BIG " + s.string() + "bytes")
        | TermType.t_ERL_LARGE_BIG_EXT() =>
            Debug.out(pos.string()+": ERL_LARGE_BIG " + s.string() + "bytes")
        | TermType.t_ERL_NEW_FUN_EXT() =>
            Debug.out(pos.string()+": ERL_NEW_FUN " + s.string() + "bytes")
        | TermType.t_ERL_MAP_EXT() =>
            Debug.out(pos.string()+": ERL_MAP " + s.string() + "bytes")
        | TermType.t_ERL_FUN_EXT() =>
            Debug.out(pos.string()+": ERL_FUN " + s.string() + "bytes")
        | TermType.none() =>
            Debug.out("no type: message is invalid")
        else
            Debug.out(pos.string()+": Unknown type: " + t.string() + " " + s.string() + "bytes")
        end

    fun ref valid(): Bool =>
        _message != Pointer[None]

    fun _final() =>
        if _message != Pointer[None] then
            @opn_ei_message_destroy[None](addressof _message)
        end
