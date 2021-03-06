#pragma once

#include <stddef.h>

#ifdef _MSC_VER
#ifdef BUILDING_OPN_API
#define OPN_API __declspec(dllexport)
#else
#define OPN_API __declspec(dllimport)
#endif
#else
#define OPN_API
#endif

#if defined(__cplusplus)
extern "C" {
#endif

OPN_API void opn_set_tracelevel(int level);

// see https://rfc.zeromq.org/spec:21/CLASS/
typedef struct _opn_ei_t opn_ei_t;
typedef struct _opn_ei_message_t opn_ei_message_t;
typedef struct _opn_ei_pid_t opn_ei_pid_t;

OPN_API opn_ei_t * opn_ei_new (const char* this_nodename, const char* cookie, int creation);

OPN_API int opn_ei_connect (opn_ei_t *self, const char* nodename);
OPN_API int opn_ei_self_pid(opn_ei_t *self, char* buffer, unsigned int* num, unsigned int* serial_, unsigned int* creation);

OPN_API opn_ei_message_t * opn_ei_receive (opn_ei_t *self, int connection_id);
OPN_API opn_ei_message_t * opn_ei_receive_tmo(opn_ei_t *self, int connection_id, unsigned int ms, int* timed_out);

OPN_API int opn_ei_send_tmo(opn_ei_t *self, int connection_id, opn_ei_pid_t *to, opn_ei_message_t * what, unsigned int ms, int* timed_out);

OPN_API void opn_ei_destroy (opn_ei_t **self_p);

OPN_API opn_ei_message_t * opn_ei_message_new();

OPN_API size_t opn_ei_message_length(opn_ei_message_t *self);

OPN_API int opn_ei_message_beginning(opn_ei_message_t *self);

OPN_API int opn_ei_message_type_at(opn_ei_message_t *self, int index, int* type, int* size);
OPN_API int opn_ei_message_encode_atom(opn_ei_message_t *self, char const* what);
OPN_API int opn_ei_message_atom_at(opn_ei_message_t *self, int* index, char* buffer);
OPN_API int opn_ei_message_encode_binary(opn_ei_message_t *self, char const* what, long len);
OPN_API int opn_ei_message_binary_at(opn_ei_message_t *self, int* index, char* buffer, long* len);
OPN_API int opn_ei_message_encode_tuple_header(opn_ei_message_t *self, int arity);
OPN_API int opn_ei_message_tuple_arity_at(opn_ei_message_t *self, int* index, int* arity);
OPN_API int opn_ei_message_encode_pid(opn_ei_message_t *self, opn_ei_pid_t const* pid);
OPN_API int opn_ei_message_pid_at(opn_ei_message_t *self, int* index, char* buffer, unsigned int* num, unsigned int* serial_, unsigned int* creation);

OPN_API void opn_ei_message_destroy (opn_ei_message_t **self_p);

OPN_API opn_ei_pid_t * opn_ei_pid_new (char const* node, unsigned int num, unsigned int serial_, unsigned int creation);
OPN_API void opn_ei_pid_destroy (opn_ei_pid_t **self_p);


#if defined(__cplusplus)
}
#endif
