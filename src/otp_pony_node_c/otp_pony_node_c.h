#pragma once

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

OPN_API opn_ei_t * opn_ei_new (const char* this_nodename, const char* cookie, int creation);

OPN_API int opn_ei_connect (opn_ei_t *self, const char* nodename);

// CLASS version
OPN_API void opn_ei_destroy (opn_ei_t **self_p);

// a less safe version for Pony use
OPN_API void opn_ei_delete (opn_ei_t *self);

#if defined(__cplusplus)
}
#endif
