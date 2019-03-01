use "lib:otp_pony_node_c"
use "debug"

class EInterface
    let this_nodename: String
    let cookie: String
    let creation: I16
    var connection: Pointer[None] = Pointer[None]
    var connection_id: Connection = -1

    new create(this_nodename': String, cookie': String, creation': I16 = 0) =>
        this_nodename = this_nodename'
        cookie = cookie'
        creation = creation'

    fun set_tracelevel(level: I32) =>
        @opn_set_tracelevel[None](level)

    fun ref connect(nodename: String): (ConnectionSucceeded | ConnectionFailed) =>
        // simple single connection for now
        if connected() then
            Debug.out("already connected once")
            return ConnectionFailed
        end

        connection = @opn_ei_new[Pointer[None]](this_nodename.cstring(), cookie.cstring(), creation)
        Debug.out("res: " + connection.usize().string())
        if connection.is_null() then
            return ConnectionFailed
        end

        connection_id = @opn_ei_connect[I32](connection, nodename.cstring())
        if connection_id < 0 then
            disconnect()
            return ConnectionFailed
        end

        ConnectionSucceeded
        
    fun ref disconnect() =>
        if not connected() then 
            return
        end

        @opn_ei_delete[None](connection)
        connection = Pointer[None]
        connection_id = -1

    fun connected(): Bool =>
        connection != Pointer[None]

    fun _final() =>
        if connection != Pointer[None] then
            @opn_ei_delete[None](connection)
        end
