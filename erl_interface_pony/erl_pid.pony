class val ErlangPid
    let node: String
    let num: U32
    let serial: U32
    let creation: U32

    var cpid: Pointer[None]

    new create(node': String, num': U32, serial': U32, creation': U32) =>
        node = node'
        num = num'
        serial = serial'
        creation = creation'
        cpid = @opn_ei_pid_new[Pointer[None]](node'.cstring(), num, serial, creation)

    fun _final() =>
        if cpid != Pointer[None] then
            @opn_ei_pid_destroy[None](addressof cpid)
        end
