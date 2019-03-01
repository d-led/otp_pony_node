use "erl"
use "debug"

use "path:./"

actor PonyNode
    let _env : Env
    let erl: EInterface

    new create(env: Env) =>
        _env = env
        erl = EInterface("pony", "secretcookie")
        erl.set_tracelevel(5)

    be demo() =>
        let conn = erl.connect()

        // if conn < 0 then
        //     _env.out.print("could not connect")
        //     return
        // end

        // _env.out.print("connected as " + erl.node_name())

        // while true do  
        //     try
        //         var msg: EMessage = erl.receive(conn) ?
        //         // String.from_array(msg.inner.from.node)...
        //         // msg.inner.from.node.copy_to(node)
        //         _env.out.print("received a message from pid:" + msg.inner.from.num.string())
        //     else
        //         _env.out.print("failed receiving")
        //         break
        //     end
        // end
        

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
