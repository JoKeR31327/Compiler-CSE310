#ifndef SYMBOL_INFO_HPP
#define SYMBOL_INFO_HPP

#include <iostream>
#include <string>
#include <sstream>
using namespace std;

class Symbol_info {
    string name;
    string type;
    Symbol_info* next;

public:
    bool is_array = false;
    string is_type;
    int p_count=0;
    vector<string> param_types; 
    bool getin=true;
    Symbol_info(string name = "", string type = "") : name(name), type(type), next(nullptr) {}

    void set_name(string n) { name = n; }
    void set_type(string t) { type = t; }
    void set_next(Symbol_info* nxt) { next = nxt; }

    string get_name() const { return name; }
    string get_type() const { return type; }
    Symbol_info* get_next() const { return next; }

    void print() {
        cout << "< " << name << " : ";
        stringstream ss(type);
        string token;
        ss >> token;

        if (token == "STRUCT" || token == "ENUM" || token == "CLASS" || token == "UNION") {
            cout << token << ",{";

            string inner_type, inner_name;
            bool first = true;

            while (ss >> inner_type) {
                ss >> inner_name;

                if (!first) {
                    cout << ",";
                }

                cout << "(" << inner_type << "," << inner_name << ")";
                first = false;
            }

            cout << "}";
        } else if (token == "FUNCTION") {
            cout << token << ",";
            string return_type;
            ss >> return_type;
            cout << return_type << "<==(";
            
            string param_type;
            bool first_param = true;
            while (ss >> param_type) {
                if (!first_param) {
                    cout << ",";
                }
                cout << param_type;
                first_param = false;
            }
            cout << ")";
        } else {
            cout << token;
        }

        cout << " >";
    }
    
};

#endif