primitive ConnectionFailed
primitive ConnectionSucceeded
primitive ReceiveFailed
primitive ReceiveTimedOut
primitive SentOk
primitive SendFailed
primitive SendTimedOut
primitive Published
primitive PublishFailed
primitive AcceptFailed
primitive AcceptTimedOut

type Connection is I32
type ConnectionStatus is (ConnectionSucceeded | ConnectionFailed)
type ReceiveResult is (EMessage | ReceiveFailed | ReceiveTimedOut)
type SendResult is (SentOk | SendFailed | SendTimedOut)
type PublishResult is (Published | PublishFailed)
type AcceptResult is (EInterface | AcceptFailed | AcceptTimedOut)

primitive TermType
  """
  The external term format tags, as defined by `ei.h`.

  Every term on the wire starts with one of these; the decoder dispatches on
  it and the printer uses it to describe terms it cannot look inside.
  """

  fun none(): I32 => 0

  fun small_integer(): I32 => 'a'
  fun integer(): I32 => 'b'
  fun float(): I32 => 'c'
  fun new_float(): I32 => 'F'
  fun atom(): I32 => 'd'
  fun small_atom(): I32 => 's'
  fun atom_utf8(): I32 => 'v'
  fun small_atom_utf8(): I32 => 'w'
  fun reference(): I32 => 'e'
  fun new_reference(): I32 => 'r'
  fun newer_reference(): I32 => 'Z'
  fun port(): I32 => 'f'
  fun new_port(): I32 => 'Y'
  fun v4_port(): I32 => 'x'
  fun pid(): I32 => 'g'
  fun new_pid(): I32 => 'X'
  fun small_tuple(): I32 => 'h'
  fun large_tuple(): I32 => 'i'
  fun nil(): I32 => 'j'
  fun string(): I32 => 'k'
  fun list(): I32 => 'l'
  fun binary(): I32 => 'm'
  fun bit_binary(): I32 => 'M'
  fun small_big(): I32 => 'n'
  fun large_big(): I32 => 'o'
  fun new_fun(): I32 => 'p'
  fun map(): I32 => 't'
  fun erl_fun(): I32 => 'u'
  fun erl_export(): I32 => 'q'

  fun is_atom(type_tag: I32): Bool =>
    (type_tag == atom()) or (type_tag == small_atom())
      or (type_tag == atom_utf8()) or (type_tag == small_atom_utf8())

  fun name(type_tag: I32): String =>
    """A readable name for a type tag, for diagnostics."""
    if is_atom(type_tag) then
      "atom"
    elseif (type_tag == small_integer()) or (type_tag == integer()) then
      "integer"
    elseif (type_tag == small_big()) or (type_tag == large_big()) then
      "big integer"
    elseif (type_tag == float()) or (type_tag == new_float()) then
      "float"
    elseif (type_tag == binary()) then
      "binary"
    elseif type_tag == bit_binary() then
      "bitstring"
    elseif type_tag == string() then
      "string"
    elseif type_tag == list() then
      "list"
    elseif type_tag == nil() then
      "empty list"
    elseif (type_tag == small_tuple()) or (type_tag == large_tuple()) then
      "tuple"
    elseif type_tag == map() then
      "map"
    elseif (type_tag == pid()) or (type_tag == new_pid()) then
      "pid"
    elseif (type_tag == port()) or (type_tag == new_port())
      or (type_tag == v4_port())
    then
      "port"
    elseif (type_tag == reference()) or (type_tag == new_reference())
      or (type_tag == newer_reference())
    then
      "reference"
    elseif (type_tag == new_fun()) or (type_tag == erl_fun()) then
      "fun"
    elseif type_tag == erl_export() then
      "export"
    else
      "unknown"
    end

primitive MessageType
  """
  Why a message arrived, mirroring `erlang_msg.msgtype`.
  """

  fun none(): I32 => 0
  fun link(): I32 => 1
  fun send(): I32 => 2
  fun exit(): I32 => 3
  fun unlink(): I32 => 4
  fun node_link(): I32 => 5
  fun reg_send(): I32 => 6
  fun group_leader(): I32 => 7
  fun exit2(): I32 => 8
  fun monitor(): I32 => 19
  fun demonitor(): I32 => 20
  fun monitor_exit(): I32 => 21

  fun name(msgtype: I32): String =>
    match msgtype
    | 0 => "local"
    | 1 => "LINK"
    | 2 => "SEND"
    | 3 => "EXIT"
    | 4 => "UNLINK"
    | 5 => "NODE_LINK"
    | 6 => "REG_SEND"
    | 7 => "GROUP_LEADER"
    | 8 => "EXIT2"
    | 19 => "MONITOR_P"
    | 20 => "DEMONITOR_P"
    | 21 => "MONITOR_P_EXIT"
    else msgtype.string()
    end

primitive ErlError
  """
  Turns the C level `erl_errno` into something a person can act on.
  """

  fun none(): I32 => 0
  fun generic(): I32 => -1
  fun no_daemon(): I32 => -2
  fun no_port(): I32 => -3
  fun connect_fail(): I32 => -4
  fun timeout(): I32 => -5
  fun no_remote(): I32 => -6

  fun describe(code: I32): String =>
    match code
    | 0 => "no error"
    | -1 => "error of some kind"
    | -2 => "no contact with epmd"
    | -3 => "no port received from epmd"
    | -4 => "connecting to the Erlang node failed"
    | -5 => "a timeout expired"
    | -6 => "cannot execute rsh"
    | 5 => "input/output error"
    | 60 => "a timeout expired"
    | 61 => "nothing is listening there"
    | 98 => "the port is already in use"
    | 104 => "the connection was reset"
    | 110 => "a timeout expired"
    | 111 => "nothing is listening there"
    else "erl_errno " + code.string()
    end
