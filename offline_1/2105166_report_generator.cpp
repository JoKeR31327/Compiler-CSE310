#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <iomanip>
#include <algorithm>
#include "2105166_scope_table.hpp"
#include "2105166_symbol_table.hpp"

using namespace std;


//SDBM Hash (Source: https://www.cse.yorku.ca/~oz/hash.html)
unsigned long long sdbm_hash(const string& str, int size) {
    unsigned long long hash = 0;
    for (char c : str) {
        hash = c + (hash << 6) + (hash << 16) - hash;
    }
    return hash % size;
}

//RS Hash (Source: https://www.partow.net/programming/hashfunctions/#RSHashFunction)
unsigned long long rs_hash(const string& str, int size) {
    unsigned int b = 378551;
    unsigned int a = 63689;
    unsigned long long hash = 0;

    for (char c : str) {
        hash = hash * a + c;
        a *= b;
    }
    return hash % size;
}

//eELF Hash (Source: https://www.partow.net/programming/hashfunctions/#ELFHashFunction)
unsigned long long elf_hash(const string& str, int size) {
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



vector<pair<string, string>> generate_test_cases() {
    vector<pair<string, string>> test_cases;
    ifstream infile("2105166_report_test_case.txt");
    if (!infile) {
        cerr << "Error: Could not open file 'report_test_case'" << endl;
        return test_cases;
    }

    string name, type;
    while (infile >> name) {
        infile >> ws;
        getline(infile, type);
        if (!name.empty() && !type.empty()) {
            test_cases.emplace_back(name, type);
        }
    }

    return test_cases;
}


void run_test(const string& func_name, int bucket_size, ofstream& report) {
    Symbol_table symbol_table(bucket_size);
    
    Scope_table::HashType hash_type = Scope_table::DEFAULT;
    if (func_name == "RS") hash_type = Scope_table::RS_HASH;
    else if (func_name == "ELF") hash_type = Scope_table::ELF_HASH;
   
    
    Scope_table* current_scope = symbol_table.get_current_scope();
    current_scope->set_hash_function(hash_type);

    auto test_cases = generate_test_cases();
    vector<int> bucket_counts(bucket_size, 0);
    int total_items = test_cases.size();
    // cout<<"test size"<<total_items<<endl;

    for (const auto& test_case : test_cases) {
        symbol_table.insert(test_case.first, test_case.second);
    }

    Scope_table* scope = symbol_table.get_current_scope();
    int total_collisions = 0;
    for (int i = 0; i < bucket_size; i++) {
        int count = 0;
        Symbol_info** table = scope->get_table();
        Symbol_info* entry = table[i];
        while (entry) {
            count++;
            entry = entry->get_next();
        }
        bucket_counts[i] = count;
        if (count > 1) total_collisions += (count - 1);
    }

    double collision_ratio = static_cast<double>(total_collisions) / total_items;
    double mean_bucket_collision = static_cast<double>(total_collisions) / bucket_size;

    report << func_name << "," << bucket_size << "," << total_collisions << ","
           << fixed << setprecision(4) << collision_ratio << "," << mean_bucket_collision << "\n";

    cout << left << setw(8) << func_name << " | " << setw(4) << bucket_size << " | "
         << setw(4) << total_collisions << " | " << setw(8) << fixed << setprecision(4) 
         << collision_ratio << " | " << setw(8) << mean_bucket_collision << endl;

    cout << "Bucket distribution for " << func_name << " (size " << bucket_size << "):\n";
    // for (int i = 0; i < bucket_size; i++) {
    //     cout << "Bucket " << i << ": " << bucket_counts[i] << " items\n";
    // }
}



int main(int argc, char* argv[]) {
    string hash_func = "SDBM"; 
    vector<string> valid_funcs = {"SDBM", "RS", "ELF"};

    if (argc > 1) {
        string arg = argv[1];
        transform(arg.begin(), arg.end(), arg.begin(), ::toupper);
        
        if (arg == "HELP" || arg == "--HELP" || arg == "-H") {
            return 0;
        }
        
        if (find(valid_funcs.begin(), valid_funcs.end(), arg) == valid_funcs.end()) {
            cerr << "Error: Invalid hash function '" << argv[1] << "'\n\n";
            return 1;
        }
        hash_func = arg;
    }

    ofstream report("2105166_hash_quality_report.csv");
    if (!report) {
        cerr << "Error: Could not create report file\n";
        return 1;
    }

    report << "HashFunction,BucketSize,TotalCollisions,CollisionRatio,MeanBucketCollision\n";

    vector<int> bucket_sizes = {5, 10, 20, 30, 50, 100};

    cout << "Hash Function Evaluation\n";
    cout << "Testing function: " << hash_func << "\n";
    cout << "------------------------------------------------------------\n";
    cout << left << setw(8) << "Function" << " | " << setw(4) << "Size" << " | "
         << setw(4) << "Cols" << " | " << setw(8) << "ColRatio" << " | "
         << setw(8) << "MeanCol" << "\n";
    cout << "------------------------------------------------------------\n";

    for (int size : bucket_sizes) {
        run_test(hash_func, size, report);
    }

    report.close();
    cout << "------------------------------------------------------------\n";
    cout << "Report generated: hash_quality_report.csv\n";
    return 0;
}