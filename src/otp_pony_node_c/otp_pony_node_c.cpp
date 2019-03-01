#include "otp_pony_node_c.h"

#include <ei.h>
#include <iostream>

void opn_set_tracelevel(int level) {
    ei_set_tracelevel(level);
}

struct _opn_ei_t {
};

opn_ei_t * opn_ei_new (const char* nodename, const char* cookie, int creation) {
    std::cout<<"opn_ei_new_new"<<std::endl;
    return nullptr;
}

void opn_ei_destroy (opn_ei_t **self_p) {

}
