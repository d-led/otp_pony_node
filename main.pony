use "otp"

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
