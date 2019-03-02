use "erl"
use "debug"

use "path:./"

actor PonyNode
    let _env : Env
    let erl: EInterface

    new create(env: Env) =>
        _env = env
        erl = EInterface("pony", "secretcookie")
        // erl.set_tracelevel(5)

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
          // todo: receive with timeout
          let receved = erl.receive()
          match receved
          | ReceiveFailed =>
            _env.out.print("Receive failed. Disconnecting")
            break
          // todo: full message
          | let m: EMessage =>
            _env.out.print("Received: " + m.length().string() + "bytes")
              (let a, let s) = m.atom_at(m.header_size)
              match a
              | let text: String =>
                _env.out.print("First atom: " + text)
              else
                _env.out.print("Expected an atom, but failed")
              end
          end
        end

        erl.disconnect()



actor Main
  new create(env: Env) =>
    let n = PonyNode(env)
    n.demo()
