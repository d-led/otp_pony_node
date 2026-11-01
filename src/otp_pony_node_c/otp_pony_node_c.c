#include "otp_pony_node_c.h"

#include <ei.h>

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <pthread.h>
#endif

/* erl_interface keeps process wide state and builds it on first use: the node
 * a Pony program is seen as, and the mutexes its host name lookups take.
 * Two actors creating a node at the same moment entered that setup at once and
 * left one of them waiting for a lock nothing would release.  Creation and
 * connection take this lock so that ei is never entered for the first time
 * from two threads. */
#if defined(_WIN32)
static SRWLOCK opn_ei_lock = SRWLOCK_INIT;
static void opn_ei_lock_acquire(void) { AcquireSRWLockExclusive(&opn_ei_lock); }
static void opn_ei_lock_release(void) { ReleaseSRWLockExclusive(&opn_ei_lock); }
#else
static pthread_mutex_t opn_ei_lock = PTHREAD_MUTEX_INITIALIZER;
static void opn_ei_lock_acquire(void) { pthread_mutex_lock(&opn_ei_lock); }
static void opn_ei_lock_release(void) { pthread_mutex_unlock(&opn_ei_lock); }
#endif

struct _opn_ei_t
{
    ei_cnode cnode;
};

struct _opn_ei_message_t
{
    erlang_msg msg;
    ei_x_buff buff;
};

/* Copies exactly `len` bytes of an erlang node name into a NUL terminated
 * buffer.  Node names are bounded by MAXATOMLEN_UTF8, callers still pass a
 * capacity so a malformed term cannot overrun them. */
static int copy_node(char *dst, size_t cap, const char *node, size_t len)
{
    if (!dst || cap == 0)
        return -1;
    if (!node) {
        dst[0] = '\0';
        return -1;
    }

    if (len == 0)
        len = strlen(node);
    if (len >= cap) {
        memcpy(dst, node, cap - 1);
        dst[cap - 1] = '\0';
        return -1;
    }

    memcpy(dst, node, len);
    dst[len] = '\0';
    return 0;
}

static int index_is_sane(const opn_ei_message_t *self, int index)
{
    return self && index >= 0 && index < self->buff.index;
}

/* erl_interface reports a timeout either as its own ERL_TIMEOUT return value
 * or through the platform errno, so both count. */
static int is_timeout(int result)
{
    return (result == ERL_TIMEOUT) || (erl_errno == ETIMEDOUT)
           || (erl_errno == ERL_TIMEOUT);
}

/* A term declares its payload length in its own bytes, and ei_decode_* takes
 * no capacity, so a declared length is only safe once it fits in what has
 * actually arrived.  Reads past ei_x_buff would come out of the heap. */
static int payload_fits(const opn_ei_message_t *self, int index, int size)
{
    return size >= 0 && index >= 0 && index < self->buff.index
           && size <= self->buff.index - index;
}

int opn_erl_errno(void)
{
    return erl_errno;
}

void opn_set_tracelevel(int level)
{
    ei_set_tracelevel(level);
}

int opn_ei_get_tracelevel(void)
{
    return ei_get_tracelevel();
}

void opn_ei_set_compat_rel(unsigned rel)
{
    ei_set_compat_rel(rel);
}

opn_ei_t *opn_ei_new(const char *this_nodename, const char *cookie,
                     unsigned creation)
{
    opn_ei_t *self;
    int initialised;

    if (!this_nodename || !cookie)
        return NULL;

    self = (opn_ei_t *)calloc(1, sizeof(*self));
    if (!self)
        return NULL;

    opn_ei_lock_acquire();
    ei_init();
    initialised =
        ei_connect_init(&self->cnode, this_nodename, cookie, creation);
    opn_ei_lock_release();

    if (initialised < 0) {
        free(self);
        return NULL;
    }

    return self;
}

void opn_ei_destroy(opn_ei_t *self)
{
    free(self);
}

int opn_ei_connect(opn_ei_t *self, const char *nodename)
{
    int connection;

    if (!self || !nodename)
        return -1;

    opn_ei_lock_acquire();
    connection = ei_connect(&self->cnode, (char *)nodename);
    opn_ei_lock_release();

    return connection;
}

