#ifndef SCOPE_TABLE_HPP
#define SCOPE_TABLE_HPP

#include "2105166_symbol_info.hpp"
#include <iostream>
#include <string>
using namespace std;

class Scope_table {
    Symbol_info** table;
    int size;
    int count = 0;
    string id;
    int parent_id;
    Scope_table* parent;
    int num_children;

   

public:
    enum HashType { DEFAULT, RS_HASH, ELF_HASH };
    HashType hash_type;
    Scope_table(int scope_num, int len, Scope_table* parent = nullptr)
    : id(to_string(scope_num)), size(len), parent(parent), hash_type(DEFAULT), num_children(0) {
    table = new Symbol_info*[size];
    for (int i = 0; i < size; i++) table[i] = nullptr;
    }

    Scope_table(int scope_num, int len, HashType type = DEFAULT, Scope_table* parent = nullptr)
    : id(to_string(scope_num)), size(len), parent(parent), hash_type(type), num_children(0) {
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

    unsigned long long hash(string const& str) {
        unsigned long long hash = 0;
        unsigned int len = str.length();

        for (unsigned int i = 0; i < len; i++) {
            hash = ((str[i]) + (hash << 6) + (hash << 16) - hash) % size;
        }
        return hash;
    }

    unsigned long long rs_hash(string const& str) {
        unsigned int b = 378551;
        unsigned int a = 63689;
        unsigned long long hash = 0;

        for (char c : str) {
            hash = hash * a + c;
            a *= b;
        }
        return hash % size;
    }

    unsigned long long elf_hash(string const& str) {
        unsigned long long hash = 0;
        unsigned long long x = 0;

        for (char c : str) {
            hash = (hash << 4) + c;
            if ((x = hash & 0xF0000000) != 0) {
                hash ^= (x >> 24);
                hash &= ~x;
            }
        }
        return hash % size;
    }

    unsigned long long get_hash(string const& str) {
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
        unsigned long long index = get_hash(name);
        Symbol_info* head = table[index];

        Symbol_info* temp = head;
        int position = 0;
        while (temp) {
            if (temp->get_name() == name) return false;
            temp = temp->get_next();
            position++;
        }

        Symbol_info* new_entry = new Symbol_info(name, type);
        if (!head) {
            table[index] = new_entry;
            position = 0;
        } else {
            temp = head;
            position = 1;
            while (temp->get_next()) {
                temp = temp->get_next();
                position++;
            }
            temp->set_next(new_entry);
        }

        cout << "\tInserted in ScopeTable# " << id << " at position " << index + 1 << ", " << position + 1 << endl;
        return true;
    }

    bool remove(string name) {
        int index = get_hash(name);
        Symbol_info* curr = table[index];
        Symbol_info* prev = nullptr;

        int position = 0;
        while (curr) {
            if (curr->get_name() == name) {
                if (prev)
                    prev->set_next(curr->get_next());
                else
                    table[index] = curr->get_next();
                string temp = curr->get_name();
                delete curr;

                cout << "\tDeleted '" << temp << "' from ScopeTable# " << id << " at position " << index + 1 << ", " << position + 1 << endl;
                return true;
            }
            prev = curr;
            curr = curr->get_next();
            position++;
        }
        return false;
    }

    Symbol_info* lookup(string name) {
        unsigned long long index = get_hash(name);
        Symbol_info* temp = table[index];

        int position = 0;
        while (temp) {
            if (temp->get_name() == name) {
                cout << "\t'" << name << "' found in ScopeTable# " << id << " at position " << index + 1 << ", " << position + 1 << endl;
                return temp;
            }
            temp = temp->get_next();
            position++;
        }
        return nullptr;
    }

    void print() {
        cout << "\tScopeTable# " << id << endl;
        for (int i = 0; i < size; i++) {
            Symbol_info* temp = table[i];
            cout << "\t" << i + 1 << "--> ";
            if (temp) {
                while (temp) {
                    temp->print();
                    temp = temp->get_next();
                }
                cout << endl;
            } else cout << endl;
        }
    }

    void print(int level) {
        for (int i = 0; i < level; i++) cout << "\t";
        cout << "\tScopeTable# " << id << endl;

        for (int i = 0; i < size; i++) {
            for (int j = 0; j < level; j++) cout << "\t";
            cout << "\t" << i + 1 << "--> ";

            Symbol_info* temp = table[i];
            if (temp) {
                while (temp) {
                    temp->print();
                    temp = temp->get_next();
                }
            }
            cout << endl;
        }
    }

    string get_id() const { return id; }

    Scope_table* get_parent() const { return parent; }

    void print_enter() const {
        cout << "\tScopeTable# " << id << " created\n";
    }

    void print_exit() const {
        cout << "\tScopeTable# " << id << " removed\n";
    }

    void increase_child_count() {
        num_children++;
    }

    int get_child() const {
        return num_children;
    }
    Symbol_info** get_table() const { return table; }
    
    bool decrease_child_count() {
        if (num_children > 0) {
            num_children--;
            return true;
        }
        return false;
    }
    Symbol_info** get_table() {
        return table;
    }
};

#endif
