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
        let connected = erl.connect("demo@localhost")
        match connected
        | ConnectionFailed => 
          _env.out.print("Connection failed. Exiting")
          return
        | ConnectionSucceeded =>
          _env.out.print("Connection successful")
        end

        while true do  
          let receved = erl.receive()
          match receved
          | ReceiveFailed =>
            _env.out.print("Receive failed. Disconnecting")
            break
          // todo: full message
          | let s: String =>
            _env.out.print("Received: " + s)
            break //for now
          end
        end

        erl.disconnect()

        

actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