int opn_ei_connect_tmo(opn_ei_t *self, const char *nodename, unsigned ms)
{
    int connection;

    if (!self || !nodename)
        return -1;

    opn_ei_lock_acquire();
    connection = ei_connect_tmo(&self->cnode, (char *)nodename, ms);
    opn_ei_lock_release();

    return connection;
}

int opn_ei_close_connection(int fd)
{
    if (fd < 0)
        return -1;

    return ei_close_connection(fd);
}

int opn_ei_self_pid(const opn_ei_t *self, char *node, size_t node_cap,
                    unsigned *num, unsigned *serial, unsigned *creation)
{
    erlang_pid *self_pid;

    if (!self || !num || !serial || !creation)
        return -1;

    self_pid = ei_self((ei_cnode *)&self->cnode);
    if (!self_pid)
        return -1;

    *num = self_pid->num;
    *serial = self_pid->serial;
    *creation = self_pid->creation;

    return copy_node(node, node_cap, self_pid->node, 0);
}

int opn_ei_thisnodename(const opn_ei_t *self, char *buffer, size_t cap)
{
    return self ? copy_node(buffer, cap, ei_thisnodename(&self->cnode), 0)
                : -1;
}

int opn_ei_thishostname(const opn_ei_t *self, char *buffer, size_t cap)
{
    return self ? copy_node(buffer, cap, ei_thishostname(&self->cnode), 0)
                : -1;
}

int opn_ei_thisalivename(const opn_ei_t *self, char *buffer, size_t cap)
{
    return self ? copy_node(buffer, cap, ei_thisalivename(&self->cnode), 0)
                : -1;
}

opn_ei_message_t *opn_ei_message_new(void)
{
    opn_ei_message_t *self = (opn_ei_message_t *)calloc(1, sizeof(*self));

    if (!self)
        return NULL;

    if (ei_x_new_with_version(&self->buff) < 0) {
        free(self);
        return NULL;
    }

    return self;
}

void opn_ei_message_destroy(opn_ei_message_t *self)
{
    if (!self)
        return;

    ei_x_free(&self->buff);
    free(self);
}

int opn_ei_message_length(const opn_ei_message_t *self)
{
    return self ? self->buff.index : 0;
}

int opn_ei_message_index(const opn_ei_message_t *self)
{
    return self ? self->buff.index : 0;
}

int opn_ei_message_truncate(opn_ei_message_t *self, int index)
{
    /* One is the version byte: everything after it belongs to terms. */
    if (!self || index < 1 || index > self->buff.index)
        return -1;

    self->buff.index = index;
    return 0;
}

int opn_ei_message_beginning(const opn_ei_message_t *self)
{
    int index = 0;
    int version = 0;

    if (!self)
        return 0;

    if (ei_decode_version(self->buff.buff, &index, &version) < 0)
        return 0;

    return index;
}

int opn_ei_message_type_at(const opn_ei_message_t *self, int index, int *type,
                           int *size)
{
    if (!self || !type || !size)
        return -1;

    *type = 0;
    *size = 0;

    return ei_get_type(self->buff.buff, &index, type, size);
}

int opn_ei_message_skip_term(const opn_ei_message_t *self, int index, int *next)
{
    int pos = index;

    if (!self || !next || !index_is_sane(self, index))
        return -1;

    if (ei_skip_term(self->buff.buff, &pos) < 0)
        return -1;

    *next = pos;
    return 0;
}

int opn_ei_message_copy(const opn_ei_message_t *self, int from, int to,
                        char *buffer, size_t cap)
{
    size_t len;

    if (!self || !buffer)
        return -1;
    if (from < 0 || to < from || to > self->buff.index)
        return -1;

    len = (size_t)(to - from);
    if (len > cap)
        return -1;

    memcpy(buffer, self->buff.buff + from, len);
    return (int)len;
}

int opn_ei_message_append_raw(opn_ei_message_t *self, const char *bytes,
                              int len)
{
    if (!self || !bytes || len < 0)
        return -1;

    return ei_x_append_buf(&self->buff, bytes, len);
}

int opn_ei_message_msgtype(const opn_ei_message_t *self)
{
    return self ? (int)self->msg.msgtype : 0;
}

