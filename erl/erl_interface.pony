use "lib:otp_pony_node_c"
use "debug"

class EInterface
    let nodename: String
    let cookie: String
    let creation: I16

    new create(nodename': String, cookie': String, creation': I16 = 0) =>
        nodename = nodename'
        cookie = cookie'
        creation = creation'

    fun set_tracelevel(level: I32) =>
        // void ei_set_tracelevel(int level)
        @opn_set_tracelevel[None](level)

    fun ref connect() =>
        // int ei_connect_init(ei_cnode* ec, const char* this_node_name, const char *cookie, short creation)
        let res = @opn_ei_new[Pointer[None]](nodename.cstring(), cookie.cstring(), creation)
        Debug.out("res: " + res.usize().string())
