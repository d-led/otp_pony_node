class val ErlangPid
    let node: String
    let num: U32
    let serial: U32
    let creation: U32

    new create(node': String, num': U32, serial': U32, creation': U32) =>
        node = node'
        num = num'
        serial = serial'
        creation = creation'
