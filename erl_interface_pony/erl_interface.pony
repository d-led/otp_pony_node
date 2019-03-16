use "lib:otp_pony_node_c"
use "debug"

class EInterface
    let _this_nodename: String
    let _cookie: String
    let _creation: I16
    var _connection: Pointer[None] = Pointer[None]
    var _connection_id: Connection = -1

    new create(this_nodename': String, cookie': String, creation': I16 = 0) =>
        _this_nodename = this_nodename'
        _cookie = cookie'
        _creation = creation'

    fun set_tracelevel(level: I32) =>
        @opn_set_tracelevel[None](level)

    fun ref self_pid(): ErlangPid =>
        let buffer: Array[U8] val = recover Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1 /*null*/) end
        var num: U32 = 0
        var serial: U32 = 0
        var creation: U32 = 0
        let res = @opn_ei_self_pid[I32](_connection, buffer.cpointer(), addressof num, addressof serial, addressof creation)

        if res != 0 then
            // todo: strategy on failure
            Debug.out("self_pid: decoding the pid failed")
        end

        let pid: ErlangPid val = recover ErlangPid(Strings.null_trimmed(buffer), num, serial, creation) end

        pid

    fun ref connect(nodename: String): (ConnectionSucceeded | ConnectionFailed) =>
        // simple single connection for now
        if connected() then
            Debug.out("already connected once")
            return ConnectionFailed
        end

        _connection = @opn_ei_new[Pointer[None]](_this_nodename.cstring(), _cookie.cstring(), _creation)

        if _connection.is_null() then
            return ConnectionFailed
        end

        _connection_id = @opn_ei_connect[I32](_connection, nodename.cstring())
        if _connection_id < 0 then
            disconnect()
            return ConnectionFailed
        end

        ConnectionSucceeded
        
    fun ref receive(): (EMessage | ReceiveFailed) =>
        if _connection_id < 0 then
            return ReceiveFailed
        end

        let message_p = @opn_ei_receive[Pointer[None]](_connection, _connection_id)
        if message_p == Pointer[None] then
            return ReceiveFailed
        end
        
        EMessage.from_cpointer(message_p)

    fun ref receive_with_timeout(timeout_ms: U32): (EMessage | ReceiveFailed | ReceiveTimedOut) =>
        if _connection_id < 0 then
            return ReceiveFailed
        end

        var timed_out: I32 = 0
        let message_p = @opn_ei_receive_tmo[Pointer[None]](_connection, _connection_id, timeout_ms, addressof timed_out)

        if timed_out != 0 then
            return ReceiveTimedOut
        end

        if message_p == Pointer[None] then
            return ReceiveFailed
        end
        
        EMessage.from_cpointer(message_p)

    fun send_with_timeout(to: ErlangPid, what: EMessage, timeout_ms: U32): (SentOk | SendFailed | SendTimedOut) =>
        if _connection_id < 0 then
            return SendFailed
        end

        var timed_out: I32 = 0
        let res = @opn_ei_send_tmo[I32](_connection, _connection_id, to.cpointer(), what.cpointer(), timeout_ms, addressof timed_out)

        if timed_out != 0 then
            return SendTimedOut
        end

        if res != 0 then
            return SendFailed
        end

        SentOk

    fun ref disconnect() =>
        if not connected() then 
            return
        end

        @opn_ei_destroy[None](addressof _connection)
        _connection = Pointer[None]
        _connection_id = -1

    fun connected(): Bool =>
        _connection != Pointer[None]

    fun _final() =>
        if _connection != Pointer[None] then
            @opn_ei_destroy[None](addressof _connection)
        end
