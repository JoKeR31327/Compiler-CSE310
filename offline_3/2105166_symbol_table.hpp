#ifndef SYMBOL_TABLE_HPP
#define SYMBOL_TABLE_HPP

#include <iostream>
#include <string>
#include "2105166_scope_table.hpp"
#include "2105166_symbol_info.hpp"
using namespace std;

class Symbol_table {
    Scope_table* running;
    int bucket_size = 0;

public:
    Symbol_table(int size) {
        if (size <= 0) {
            cout << "\tInvalid size for the symbol table. Size should be greater than 0.\n";
            return;
        }
        bucket_size = size;
        running = new Scope_table("1", bucket_size, nullptr);  
        running->print_enter();
    }

    ~Symbol_table() {
        while (running) {
            Scope_table* temp = running;
            running = running->get_parent();
            delete temp;
        }
    }

    void enter_scope() {
        if (!running) return;

        int child_num = running->get_child() + 1;
        running->increase_child_count();

        string new_id = running->get_id() + "." + to_string(child_num);
        Scope_table* new_table = new Scope_table(new_id, bucket_size, running);
        running = new_table;
        running->print_enter();
    }

    void exit_scope() {
        if (!running) {
            cout << "\tNo scope to exit\n";
            return;
        }

        Scope_table* temp = running;
        temp->print_exit();
        running = temp->get_parent();
        delete temp;
        if (running) {
            cout << "\tNo child to remove\n";
        }
        // if(running->get_parent()==nullptr)print_all_scope_table();
    }

    bool insert(const string& name, const string& type) {
        if(running->insert(name, type)){
            print_all_scope_table();
            return true;
        }
        return false;
    }

    bool remove(string& name) {
        return running ? running->remove(name) : false;
    }

 

    Symbol_info* look_up(const string& name) {
        Scope_table* temp = running;
        while (temp) {
            Symbol_info* entry = temp->lookup(name);
            if (entry) return entry;
            temp = temp->get_parent();
        }
        return nullptr;
    }

    void print_current_scope_table() {
        if (running) running->print();
        else cout << "\tNo current scope\n";
    }

    void print_all_scope_table() {
        Scope_table* temp = running;
        while (temp) {
            temp->print();  
            temp = temp->get_parent();
        }
        cout <<"\n";
    }

    string get_current_scope_id() {
        return running ? running->get_id() : "No Scope";
    }

    Scope_table* get_current_scope() {
        return running;
    }

    void ending() {
        while (running) {
            exit_scope();
        }
    }
};

#endif
