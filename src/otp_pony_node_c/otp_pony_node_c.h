#pragma once

/*
 * C shim over OTP's `ei` (erl_interface) library.
 *
 * The Pony package never touches `ei` directly: everything that needs a C
 * struct layout (ei_cnode, erlang_pid, erlang_port, ...) is built here and
 * handed to Pony as plain values.  That keeps the FFI surface small and lets
 * the Pony side stay a set of immutable value classes.
 *
 * Conventions used throughout:
 *   - functions returning `int` return 0 (or a non-negative handle) on
 *     success and a negative value on failure, mirroring `ei`;
 *   - decoding functions take the position to decode at through `int *index`
 *     and advance it past the decoded term;
 *   - a `char *buffer`/`size_t cap` pair always carries its own capacity, so a
 *     caller can never be overrun;
 *   - no function aborts the process on bad input.
 */

#include <stddef.h>

#if defined(_MSC_VER)
#ifdef BUILDING_OPN_API
#define OPN_API __declspec(dllexport)
#else
#define OPN_API __declspec(dllimport)
#endif
#elif defined(__GNUC__) || defined(__clang__)
#define OPN_API __attribute__((visibility("default")))
#else
#define OPN_API
#endif

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct _opn_ei_t opn_ei_t;
typedef struct _opn_ei_message_t opn_ei_message_t;

/* The `erl_errno` value of the calling thread. */
OPN_API int opn_erl_errno(void);

OPN_API void opn_set_tracelevel(int level);
OPN_API int opn_ei_get_tracelevel(void);
OPN_API void opn_ei_set_compat_rel(unsigned rel);

OPN_API opn_ei_t *opn_ei_new(const char *this_nodename, const char *cookie,
                             unsigned creation);
OPN_API void opn_ei_destroy(opn_ei_t *self);

/* Returns the connection file descriptor, or a negative value. */
OPN_API int opn_ei_connect(opn_ei_t *self, const char *nodename);
OPN_API int opn_ei_connect_tmo(opn_ei_t *self, const char *nodename,
                               unsigned ms);
OPN_API int opn_ei_close_connection(int fd);

/* Publishes this node's name with epmd and listens for connections on `port`,
 * or on a port of its own when `port` is zero.  The port bound is written to
 * `bound`.  Returns the listening socket, or a negative value. */
OPN_API int opn_ei_publish(opn_ei_t *self, unsigned port, unsigned *bound);

/* Withdraws this node's name from epmd. */
OPN_API int opn_ei_unpublish(opn_ei_t *self);

/* Waits for a node to connect to `listen_fd`, `ms == 0` blocking.  Returns the
 * connection, or a negative value; the peer's node name lands in `peer`. */
OPN_API int opn_ei_accept(opn_ei_t *self, int listen_fd, char *peer,
                          size_t peer_cap);
OPN_API int opn_ei_accept_tmo(opn_ei_t *self, int listen_fd, unsigned ms,
                              char *peer, size_t peer_cap, int *timed_out);

/* One more owner of a node: an accepted connection shares the node that its
 * listener was made from. */
OPN_API void opn_ei_retain(opn_ei_t *self);

OPN_API int opn_ei_self_pid(const opn_ei_t *self, char *node, size_t node_cap,
                            unsigned *num, unsigned *serial,
                            unsigned *creation);

OPN_API int opn_ei_thisnodename(const opn_ei_t *self, char *buffer,
                                size_t cap);
OPN_API int opn_ei_thishostname(const opn_ei_t *self, char *buffer,
                                size_t cap);
OPN_API int opn_ei_thisalivename(const opn_ei_t *self, char *buffer,
                                 size_t cap);

OPN_API opn_ei_message_t *opn_ei_message_new(void);
OPN_API void opn_ei_message_destroy(opn_ei_message_t *self);

/* Number of encoded bytes written so far. */
OPN_API int opn_ei_message_length(const opn_ei_message_t *self);
/* The write position, for rolling a failed encode back. */
OPN_API int opn_ei_message_index(const opn_ei_message_t *self);
OPN_API int opn_ei_message_truncate(opn_ei_message_t *self, int index);
/* First position after the protocol version byte. */
OPN_API int opn_ei_message_beginning(const opn_ei_message_t *self);

/* The type character and payload size of the term at `index`. */
OPN_API int opn_ei_message_type_at(const opn_ei_message_t *self, int index,
                                   int *type, int *size);
/* Position just past the term at `index`, whatever its type. */
OPN_API int opn_ei_message_skip_term(const opn_ei_message_t *self, int index,
                                     int *next);
