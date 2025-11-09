#ifndef SYMBOL_TABLE_HPP
#define SYMBOL_TABLE_HPP

#include <iostream>
#include <string>
#include "2105166_scope_table.hpp"
#include "2105166_symbol_info.hpp"
using namespace std;

class Symbol_table {
    Scope_table* running;
    int bucket_size=0;
    int scope_num;

public:
    Symbol_table(int size) {
        if (size <= 0) {
            cout << "\tInvalid size for the symbol table. Size should be greater than 0.\n";
            return;
        }
        bucket_size = size;
        scope_num=1;
        running = new Scope_table(scope_num, bucket_size, nullptr);
        running->print_enter();
        
    }

    ~Symbol_table() {
        while (running) {
            Scope_table* temp = running;
            running = running->get_parent();
            delete temp;
        }
    }
    

    void enter_scope(int size) {
        scope_num++;
        Scope_table* new_table = new Scope_table(scope_num, bucket_size, running);
        if (running) running->increase_child_count();
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

        if (running && !running->decrease_child_count()) {
            cout << "\tNo child to remove\n";
        }
    }

    bool insert(const string& name,const string& type) {
        if (!running) return false;
        return running->insert(name, type);
    }

    bool remove(string& name) {
        if (!running) return false;
        return running->remove(name);
    }

    Symbol_info* look_up(string& name) {
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
        int level = 0;  
        while (temp) {
            temp->print(level);    
            temp = temp->get_parent();
            level++;
        }
    }
    

    string get_current_scope_id() {
        return running ? running->get_id() : "No Scope";
    }

    Scope_table* get_current_scope() {
        return running;
    }
    void ending(){
        while(running){
            exit_scope();
        }
    }
};

#endif