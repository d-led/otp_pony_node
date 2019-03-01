#include "otp_pony_node_c.h"

#include <ei.h>

#include <iostream>
#include <cassert>

void opn_set_tracelevel(int level)
{
    ei_set_tracelevel(level);
}

struct _opn_ei_t
{
};

opn_ei_t *opn_ei_new(const char *nodename, const char *cookie, int creation)
{
    try
    {
        opn_ei_t *self = new opn_ei_t;
        assert (self);
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

void opn_ei_delete(opn_ei_t *self)
{
    if (self) {
        delete self;
    }
}
