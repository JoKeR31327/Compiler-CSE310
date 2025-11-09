#ifndef SCOPE_TABLE_HPP
#define SCOPE_TABLE_HPP

#include "2105166_symbol_info.hpp"
#include <iostream>
#include <string>
using namespace std;

class Scope_table {
    Symbol_info** table;
    int size;
    string id;
    Scope_table* parent;
    int num_children;

public:
    enum HashType { DEFAULT, RS_HASH, ELF_HASH };
    HashType hash_type;

    Scope_table(string id, int len, Scope_table* parent = nullptr)
        : id(id), size(len), parent(parent), hash_type(DEFAULT), num_children(0) {
        table = new Symbol_info*[size];
        for (int i = 0; i < size; i++) table[i] = nullptr;
    }

    Scope_table(string id, int len, HashType type = DEFAULT, Scope_table* parent = nullptr)
        : id(id), size(len), parent(parent), hash_type(type), num_children(0) {
        table = new Symbol_info*[size];
        for (int i = 0; i < size; i++) table[i] = nullptr;
    }

    ~Scope_table() {
        for (int i = 0; i < size; i++) {
            Symbol_info* entry = table[i];
            while (entry) {
                Symbol_info* temp = entry;
                entry = entry->get_next();
                delete temp;
            }
        }
        delete[] table;
    }

    unsigned int hash(const string& str) {
        unsigned int hash = 0;
        unsigned int i=0;
        unsigned int len= str.length();
        for (i = 0; i < len ; i ++)
        {
        hash = (( str[ i ]) + ( hash << 6) + ( hash << 16) - hash );
        }
        return hash % size;
    }

    unsigned long long rs_hash(const string& str) {
        unsigned int b = 378551;
        unsigned int a = 63689;
        unsigned long long hash = 0;

        for (char c : str) {
            hash = hash * a + c;
            a *= b;
        }
        return hash % size;
    }

    unsigned long long elf_hash(const string& str) {
        unsigned long long hash = 0, x = 0;

        for (char c : str) {
            hash = (hash << 4) + c;
            if ((x = hash & 0xF0000000)) {
                hash ^= (x >> 24);
                hash &= ~x;
            }
        }
        return hash % size;
    }

    unsigned long long get_hash(const string& str) {
        switch (hash_type) {
            case RS_HASH: return rs_hash(str);
            case ELF_HASH: return elf_hash(str);
            default: return hash(str);
        }
    }

    void set_hash_function(HashType type) {
        hash_type = type;
    }

    bool insert(string name, string type) {
        unsigned int index = hash(name);
        Symbol_info* head = table[index];
        Symbol_info* temp = head;
        while (temp) {
            if (temp->get_name() == name) return false;
            temp = temp->get_next();
        }

        Symbol_info* new_entry = new Symbol_info(name, type);
        if (!head) {
            table[index] = new_entry;
        } else {
            while (head->get_next()) head = head->get_next();
            head->set_next(new_entry);
        }

        return true;
    }

    bool remove(const string& name) {
        int index = get_hash(name);
        Symbol_info* curr = table[index];
        Symbol_info* prev = nullptr;
        int pos = 0;

        while (curr) {
            if (curr->get_name() == name) {
                if (prev) prev->set_next(curr->get_next());
                else table[index] = curr->get_next();
                cout << "\tDeleted '" << name << "' from ScopeTable# " << id
                     << " at position " << index + 1 << ", " << pos + 1 << endl;
                delete curr;
                return true;
            }
            prev = curr;
            curr = curr->get_next();
            pos++;
        }
        return false;
    }

    Symbol_info* lookup(const string& name) {
        unsigned long long index = get_hash(name);
        Symbol_info* temp = table[index];
        int pos = 0;
        while (temp) {
            if (temp->get_name() == name) {
                cout << "< " << name << " : " << temp->get_type() << " > already exists in ScopeTable# "
                     << id << " at position " << index << ", " << pos <<"\n"<<endl;
                return temp;
            }
            temp = temp->get_next();
            pos++;
        }
        return nullptr;
    }

    void print() {
        cout << "ScopeTable # " << id << endl;
        for (int i = 0; i < size; i++) {
            Symbol_info* temp = table[i];
            if (!temp) continue;

            cout << i << " --> ";
            while (temp) {
                temp->print();
                temp = temp->get_next();
            }
            cout << endl;
        }
    }

    void print_enter() const {
        // cout << "\tScopeTable# " << id << " created\n";
    }

    void print_exit() const {
        // cout << "\tScopeTable# " << id << " removed\n";
    }

    Scope_table* get_parent() const { return parent; }
    string get_id() const { return id; }
    int get_child() const { return num_children; }
    void increase_child_count() { num_children++; }
    bool decrease_child_count() {
        if (num_children > 0) {
            num_children--;
            return true;
        }
        return false;
    }

    Symbol_info** get_table() const { return table; }
};

#endif
