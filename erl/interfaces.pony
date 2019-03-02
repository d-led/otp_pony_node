primitive ConnectionFailed
primitive ConnectionSucceeded
primitive ReceiveFailed

type Connection is I32

primitive TermType
    fun none(): U8 => 0
    // values from OTP: ei.h
    fun t_ERL_SMALL_INTEGER_EXT(): U8 => 'a'
    fun t_ERL_INTEGER_EXT(): U8 => 'b'
    fun t_ERL_FLOAT_EXT(): U8 => 'c'
    fun t_NEW_FLOAT_EXT(): U8 => 'F'
    fun t_ERL_ATOM_EXT(): U8 => 'd'
    fun t_ERL_SMALL_ATOM_EXT(): U8 => 's'
    fun t_ERL_ATOM_UTF8_EXT(): U8 => 'v'
    fun t_ERL_SMALL_ATOM_UTF8_EXT(): U8 => 'w'
    fun t_ERL_REFERENCE_EXT(): U8 => 'e'
    fun t_ERL_NEW_REFERENCE_EXT(): U8 => 'r'
    fun t_ERL_NEWER_REFERENCE_EXT(): U8 => 'Z'
    fun t_ERL_PORT_EXT(): U8 => 'f'
    fun t_ERL_NEW_PORT_EXT(): U8 => 'Y'
    fun t_ERL_PID_EXT(): U8 => 'g'
    fun t_ERL_NEW_PID_EXT(): U8 => 'X'
    fun t_ERL_SMALL_TUPLE_EXT(): U8 => 'h'
    fun t_ERL_LARGE_TUPLE_EXT(): U8 => 'i'
    fun t_ERL_NIL_EXT(): U8 => 'j'
    fun t_ERL_STRING_EXT(): U8 => 'k'
    fun t_ERL_LIST_EXT(): U8 => 'l'
    fun t_ERL_BINARY_EXT(): U8 => 'm'
    fun t_ERL_SMALL_BIG_EXT(): U8 => 'n'
    fun t_ERL_LARGE_BIG_EXT(): U8 => 'o'
    fun t_ERL_NEW_FUN_EXT(): U8 => 'p'
    fun t_ERL_MAP_EXT(): U8 => 't'
    fun t_ERL_FUN_EXT(): U8 => 'u'
