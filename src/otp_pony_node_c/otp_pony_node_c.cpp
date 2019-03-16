#include "otp_pony_node_c.h"

#include <ei.h>

#include <iostream>
#include <cassert>
#include <string>
#include <algorithm>
#include <cstring>
#include <cstdlib>

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

struct _opn_ei_pid_t
{
    erlang_pid pid;
};

int opn_ei_connect(opn_ei_t *self, const char* nodename)
{
    assert(self);
    assert(nodename);
    return ei_connect(&self->node, (char*)nodename);
}

// http://erlang.org/doc/man/ei_connect.html#ei_self
int opn_ei_self_pid(opn_ei_t *self, char* buffer, unsigned int* num, unsigned int* serial_, unsigned int* creation)
{
    assert(self);
    assert(buffer);
    assert(num);
    assert(serial_);
    assert(creation);

    erlang_pid* tmp = ei_self(&self->node);
    if (!tmp) {
        // should not have happened
        return 1;
    }

    // both should have been null-terminated
    strcpy(buffer, tmp->node);

    *num = tmp->num;
    *serial_ = tmp->serial;
    *creation = tmp->creation;
    return 0;
}

opn_ei_message_t * opn_ei_new_message()
{
    try
    {
        opn_ei_message_t * m = new opn_ei_message_t;
        if (ei_x_new_with_version(&m->buff) < 0) {
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

    int timed_out = 0;
    return opn_ei_receive_tmo(self, connection_id, 0, &timed_out);
}

opn_ei_message_t * opn_ei_receive_tmo(opn_ei_t *self, int connection_id, unsigned int ms, int* timed_out)
{
    assert(self);
    assert(timed_out);

    opn_ei_message_t * m = opn_ei_new_message();
    if (!m)
        return nullptr;

    int res = 0;

    // skip tick messages
    do {
        if (ms!=0) {
            res = ei_xreceive_msg_tmo(connection_id, &m->msg, &m->buff, ms);
        } else {
            res = ei_xreceive_msg(connection_id, &m->msg, &m->buff);
        }

        if (res < 0) {
            opn_ei_message_destroy(&m);
            *timed_out = erl_errno == ETIMEDOUT;
            return nullptr;
        }
    } while (res == ERL_TICK);

    // todo: complex protocol handling & returning the message appropriately

    if (res < 0) {
        opn_ei_message_destroy(&m);
        return nullptr;
    }

    return m;
}

int opn_ei_send_tmo(opn_ei_t *self, int connection_id, opn_ei_pid_t *to, opn_ei_message_t * what, unsigned int ms, int* timed_out)
{
    assert(self);
    assert(timed_out);
    assert(to);
    assert(what);

    int res = 0;

    if (ms!=0) {
        res = ei_send_tmo(connection_id, &to->pid, what->buff.buff, what->buff.index, ms);
    } else {
        res = ei_send(connection_id, &to->pid, what->buff.buff, what->buff.index);
    }

    if (res < 0) {
        *timed_out = erl_errno == ETIMEDOUT;
    }

    return res;
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

opn_ei_message_t * opn_ei_message_new()
{
    return opn_ei_new_message();
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
    if (index <0 || index >= self->buff.index) {
        *type = 0;
        *size = 0;
        return 1 /*unknown type*/;
    }
    return ei_get_type(self->buff.buff, &index, type, size);
}

int opn_ei_message_encode_atom(opn_ei_message_t *self, char const* what)
{
    assert(self);
    assert(what);

    return ei_x_encode_atom(&self->buff, what);
}

int opn_ei_message_atom_at(opn_ei_message_t *self, int* index, char* buffer)
{
    assert(self);
    assert(buffer);
    assert(index);

    return ei_decode_atom(self->buff.buff, index, buffer);
}

int opn_ei_message_encode_binary(opn_ei_message_t *self, char const* what, long len)
{
    assert(self);
    assert(what);
    assert(len > 0);

    return ei_x_encode_binary(&self->buff, what, len);
}

int opn_ei_message_binary_at(opn_ei_message_t *self, int* index, char* buffer, long* len)
{
    assert(self);
    assert(buffer);
    assert(index);
    assert(len);

    return ei_decode_binary(self->buff.buff, index, buffer, len);
}

int opn_ei_message_tuple_arity_at(opn_ei_message_t *self, int* index, int* arity)
{
    assert(self);
    assert(index);
    assert(arity);

    return ei_decode_tuple_header(self->buff.buff, index, arity);
}

int opn_ei_message_encode_pid(opn_ei_message_t *self, opn_ei_pid_t const* pid)
{
    assert(self);
    assert(pid);

    return ei_x_encode_pid(&self->buff, &pid->pid);
}

int opn_ei_message_pid_at(opn_ei_message_t *self, int* index, char* buffer, unsigned int* num, unsigned int* serial_, unsigned int* creation)
{
    assert(self);
    assert(index);
    assert(buffer);
    assert(serial_);
    assert(creation);

    erlang_pid pid;
    int res = ei_decode_pid(self->buff.buff, index, &pid);

    if (res < 0)
        return res;

    // both should have been null-terminated
    strcpy(buffer, pid.node);

    *num = pid.num;
    *serial_ = pid.serial;
    *creation = pid.creation;
    return 0;
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

opn_ei_pid_t * opn_ei_pid_new(char const* node, unsigned int num, unsigned int serial_, unsigned int creation)
{
    try
    {
        opn_ei_pid_t *self = new opn_ei_pid_t;
        self->pid.num = num;
        self->pid.serial = serial_;
        self->pid.creation = creation;

        memset(self->pid.node, 0, sizeof(self->pid.node)/sizeof(self->pid.node[0]));
        // both should have been null-terminated
        strcpy(self->pid.node, node);

        return self;
    }
    catch (std::exception &e)
    {
        std::cerr << "opn_ei_pid_new: " << e.what() << std::endl;
        return nullptr;
    }
}

void opn_ei_pid_destroy(opn_ei_pid_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        opn_ei_pid_t *self = *self_p;
        delete self;
        *self_p = nullptr;
    }
}
