// todo: find a robust way to supply the dependencies
use "path:/usr/local/Cellar/erlang/21.2.2/lib/erlang/lib/erl_interface-3.10.4/lib/" if osx

use "lib:ei" if osx

use "debug"

// see ei.h
struct ErlangPid
    var node: Array[U8] = Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1)
    var num: U32 = 0
    var serial: U32 = 0
    var creation: U32 = 0

    new create() => None

struct ErlangTrace
    var serial: I32 = 0
    var prev: I32 = 0
    embed from: ErlangPid = ErlangPid
    var label: I32 = 0
    var flags: I32 = 0

    new create() => None

struct ErlangMsg
    var v: I32 = 0
    embed from: ErlangPid = ErlangPid
    embed to: ErlangPid = ErlangPid
    var toname: Array[U8] = Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1)
    var cookie: Array[U8] = Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1)
    embed token: ErlangTrace = ErlangTrace

    new create() => None

struct EiNode
    var thishostname: Array[U8] = Array[U8].init(0, /*EI_MAXHOSTNAMELEN*/ 64+1)
    var thisalivename: Array[U8] = Array[U8].init(0, /*EI_MAXALIVELEN*/ 63+1)
    var ei_connect_cookie: Array[U8] = Array[U8].init(0, /*EI_MAX_COOKIE_SIZE*/ 512+1)
    var creation: I16 = 0
    embed self: ErlangPid = ErlangPid

    new create() => None

struct EiXBuff
    var buff: Pointer[U8] tag = Pointer[U8]
    var buffsz: I32 = 0
    var index: I32 = 0

    new create() => None


class EBuffer
    var xbuff: EiXBuff = EiXBuff

    new create() ? =>
        // int ei_x_new(ei_x_buff* x);
        if @ei_x_new[I32](MaybePointer[EiXBuff](xbuff)) < 0 then
            Debug.err("Failed: EBuffer.create()")
            error
        end

    fun ref destroy() =>
        // int ei_x_free(ei_x_buff* x);
        if @ei_x_free[I32](MaybePointer[EiXBuff](xbuff)) < 0 then
            Debug.err("Failed: EBuffer.destroy()")
        end

class EMessage
    let inner: ErlangMsg

    new create(inner': ErlangMsg) =>
        inner = inner'

// erl_interface.h
class EInterface
    let node: EiNode = EiNode

    fun valid(): Bool => true

    new create(nodename: String, cookie: String, creation: I16 = 0) ? =>
        // int ei_connect_init(ei_cnode* ec, const char* this_node_name, const char *cookie, short creation)
        if @ei_connect_init[I32](MaybePointer[EiNode](node), nodename.cstring(), cookie.cstring(), creation) < 0 then
            error
        end

    // todo: refactor connection into a class
    fun ref connect(nodename: String) : I32 =>
        // int ei_connect(ei_cnode* ec, char *nodename)
        @ei_connect[I32](MaybePointer[EiNode](node), nodename.cstring())
    
    fun ref receive(fd: I32) : EMessage ? =>
        let buf = EBuffer.create() ?
        var msg = ErlangMsg
        // int ei_xreceive_msg(int fd, erlang_msg* msg, ei_x_buff* x);
        if @ei_xreceive_msg[I32](fd, MaybePointer[ErlangMsg](msg), MaybePointer[EiXBuff](buf.xbuff)) < 0 then
            Debug.err("Error: ei_xreceive_msg")
            error
        end
        // todo: parse the message
        buf.destroy()

        EMessage(consume msg)

    fun ref node_name() : String =>
        // const char *ei_thisnodename(ei_cnode *ec)
        String.from_cstring(@ei_thisnodename[Pointer[U8]](MaybePointer[EiNode](node))).string()