/* Copies the raw encoded bytes of [from, to) into `buffer`. */
OPN_API int opn_ei_message_copy(const opn_ei_message_t *self, int from,
                                int to, char *buffer, size_t cap);
OPN_API int opn_ei_message_append_raw(opn_ei_message_t *self, const char *bytes,
                                      int len);

/* Who sent the message, and how (ERL_SEND, ERL_REG_SEND, ...). */
OPN_API int opn_ei_message_msgtype(const opn_ei_message_t *self);
OPN_API int opn_ei_message_from(const opn_ei_message_t *self, char *node,
                                size_t node_cap, unsigned *num,
                                unsigned *serial, unsigned *creation);

/* Polls the connection.  `ms == 0` blocks. */
OPN_API opn_ei_message_t *opn_ei_receive_tmo(int fd, unsigned ms,
                                             int *timed_out);
OPN_API int opn_ei_send_tmo(int fd, const char *node, unsigned num,
                            unsigned serial, unsigned creation,
                            const opn_ei_message_t *what, unsigned ms,
                            int *timed_out);
OPN_API int opn_ei_reg_send_tmo(opn_ei_t *self, int fd, const char *server,
                                const opn_ei_message_t *what, unsigned ms,
                                int *timed_out);

OPN_API int opn_ei_message_decode_atom(const opn_ei_message_t *self,
                                       int *index, char *buffer, size_t cap);
OPN_API int opn_ei_message_decode_int(const opn_ei_message_t *self,
                                      int *index, long long *value);
OPN_API int opn_ei_message_decode_double(const opn_ei_message_t *self,
                                         int *index, double *value);
OPN_API int opn_ei_message_decode_binary(const opn_ei_message_t *self,
                                         int *index, char *buffer, size_t cap,
                                         long long *len);
OPN_API int opn_ei_message_decode_bitstring(const opn_ei_message_t *self,
                                            int *index, char *buffer,
                                            size_t cap, long long *len,
                                            int *used_bits_in_last_byte);
OPN_API int opn_ei_message_decode_string(const opn_ei_message_t *self,
                                         int *index, char *buffer, size_t cap);
OPN_API int opn_ei_message_decode_list_header(const opn_ei_message_t *self,
                                              int *index, int *arity);
OPN_API int opn_ei_message_decode_tuple_header(const opn_ei_message_t *self,
                                               int *index, int *arity);
OPN_API int opn_ei_message_decode_map_header(const opn_ei_message_t *self,
                                             int *index, int *arity);
OPN_API int opn_ei_message_decode_pid(const opn_ei_message_t *self,
                                      int *index, char *node, size_t node_cap,
                                      unsigned *num, unsigned *serial,
                                      unsigned *creation);
OPN_API int opn_ei_message_decode_port(const opn_ei_message_t *self,
                                       int *index, char *node, size_t node_cap,
                                       unsigned long long *id,
                                       unsigned *creation);
OPN_API int opn_ei_message_decode_ref(const opn_ei_message_t *self,
                                      int *index, char *node, size_t node_cap,
                                      unsigned *ids, int ids_cap,
                                      int *id_count, unsigned *creation);

OPN_API int opn_ei_message_encode_atom(opn_ei_message_t *self,
                                       const char *what);
OPN_API int opn_ei_message_encode_int(opn_ei_message_t *self,
                                      long long value);
OPN_API int opn_ei_message_encode_double(opn_ei_message_t *self, double value);
OPN_API int opn_ei_message_encode_binary(opn_ei_message_t *self,
                                         const char *what, int len);
OPN_API int opn_ei_message_encode_bitstring(opn_ei_message_t *self,
                                            const char *what, int len,
                                            int used_bits_in_last_byte);
OPN_API int opn_ei_message_encode_string(opn_ei_message_t *self,
                                         const char *what, int len);
OPN_API int opn_ei_message_encode_list_header(opn_ei_message_t *self,
                                              int arity);
OPN_API int opn_ei_message_encode_empty_list(opn_ei_message_t *self);
OPN_API int opn_ei_message_encode_tuple_header(opn_ei_message_t *self,
                                               int arity);
OPN_API int opn_ei_message_encode_map_header(opn_ei_message_t *self,
                                             int arity);
OPN_API int opn_ei_message_encode_pid(opn_ei_message_t *self, const char *node,
                                      unsigned num, unsigned serial,
                                      unsigned creation);
OPN_API int opn_ei_message_encode_port(opn_ei_message_t *self,
                                       const char *node, unsigned long long id,
                                       unsigned creation);
OPN_API int opn_ei_message_encode_ref(opn_ei_message_t *self, const char *node,
                                      const unsigned *ids, int id_count,
                                      unsigned creation);

#if defined(__cplusplus)
}
#endif
