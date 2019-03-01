#include "otp_pony_node_c.h"

#include <ei.h>

#include <iostream>
#include <cassert>
#include <string>

void opn_set_tracelevel(int level)
{
    ei_set_tracelevel(level);
}

struct _opn_ei_t
{
    int creation;
    std::string this_nodename;
    std::string cookie;
    ei_cnode node;
};

// int connect(opn_ei_t * self) {
//     if (ei_connect_init(&ec, thisnodename.c_str(), cookie.c_str(), creation) < 0)
// }

        // @ei_connect[I32](MaybePointer[EiNode](node), nodename.cstring())

int opn_ei_connect(opn_ei_t *self, const char* nodename)
{
    assert(self);
    assert(nodename);
    return ei_connect(&self->node, (char*)nodename);
}

opn_ei_t *opn_ei_new(const char *this_nodename, const char *cookie, int creation)
{
    try
    {
        opn_ei_t *self = new opn_ei_t;
        self->creation = creation;
        self->this_nodename = this_nodename;
        self->cookie = cookie;

        if (ei_connect_init(&self->node, self->this_nodename.c_str(), self->cookie.c_str(), self->creation) < 0) {
            opn_ei_destroy(&self);
            return nullptr;
        }
        return self;
    }
    catch (std::exception &e)
    {
        std::cerr << "opn_ei_new: " << e.what() << std::endl;
        return nullptr;
    }
}

void opn_ei_destroy(opn_ei_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        opn_ei_t *self = *self_p;
        delete self;
        *self_p = nullptr;
    }
}
