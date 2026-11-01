use "lib:otp_pony_node_c"

use @opn_erl_errno[I32]()
use @opn_set_tracelevel[None](level: I32)
use @opn_ei_get_tracelevel[I32]()
use @opn_ei_set_compat_rel[None](rel: U32)
use @opn_ei_new[Pointer[None]](this_nodename: Pointer[U8] tag,
  cookie: Pointer[U8] tag, creation: U32)
use @opn_ei_destroy[None](node: Pointer[None] tag)
use @opn_ei_connect[I32](node: Pointer[None] tag, nodename: Pointer[U8] tag)
use @opn_ei_connect_tmo[I32](node: Pointer[None] tag, nodename: Pointer[U8] tag,
  timeout_ms: U32)
use @opn_ei_self_pid[I32](node: Pointer[None] tag, buffer: Pointer[U8] tag,
  capacity: USize, num: Pointer[U32] tag, serial: Pointer[U32] tag,
  creation: Pointer[U32] tag)
use @opn_ei_thisnodename[I32](node: Pointer[None] tag, buffer: Pointer[U8] tag,
  capacity: USize)
use @opn_ei_thishostname[I32](node: Pointer[None] tag, buffer: Pointer[U8] tag,
  capacity: USize)
use @opn_ei_thisalivename[I32](node: Pointer[None] tag, buffer: Pointer[U8] tag,
  capacity: USize)
use @opn_ei_receive_tmo[Pointer[None]](connection: I32, timeout_ms: U32,
  timed_out: Pointer[I32] tag)
use @opn_ei_send_tmo[I32](connection: I32, node: Pointer[U8] tag, num: U32,
  serial: U32, creation: U32, what: Pointer[None] tag, timeout_ms: U32,
  timed_out: Pointer[I32] tag)
use @opn_ei_reg_send_tmo[I32](node: Pointer[None] tag, connection: I32,
  server: Pointer[U8] tag, what: Pointer[None] tag, timeout_ms: U32,
  timed_out: Pointer[I32] tag)

class EInterface
  """
  A C node: this side of a connection to a running Erlang/Elixir node.

  One `EInterface` owns one connection.  `connect` creates the node on first
  use, so the node name is available before it is connected, and `disconnect`
  closes the connection without throwing the node away.
  """

  let _this_nodename: String
  let _cookie: String
  let _creation: U32
  var _node: Pointer[None] = Pointer[None]
  var _connection: Connection = -1

  new create(this_nodename': String, cookie': String, creation': U32 = 0) =>
    _this_nodename = this_nodename'
    _cookie = cookie'
    _creation = creation'

  fun connected(): Bool =>
    _connection >= 0

  fun ref connect(nodename: String): ConnectionStatus =>
    """Connects to a node, blocking until it answers."""
    if connected() then return ConnectionFailed end
    if not _ensure_node() then return ConnectionFailed end

    _connection = @opn_ei_connect(_node, nodename.cstring())
    if _connection < 0 then
      _connection = -1
      return ConnectionFailed
    end

    ConnectionSucceeded

  fun ref connect_with_timeout(nodename: String, timeout_ms: U32)
    : ConnectionStatus
  =>
    """Connects to a node, giving up after `timeout_ms` milliseconds."""
    if connected() then return ConnectionFailed end
    if not _ensure_node() then return ConnectionFailed end

    _connection = @opn_ei_connect_tmo(_node, nodename.cstring(), timeout_ms)
    if _connection < 0 then
      _connection = -1
      return ConnectionFailed
    end

    ConnectionSucceeded

  fun ref disconnect() =>
    """Closes the connection.  The node itself stays usable for a new one."""
    _connection = -1

  fun ref receive(): ReceiveResult =>
    """Waits for a message."""
    receive_with_timeout(0)

  fun ref receive_with_timeout(timeout_ms: U32): ReceiveResult =>
    """
    Waits for a message, giving up after `timeout_ms`; zero means wait forever
    and is the same as `receive`.
    """
    if not connected() then return ReceiveFailed end

    var timed_out: I32 = 0
    let message = @opn_ei_receive_tmo(_connection, timeout_ms,
      addressof timed_out)

    if message.is_null() then
      if timed_out != 0 then ReceiveTimedOut else ReceiveFailed end
    else
      EMessage.from_cpointer(message)
    end

  fun ref send_to(to: ErlangPid, what: EMessage ref, timeout_ms: U32): SendResult =>
    """Sends an encoded message to a process."""
    if not connected() then return SendFailed end

    var timed_out: I32 = 0
    let result = @opn_ei_send_tmo(_connection, to.node.cstring(), to.num,
      to.serial, to.creation, what.cpointer(), timeout_ms, addressof timed_out)

    _send_result(result, timed_out)

  fun ref send_to_registered(server_name: String, what: EMessage ref,
    timeout_ms: U32)
    : SendResult
  =>
    """Sends an encoded message to a process registered under a name."""
    if not connected() then return SendFailed end

    var timed_out: I32 = 0
    let result = @opn_ei_reg_send_tmo(_node, _connection, server_name.cstring(),
      what.cpointer(), timeout_ms, addressof timed_out)

    _send_result(result, timed_out)

  fun ref self_pid(): ErlangPid ? =>
    """This node's own pid, as the remote node sees it."""
    if not _ensure_node() then error end

    let buffer = Strings.buffer(_node_capacity())
    var num: U32 = 0
    var serial: U32 = 0
    var creation: U32 = 0
    let result = @opn_ei_self_pid(_node, buffer.cpointer(), buffer.size(),
      addressof num, addressof serial, addressof creation)
    if result != 0 then error end

    ErlangPid(Strings.null_trimmed(buffer), num, serial, creation)

  fun ref this_nodename(): String =>
    _read_name(0)

  fun ref this_hostname(): String =>
    _read_name(1)

  fun ref this_alivename(): String =>
    _read_name(2)

  fun set_tracelevel(level: I32) =>
    @opn_set_tracelevel(level)

  fun get_tracelevel(): I32 =>
    @opn_ei_get_tracelevel()

  fun set_compat_rel(rel: U32) =>
    @opn_ei_set_compat_rel(rel)

  fun last_error(): String =>
    """The reason the last call into the C layer failed, as far as it knows."""
    ErlError.describe(@opn_erl_errno())

  fun ref _ensure_node(): Bool =>
    if _node.is_null() then
      _node = @opn_ei_new(_this_nodename.cstring(), _cookie.cstring(), _creation)
    end
    not _node.is_null()

  fun ref _read_name(kind: U8): String =>
    """
    Reads one of the three names `ei` knows for this node: 0 the node name,
    1 the host name, 2 the alive name.
    """
    if not _ensure_node() then return "" end

    let buffer = Strings.buffer(_node_capacity())

    let result = match kind
    | 0 => @opn_ei_thisnodename(_node, buffer.cpointer(), buffer.size())
    | 1 => @opn_ei_thishostname(_node, buffer.cpointer(), buffer.size())
    else @opn_ei_thisalivename(_node, buffer.cpointer(), buffer.size())
    end

    if result != 0 then return "" end
    Strings.null_trimmed(buffer)

  fun _send_result(result: I32, timed_out: I32): SendResult =>
    if timed_out != 0 then
      SendTimedOut
    elseif result != 0 then
      SendFailed
    else
      SentOk
    end

  fun _node_capacity(): USize =>
    """`MAXATOMLEN_UTF8` from `ei.h`: a node name, NUL included."""
    let max_atom_length: USize = 255 * 4
    max_atom_length + 1

  fun _final() =>
    if not _node.is_null() then
      @opn_ei_destroy(_node)
    end
