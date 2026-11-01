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
use @opn_ei_close_connection[I32](connection: I32)
use @opn_ei_publish[I32](node: Pointer[None] tag, port: U32,
  bound: Pointer[U32] tag)
use @opn_ei_unpublish[I32](node: Pointer[None] tag)
use @opn_ei_retain[None](node: Pointer[None] tag)
use @opn_ei_accept[I32](node: Pointer[None] tag, listener: I32,
  peer: Pointer[U8] tag, peer_cap: USize)
use @opn_ei_accept_tmo[I32](node: Pointer[None] tag, listener: I32, ms: U32,
  peer: Pointer[U8] tag, peer_cap: USize, timed_out: Pointer[I32] tag)
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
  closes the connection without throwing the node away.  `dispose` releases
  both, and an interface that has been disposed stays inert.
  """

  let _this_nodename: String
  let _cookie: String
  let _creation: U32
  var _node: Pointer[None] = Pointer[None]
  var _connection: Connection = -1
  var _listener: Connection = -1
  var _published_port: U32 = 0
  var _peer: String = ""
  var _disposed: Bool = false

  new create(this_nodename': String, cookie': String, creation': U32 = 0) =>
    _this_nodename = this_nodename'
    _cookie = cookie'
    _creation = creation'

  new relay(node: Pointer[None] ref, connection: Connection,
    peer: String = "")
  =>
    """
    A connection that arrived on another interface's listening socket.

    It shares that interface's node, and holds the node until both are done
    with it, so neither order of disposal leaves the other with a freed node.
    """
    @opn_ei_retain(node)
    _this_nodename = ""
    _cookie = ""
    _creation = 0
    _node = node
    _connection = connection
    _peer = peer

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
    if _connection >= 0 then
      @opn_ei_close_connection(_connection)
      _connection = -1
    end

  fun ref publish(port: U32): PublishResult =>
    """
    Registers this node's name with epmd and listens for connections on
    `port`, or on a port of the system's choosing when it is zero, so that
    other nodes can connect to this one.

    The name is withdrawn with `unpublish`, or when the process ends.
    """
    if (_listener >= 0) or _disposed then return PublishFailed end
    if not _ensure_node() then return PublishFailed end

    var bound: U32 = 0
    let listener = @opn_ei_publish(_node, port, addressof bound)
    if listener < 0 then return PublishFailed end

    _listener = listener
    _published_port = bound
    Published

  fun box published_port(): U32 =>
    """The port the listening socket took, and zero before `publish`."""
    _published_port

  fun ref unpublish() =>
    """Withdraws the name from epmd and closes the listening socket."""
    if _listener >= 0 then
      @opn_ei_close_connection(_listener)
      _listener = -1
      _published_port = 0
    end

    if not (_disposed or _node.is_null()) then
      @opn_ei_unpublish(_node)
    end

  fun ref accept(): AcceptResult =>
    """Waits for another node to connect to this one."""
    _accept(0)

  fun ref accept_with_timeout(timeout_ms: U32): AcceptResult =>
    """
    Waits up to `timeout_ms` for another node to connect; zero waits forever
    and is the same as `accept`.
    """
    _accept(timeout_ms)

  fun box peer_nodename(): String =>
    """
    The node at the other end of an accepted connection, and empty for a
    connection this interface opened itself.
    """
    _peer

  fun ref _accept(timeout_ms: U32): AcceptResult =>
    if (_listener < 0) or _disposed then return AcceptFailed end

    let peer = Strings.buffer(_node_capacity())
    var timed_out: I32 = 0

    let connection =
      if timeout_ms == 0 then
        @opn_ei_accept(_node, _listener, peer.cpointer(), peer.size())
      else
        @opn_ei_accept_tmo(_node, _listener, timeout_ms, peer.cpointer(),
          peer.size(), addressof timed_out)
      end

    if connection < 0 then
      if timed_out != 0 then AcceptTimedOut else AcceptFailed end
    else
      EInterface.relay(_node, connection, Strings.null_trimmed(peer))
    end

  fun ref dispose() =>
    """
    Releases the connection and the node now, not when the collector runs.
    A disposed interface does nothing on any later call.
    """
    if _disposed then return end
    _disposed = true
    disconnect()
    unpublish()
    if not _node.is_null() then
      @opn_ei_destroy(_node)
      _node = Pointer[None]
    end

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

  fun ref send_to(to: ErlangPid, what: EMessage ref, timeout_ms: U32)
    : SendResult
  =>
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
    if _disposed then return false end
    if _node.is_null() then
      _node = @opn_ei_new(_this_nodename.cstring(), _cookie.cstring(),
        _creation)
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
    if _listener >= 0 then
      @opn_ei_close_connection(_listener)
    end
    if _connection >= 0 then
      @opn_ei_close_connection(_connection)
    end
    if not _node.is_null() then
      @opn_ei_destroy(_node)
    end
