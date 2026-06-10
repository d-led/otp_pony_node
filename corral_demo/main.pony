use "erl_interface_pony"
use "path:_corral/github_com_d_led_otp_pony_node"

actor Main
  new create(env: Env) =>
    env.out.print("Corral Demo: Initializing EInterface...")
    
    // Initialize node interface
    let erl = EInterface("pony_demo_node", "secretcookie")
    
    // Demonstrate building, encoding, and recursively decoding Erlang terms
    let m = EMessage.begin()
    if not m.valid() then
      env.out.print("Error: EMessage is invalid")
      return
    end
    
    // Structure: {"demo_hello", "hello from corral dependency!"}
    m.encode_tuple_header(2)
    m.encode_atom("demo_hello")
    m.encode_binary("hello from corral dependency!")
    
    env.out.print("Corral Demo: Decoding encoded ErlangTerm...")
    match ErlangTermDecoder.decode(m)
    | let root_tuple: ErlangTuple =>
      env.out.print("Decoded root tuple with " + root_tuple.elements.size().string() + " elements:")
      try
        match root_tuple.elements(0)?
        | let a: ErlangAtom =>
          env.out.print("  - Element 0 (Atom): " + a.name)
        end
        
        match root_tuple.elements(1)?
        | let b: ErlangBinary =>
          env.out.print("  - Element 1 (Binary): " + b.value)
        end
      end
    else
      env.out.print("Error: failed to decode ErlangTerm")
    end
