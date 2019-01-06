struct val ErlMessage
    var mtype: I32 = 0 // ERL_REG_SEND == 6
    var msg: Pointer[U8] tag = Pointer[U8]
    var from: Pointer[U8] tag = Pointer[U8]
    var to: Pointer[U8] tag = Pointer[U8]
    var to_name: Array[U8] = Array[U8].init(0, (255*4)+1)

    new val create() => None

    fun free() =>
        @erl_free_compound[None](msg)
        @erl_free_compound[None](from)
        @erl_free_compound[None](to)
    // void   erl_free_compound(ETERM*);
