use "erl"
use "debug"

actor PonyNode
    let _env : Env
    var erl : ErlInterface = NullInterface

    new create(env: Env) =>
        _env = env
        try 
            erl = EInterface("pony", "secretcookie") ?
        else
            _env.out.print("could not create a Pony node")
            Debug.err("could not create a Pony node")
        end

    be demo() =>
        if not erl.valid() then
            _env.out.print("an error happened: aborting")
            return
        end

        if not erl.connect("demo@localhost") then
            _env.out.print("could not connect")
            return
        end
        
        _env.out.print("connected")


        
        erl.receive()
        

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
