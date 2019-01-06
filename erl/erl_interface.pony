// todo: find a robust way to supply the dependencies
use "path:/usr/local/Cellar/erlang/21.2.2/lib/erlang/lib/erl_interface-3.10.4/lib/" if osx

use "lib:erl_interface" if osx
use "lib:ei" if osx

primitive ErlInterfaceInit
    fun apply() =>
        // void   erl_init(void *x, long y);
        @erl_init[None](Pointer[None], I32(0))

// erl_interface.h
class ErlInterface
    // constants:
    let _erl_tick: U32 = 0
    let _erl_msg: U32 = 1

    let buf_size: USize = 1024*16
    let buf: Array[U8] = Array[U8].init(0, buf_size)
    let emsg: ErlMessage = ErlMessage

    fun simple_connect(node: String, cookie: String) : I32 =>
        // -> c1@localhost
        var res = @erl_connect_init[I32](I32(1)/*id*/, cookie.cstring(), I8(0)/*instance*/)
        if res < 0 then
            return res
        end
        @erl_connect[I32](node.cstring())

    fun connect(node: String, cookie: String, node_name: String = "pony", hostname: String = "localhost", full_name: String = "pony@localhost") : I32 =>
        // -> c1@localhost
        var res = @erl_connect_xinit[I32](I32(1)/*id*/, cookie.cstring(), I8(0)/*instance*/)
        if res < 0 then
            return res
        end
        @erl_connect[I32](node.cstring())


    fun ref receive(sock: I32) : I32 =>
        """
        blocks until it receives a regular erlang message
        """
        //int    erl_receive_msg(int, unsigned char*, int, ErlMessage*)
        // @erl_receive_msg[I32](sock, buf.cpointer(), buf_size.i32(), MaybePointer[ErlMessage](emsg))
        @erl_receive[I32](sock, buf.cpointer(), buf_size.i32())

// int    erl_connect(char*);
// int    erl_connect_init(int, char*, short);
// int    erl_connect_xinit(char*,char*,char*,struct in_addr*,char*,short);

// iex --sname iex@localhost --cookie secretcookie

