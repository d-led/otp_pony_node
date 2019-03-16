class val ErlangPid
    let node: String
    let num: U32
    let serial: U32
    let creation: U32

    var _cpid: Pointer[None]

    new create(node': String, num': U32, serial': U32, creation': U32) =>
        node = node'
        num = num'
        serial = serial'
        creation = creation'
        _cpid = @opn_ei_pid_new[Pointer[None]](node'.cstring(), num, serial, creation)

    fun val cpointer(): Pointer[None] val =>
        _cpid

    fun _final() =>
        if _cpid != Pointer[None] then
            @opn_ei_pid_destroy[None](addressof _cpid)
        end
