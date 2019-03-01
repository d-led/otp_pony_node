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

// see https://rfc.zeromq.org/spec:21/CLASS/
typedef struct _opn_ei_t opn_ei_t;

OPN_API opn_ei_t * opn_ei_new (const char* nodename, const char* cookie, int creation);
OPN_API void opn_ei_destroy (opn_ei_t **self_p);

OPN_API void opn_set_tracelevel(int level);

#if defined(__cplusplus)
}
#endif