int opn_ei_message_from(const opn_ei_message_t *self, char *node,
                        size_t node_cap, unsigned *num, unsigned *serial,
                        unsigned *creation)
{
    if (!self || !num || !serial || !creation)
        return -1;

    *num = self->msg.from.num;
    *serial = self->msg.from.serial;
    *creation = self->msg.from.creation;

    return copy_node(node, node_cap, self->msg.from.node, 0);
}

opn_ei_message_t *opn_ei_receive_tmo(int fd, unsigned ms, int *timed_out)
{
    opn_ei_message_t *self;
    int res;

    if (!timed_out)
        return NULL;

    *timed_out = 0;
    self = opn_ei_message_new();
    if (!self)
        return NULL;

    do {
        if (ms != 0)
            res = ei_xreceive_msg_tmo(fd, &self->msg, &self->buff, ms);
        else
            res = ei_xreceive_msg(fd, &self->msg, &self->buff);

        if (res < 0) {
            *timed_out = is_timeout(res);
            opn_ei_message_destroy(self);
            return NULL;
        }
    } while (res == ERL_TICK);

    return self;
}

/* Builds an erlang_pid from its parts so that callers never own a C struct. */
static int make_pid(erlang_pid *pid, const char *node, unsigned num,
                    unsigned serial, unsigned creation)
{
    memset(pid, 0, sizeof(*pid));
    if (copy_node(pid->node, sizeof(pid->node), node, 0) < 0)
        return -1;

    pid->num = num;
    pid->serial = serial;
    pid->creation = creation;
    return 0;
}

int opn_ei_send_tmo(int fd, const char *node, unsigned num, unsigned serial,
                    unsigned creation, const opn_ei_message_t *what,
                    unsigned ms, int *timed_out)
{
    erlang_pid to;
    int res;

    if (!what || !timed_out)
        return -1;

    *timed_out = 0;

    if (make_pid(&to, node, num, serial, creation) < 0)
        return -1;

    if (ms != 0)
        res = ei_send_tmo(fd, &to, what->buff.buff, what->buff.index, ms);
    else
        res = ei_send(fd, &to, what->buff.buff, what->buff.index);

    if (res < 0)
        *timed_out = is_timeout(res);

    return res;
}

int opn_ei_reg_send_tmo(opn_ei_t *self, int fd, const char *server,
                        const opn_ei_message_t *what, unsigned ms,
                        int *timed_out)
{
    int res;

    if (!self || !server || !what || !timed_out)
        return -1;

    *timed_out = 0;

    if (ms != 0)
        res = ei_reg_send_tmo(&self->cnode, fd, (char *)server, what->buff.buff,
                              what->buff.index, ms);
    else
        res = ei_reg_send(&self->cnode, fd, (char *)server, what->buff.buff,
                          what->buff.index);

    if (res < 0)
        *timed_out = is_timeout(res);

    return res;
}

/* The opn_ei_message_decode_* functions convert the `long` and `int` values
 * that ei.h uses into fixed-width types, so the published API has one width on
 * every platform. */
int opn_ei_message_decode_atom(const opn_ei_message_t *self, int *index,
                               char *buffer, size_t cap)
{
    int size = 0;
    int type = 0;

    if (!index_is_sane(self, *index) || !buffer || cap == 0)
        return -1;

    ei_get_type(self->buff.buff, index, &type, &size);
    if (!payload_fits(self, *index, size))
        return -1;

    return ei_decode_atom(self->buff.buff, index, buffer);
}

int opn_ei_message_decode_int(const opn_ei_message_t *self, int *index,
                              long long *value)
{
    EI_LONGLONG decoded = 0;

    if (!index_is_sane(self, *index) || !value)
        return -1;

    if (ei_decode_longlong(self->buff.buff, index, &decoded) < 0)
        return -1;

    *value = (long long)decoded;
    return 0;
}

int opn_ei_message_decode_double(const opn_ei_message_t *self, int *index,
                                 double *value)
{
    if (!index_is_sane(self, *index) || !value)
        return -1;

    return ei_decode_double(self->buff.buff, index, value);
}

