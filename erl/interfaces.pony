interface ErlInterface
    fun valid(): Bool => false
    fun ref connect(nodename: String) : I32
    fun ref receive(fd: I32) : EMessage ?
    fun ref node_name() : String 

class NullInterface
    fun valid(): Bool => false
    fun ref connect(nodename: String) : I32 => -1
    fun ref receive(fd: I32) : EMessage ? => error
    fun ref node_name() : String => ""