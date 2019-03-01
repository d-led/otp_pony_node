use "erl"
use "debug"

actor PonyNode
    let _env : Env
    var erl : ErlInterface = NullInterface

    new create(env: Env) =>
        _env = env
        try 
            erl = EInterface("pony", "secretcookie") ?
            erl.set_tracelevel(5)
        else
            _env.out.print("could not create a Pony node")
            Debug.err("could not create a Pony node")
        end

    be demo() =>
        if not erl.valid() then
            _env.out.print("an error happened: aborting")
            return
        end

        let conn = erl.connect("demo@localhost")

        if conn < 0 then
            _env.out.print("could not connect")
            return
        end

        _env.out.print("connected as " + erl.node_name())

        while true do  
            try
                var msg: EMessage = erl.receive(conn) ?
                // String.from_array(msg.inner.from.node)...
                // msg.inner.from.node.copy_to(node)
                _env.out.print("received a message from pid:" + msg.inner.from.num.string())
            else
                _env.out.print("failed receiving")
                break
            end
        end
        

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
