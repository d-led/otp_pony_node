use "lib:otp_pony_node_c"
use "debug"

class EMessage
    var message: Pointer[None]

    new create(message': Pointer[None]) =>
        message = message'

    fun ref length(): USize =>
        @opn_ei_message_length[USize](message)

    fun _final() =>
        if message != Pointer[None] then
            @opn_ei_message_destroy[None](addressof message)
        end