int opn_ei_message_decode_binary(const opn_ei_message_t *self, int *index,
                                 char *buffer, size_t cap, long long *len)
{
    long decoded = 0;
    int size = 0;
    int type = 0;

    if (!index_is_sane(self, *index) || !buffer || !len)
        return -1;

    ei_get_type(self->buff.buff, index, &type, &size);
    if (!payload_fits(self, *index, size) || (size_t)size > cap)
        return -1;

    if (ei_decode_binary(self->buff.buff, index, buffer, &decoded) < 0)
        return -1;

    *len = (long long)decoded;
    return 0;
}

int opn_ei_message_decode_bitstring(const opn_ei_message_t *self, int *index,
                                    char *buffer, size_t cap, long long *len,
                                    int *used_bits_in_last_byte)
{
    const char *bits = NULL;
    unsigned int bit_offset = 0;
    size_t bit_count = 0;
    size_t byte_count;
    size_t arrived;

    if (!index_is_sane(self, *index) || !buffer || !len ||
            !used_bits_in_last_byte)
        return -1;

    arrived = (size_t)(self->buff.index - *index);

    if (ei_decode_bitstring(self->buff.buff, index, &bits, &bit_offset,
            &bit_count) < 0)
        return -1;

    if (bit_offset != 0)
        return -1;

    byte_count = (bit_count + 7) / 8;
    if (byte_count > cap || byte_count > arrived)
        return -1;

    if (byte_count > 0)
        memcpy(buffer, bits, byte_count);

    *len = (long long)byte_count;
    *used_bits_in_last_byte =
        (int)(bit_count % 8 == 0 ? (byte_count > 0 ? 8 : 0) : bit_count % 8);
    return 0;
}

int opn_ei_message_decode_string(const opn_ei_message_t *self, int *index,
                                 char *buffer, size_t cap)
{
    int size = 0;
    int type = 0;

    if (!index_is_sane(self, *index) || !buffer || cap == 0)
        return -1;

    ei_get_type(self->buff.buff, index, &type, &size);
    if (!payload_fits(self, *index, size) || (size_t)size > cap)
        return -1;

    return ei_decode_string(self->buff.buff, index, buffer);
}

int opn_ei_message_decode_list_header(const opn_ei_message_t *self, int *index,
                                      int *arity)
{
    if (!index_is_sane(self, *index) || !arity)
        return -1;

    return ei_decode_list_header(self->buff.buff, index, arity);
}

int opn_ei_message_decode_tuple_header(const opn_ei_message_t *self, int *index,
                                       int *arity)
{
    if (!index_is_sane(self, *index) || !arity)
        return -1;

    return ei_decode_tuple_header(self->buff.buff, index, arity);
}

int opn_ei_message_decode_map_header(const opn_ei_message_t *self, int *index,
                                     int *arity)
{
    if (!index_is_sane(self, *index) || !arity)
        return -1;

    return ei_decode_map_header(self->buff.buff, index, arity);
}

int opn_ei_message_decode_pid(const opn_ei_message_t *self, int *index,
                              char *node, size_t node_cap, unsigned *num,
                              unsigned *serial, unsigned *creation)
{
    erlang_pid pid;

    if (!index_is_sane(self, *index) || !num || !serial || !creation)
        return -1;

    memset(&pid, 0, sizeof(pid));
    if (ei_decode_pid(self->buff.buff, index, &pid) < 0)
        return -1;

    *num = pid.num;
    *serial = pid.serial;
    *creation = pid.creation;

    return copy_node(node, node_cap, pid.node, 0);
}

int opn_ei_message_decode_port(const opn_ei_message_t *self, int *index,
                               char *node, size_t node_cap,
                               unsigned long long *id, unsigned *creation)
{
    erlang_port port;

    if (!index_is_sane(self, *index) || !id || !creation)
        return -1;

    memset(&port, 0, sizeof(port));
    if (ei_decode_port(self->buff.buff, index, &port) < 0)
        return -1;

    *id = (unsigned long long)port.id;
    *creation = port.creation;

    return copy_node(node, node_cap, port.node, 0);
}

int opn_ei_message_decode_ref(const opn_ei_message_t *self, int *index,
                              char *node, size_t node_cap, unsigned *ids,
                              int ids_cap, int *id_count, unsigned *creation)
{
    erlang_ref ref;
    int count;
    int i;

    if (!index_is_sane(self, *index) || !ids || !id_count || !creation)
        return -1;

    memset(&ref, 0, sizeof(ref));
    if (ei_decode_ref(self->buff.buff, index, &ref) < 0)
        return -1;

    count = ref.len;
    if (count < 0 || count > 5 || count > ids_cap)
        return -1;

    for (i = 0; i < count; i++)
        ids[i] = ref.n[i];

    *id_count = count;
    *creation = ref.creation;

    return copy_node(node, node_cap, ref.node, 0);
}

