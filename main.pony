use "path:/usr/local/Cellar/erlang/21.2.2/lib/erlang/lib/erl_interface-3.10.4/lib/" if osx

use "lib:erl_interface" if osx
use "lib:ei" if osx

primitive ErlInterfaceInit
    fun init() =>
        // void   erl_init(void *x, long y);
        @erl_init[None](Pointer[None], I32(0))

struct ErlMessage
    var mtype: I32 = 0
    // incomplete!!
    // todo
    new create() => None

// erl_interface.h
class ErlInterface
    let buf_size: USize = 1024*16
    let buf: Array[U8] = Array[U8].init(0, buf_size)
    let emsg: ErlMessage = ErlMessage

    fun simple_connect(cookie: String, node: String) : I32 =>
        // -> c1@localhost
        var res = @erl_connect_init[I32](I32(1)/*id*/, cookie.cstring(), I8(0)/*instance*/)
        if res < 0 then
            return res
        end
        @erl_connect[I32](node.cstring())

    fun ref receive(sock: I32) : I32 =>
        //int    erl_receive_msg(int, unsigned char*, int, ErlMessage*)
        // @erl_receive_msg[I32](sock, buf.cpointer(), buf_size.i32(), MaybePointer[ErlMessage](emsg))
        @erl_receive[I32](sock, buf.cpointer(), buf_size.i32())

// int    erl_connect(char*);
// int    erl_connect_init(int, char*, short);
// int    erl_connect_xinit(char*,char*,char*,struct in_addr*,char*,short);

// iex --sname iex@localhost --cookie secretcookie

actor Main
  new create(env: Env) =>
    ErlInterfaceInit.init()
    let erl = ErlInterface
    let sock = erl.simple_connect("secretcookie", "iex@localhost") 
    if sock < 0 then
        env.out.print("failed to connect")
        return
    end
    env.out.print("connected: " + sock.string())
    let name = String.from_cstring(@erl_thisnodename[Pointer[U8]]())
    // this is the node name to send messages to 
    env.out.print(name.string())

    while true do
        let res = erl.receive(sock)
        env.out.print(res.string())
    end
