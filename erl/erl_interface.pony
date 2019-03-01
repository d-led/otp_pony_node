use "lib:otp_pony_node_c"
use "debug"

class EInterface
    let nodename: String
    let cookie: String
    let creation: I16
    var connection: Pointer[None] = Pointer[None]

    new create(nodename': String, cookie': String, creation': I16 = 0) =>
        nodename = nodename'
        cookie = cookie'
        creation = creation'

    fun set_tracelevel(level: I32) =>
        @opn_set_tracelevel[None](level)

    fun ref connect(): (ConnectionSucceeded | ConnectionFailed) =>
        connection = @opn_ei_new[Pointer[None]](nodename.cstring(), cookie.cstring(), creation)
        Debug.out("res: " + connection.usize().string())
        if connection.is_null() then
            return ConnectionFailed
        else
            return ConnectionSucceeded
        end
        
    fun ref disconnect() =>
        @opn_ei_delete[None](connection)
        connection = Pointer[None]

    fun connected(): Bool =>
        connection == Pointer[None]