int opn_ei_message_encode_atom(opn_ei_message_t *self, const char *what)
{
    if (!self || !what)
        return -1;

    return ei_x_encode_atom(&self->buff, what);
}

int opn_ei_message_encode_int(opn_ei_message_t *self, long long value)
{
    if (!self)
        return -1;

    return ei_x_encode_longlong(&self->buff, (EI_LONGLONG)value);
}

int opn_ei_message_encode_double(opn_ei_message_t *self, double value)
{
    if (!self)
        return -1;

    return ei_x_encode_double(&self->buff, value);
}

int opn_ei_message_encode_binary(opn_ei_message_t *self, const char *what,
                                 int len)
{
    if (!self || len < 0 || (!what && len > 0))
        return -1;

    return ei_x_encode_binary(&self->buff, what, len);
}

int opn_ei_message_encode_bitstring(opn_ei_message_t *self, const char *what,
                                    int len, int used_bits_in_last_byte)
{
    size_t bits;

    if (!self || len < 0 || (!what && len > 0))
        return -1;

    if (len == 0)
        return ei_x_encode_bitstring(&self->buff, "", 0, 0);

    if (used_bits_in_last_byte < 1 || used_bits_in_last_byte > 8)
        return -1;

    bits = (size_t)(len - 1) * 8 + (size_t)used_bits_in_last_byte;
    return ei_x_encode_bitstring(&self->buff, what, 0, bits);
}

int opn_ei_message_encode_string(opn_ei_message_t *self, const char *what,
                                 int len)
{
    if (!self || len < 0 || (!what && len > 0))
        return -1;

    return ei_x_encode_string_len(&self->buff, what, len);
}

int opn_ei_message_encode_list_header(opn_ei_message_t *self, int arity)
{
    if (!self || arity < 0)
        return -1;

    return ei_x_encode_list_header(&self->buff, (long)arity);
}

int opn_ei_message_encode_empty_list(opn_ei_message_t *self)
{
    if (!self)
        return -1;

    return ei_x_encode_empty_list(&self->buff);
}

int opn_ei_message_encode_tuple_header(opn_ei_message_t *self, int arity)
{
    if (!self || arity < 0)
        return -1;

    return ei_x_encode_tuple_header(&self->buff, (long)arity);
}

int opn_ei_message_encode_map_header(opn_ei_message_t *self, int arity)
{
    if (!self || arity < 0)
        return -1;

    return ei_x_encode_map_header(&self->buff, (long)arity);
}

int opn_ei_message_encode_pid(opn_ei_message_t *self, const char *node,
                              unsigned num, unsigned serial, unsigned creation)
{
    erlang_pid pid;

    if (!self)
        return -1;
    if (make_pid(&pid, node, num, serial, creation) < 0)
        return -1;

    return ei_x_encode_pid(&self->buff, &pid);
}

int opn_ei_message_encode_port(opn_ei_message_t *self, const char *node,
                               unsigned long long id, unsigned creation)
{
    erlang_port port;

    if (!self)
        return -1;

    memset(&port, 0, sizeof(port));
    if (copy_node(port.node, sizeof(port.node), node, 0) < 0)
        return -1;

    port.id = (EI_ULONGLONG)id;
    port.creation = creation;
    return ei_x_encode_port(&self->buff, &port);
}

int opn_ei_message_encode_ref(opn_ei_message_t *self, const char *node,
                              const unsigned *ids, int id_count,
                              unsigned creation)
{
    erlang_ref ref;
    int i;

    if (!self || !ids || id_count < 0 || id_count > 5)
        return -1;

    memset(&ref, 0, sizeof(ref));
    if (copy_node(ref.node, sizeof(ref.node), node, 0) < 0)
        return -1;

    ref.len = id_count;
    for (i = 0; i < id_count; i++)
        ref.n[i] = ids[i];
    ref.creation = creation;

    return ei_x_encode_ref(&self->buff, &ref);
}
