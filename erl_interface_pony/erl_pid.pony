use @opn_ei_pid_new[Pointer[None]](node': Pointer[None], num: U32, serial: U32, creation: U32)
use @opn_ei_pid_destroy[None](_cpid: Pointer[None])

class val ErlangPid is Stringable
    let node: String
    let num: U32
    let serial: U32
    let creation: U32

    var _cpid: Pointer[None]

    new val create(node': String, num': U32, serial': U32, creation': U32) =>
        node = node'
        num = num'
        serial = serial'
        creation = creation'
        _cpid = @opn_ei_pid_new(node'.cstring(), num, serial, creation)

    fun val cpointer(): Pointer[None] val =>
        _cpid

    fun box string() : String iso^ =>
        recover
            let s: String ref = String
            s.append("node: " )
            s.append(node)
            s.append(", num: ")
            s.append(num.string())
            s.append(", serial: ")
            s.append(serial.string())
            s.append(", creation: " + creation.string())
            s
        end

    fun _final() =>
        if _cpid != Pointer[None] then
            @opn_ei_pid_destroy(addressof _cpid)
        end
