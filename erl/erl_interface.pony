// todo: find a robust way to supply the dependencies
use "path:/usr/local/Cellar/erlang/21.2.2/lib/erlang/lib/erl_interface-3.10.4/lib/" if osx

use "lib:ei" if osx

interface ErlInterface
    fun valid(): Bool => false
    fun ref connect(nodename: String) : Bool
    fun ref receive() => None

class NullInterface
    fun valid(): Bool => false
    fun ref connect(nodename: String) : Bool => false
    fun ref receive() => None

struct ErlangPid
    var node: Array[U8] = Array[U8].init(0, /*MAXATOMLEN_UTF8*/ (255*4) + 1)
    var num: U32 = 0
    var serial: U32 = 0
    var creation: U32 = 0

struct EiNode
    var thishostname: Array[U8] = Array[U8].init(0, /*EI_MAXHOSTNAMELEN*/ 64+1)
    var thisalivename: Array[U8] = Array[U8].init(0, /*EI_MAXALIVELEN*/ 63+1)
    var ei_connect_cookie: Array[U8] = Array[U8].init(0, /*EI_MAX_COOKIE_SIZE*/ 512+1)
    var creation: I16 = 0
    embed self: ErlangPid = ErlangPid


// erl_interface.h
class EInterface
    let node: EiNode = EiNode

    fun valid(): Bool => true

    new create(nodename: String, cookie: String, creation: I16 = 0) ? =>
        // int ei_connect_init(ei_cnode* ec, const char* this_node_name, const char *cookie, short creation)
        if @ei_connect_init[I32](MaybePointer[EiNode](node), nodename.cstring(), cookie.cstring(), creation) < 0 then
            error
        end

    fun ref connect(nodename: String) : Bool =>
        // int ei_connect(ei_cnode* ec, char *nodename)
        @ei_connect[I32](MaybePointer[EiNode](node), nodename.cstring()) >= 0
    
    fun ref receive() => None
