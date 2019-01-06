use "erl"

actor PonyNode
    let _env : Env
    let erl : ErlInterface = ErlInterface

    new create(env: Env) =>
        _env = env

    be demo() =>
        let sock = erl.simple_connect("demo@localhost", "secretcookie") 
        if sock < 0 then
            _env.out.print("failed to connect")
            return
        end
        _env.out.print("connected: " + sock.string())
        let name = String.from_cstring(@erl_thisnodename[Pointer[U8]]())
        // this is the node name to send messages to 
        _env.out.print(name.string())

        while true do
            let res = erl.receive(sock)
            if res < 0 then
                break
            end
            _env.out.print("recieved from the connected node: "+ res.string() + " bytes")
        end

        _env.out.print("disconnected")


actor Main
  new create(env: Env) =>
    ErlInterfaceInit()
    let n = PonyNode(env)
    n.demo()