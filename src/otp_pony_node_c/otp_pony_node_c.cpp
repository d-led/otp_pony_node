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

struct _opn_ei_message_t
{
    erlang_msg msg;
    ei_x_buff buff;
};

int opn_ei_connect(opn_ei_t *self, const char* nodename)
{
    assert(self);
    assert(nodename);
    return ei_connect(&self->node, (char*)nodename);
}

opn_ei_message_t * opn_ei_new_message()
{
    try
    {
        opn_ei_message_t * m = new opn_ei_message_t;
        if (ei_x_new(&m->buff) < 0) {
            delete m;
            return nullptr;
        }
        
        return m;
    }
    catch (std::exception &e)
    {
        std::cerr << "opn_ei_new_message: " << e.what() << std::endl;
        return nullptr;
    }
}

opn_ei_message_t * opn_ei_receive (opn_ei_t *self, int connection_id)
{
    assert(self);

    opn_ei_message_t * m = opn_ei_new_message();
    if (!m)
        return nullptr;

    int res = 0;

    // skip tick messages
    do {
        res = ei_xreceive_msg(connection_id, &m->msg, &m->buff);
		if (res < 0) {
            opn_ei_message_destroy(&m);
            return nullptr;
        }
    } while (res == ERL_TICK) ;

    // todo: complex protocol handling & returning the message appropriately

    if (res < 0) {
        opn_ei_message_destroy(&m);
        return nullptr;
    }

    return m;
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

size_t opn_ei_message_length(opn_ei_message_t *self)
{
    assert(self);
    return self->buff.buffsz;
}

int opn_ei_message_beginning(opn_ei_message_t *self)
{
    assert(self);
    int index = 0;
    int version = 0;
    if (ei_decode_version(self->buff.buff, &index, &version) < 0)
        // should not have failed, just return the absolute beginning
        return 0;

    return index;
}

int opn_ei_message_type_at(opn_ei_message_t *self, int index, int* type, int* size)
{
    assert(self);
    assert(type);
    assert(size);
    return ei_get_type(self->buff.buff, &index, type, size);
}

int opn_ei_message_atom_at(opn_ei_message_t *self, int index, char* buffer)
{
    assert(self);
    assert(buffer);

    return ei_decode_atom(self->buff.buff, &index, buffer);
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

void opn_ei_message_destroy(opn_ei_message_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        opn_ei_message_t *self = *self_p;
        ei_x_free(&self->buff);
        delete self;
        *self_p = nullptr;
    }
}
