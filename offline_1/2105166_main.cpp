#include <iostream>
#include "2105166_symbol_table.hpp"
#include <fstream>
#include <sstream>
using namespace std;

int main(int argc, char* argv[]) {
    string inputFile="sample_input.txt";
    string outputFile="outputs.txt";
    if (argc >= 2) inputFile = argv[1];
    if (argc >= 3) outputFile = argv[2];
    ifstream file(inputFile);
    ofstream output(outputFile);
    streambuf* cinbuf = cin.rdbuf();
    streambuf* coutbuf = cout.rdbuf();
    cin.rdbuf(file.rdbuf());
    cout.rdbuf(output.rdbuf());

    int size;
    cin >> size;
    cin.ignore(); 

    Symbol_table table(size);

    string line;
    int cmd_count = 0;
    while (getline(cin, line)) {
        if (line.empty()) continue;
        cmd_count++;

        istringstream iss(line);
        char command;
        iss >> command;

        cout << "Cmd " << cmd_count << ": " << line << endl;

        switch (command) {
            case 'I': {
                string name, type;
                if (!(iss >> name)) {
                    cout << "\tNumber of parameters mismatch for the command I\n";
                    break;
                }
                iss >> ws;
                getline(iss, type);
                if (type.empty()) {
                    cout << "\tNumber of parameters mismatch for the command I\n";
                    break;
                }

                bool success = table.insert(name, type);
                if (!success)
                    cout << "\t'" << name << "' already exists in the current ScopeTable\n";
                break;
            }

            case 'L': {
                string name, extra;
                if (!(iss >> name) || (iss >> extra)) {
                    cout << "\tNumber of parameters mismatch for the command L\n";
                    break;
                }

                Symbol_info* result = table.look_up(name);
                if (!result) {
                    cout << "\t'" << name << "' not found in any of the ScopeTables\n";
                }
                break;
            }

            case 'D': {
                string name, extra;
                if (!(iss >> name) || (iss >> extra)) {
                    cout << "\tNumber of parameters mismatch for the command D\n";
                    break;
                }

                bool removed = table.remove(name);
                if (!removed)
                    cout << "\tNot found in the current ScopeTable\n";
                break;
            }

            case 'P': {
                char scope;
                string extra;
                if (!(iss >> scope) || (iss >> extra)) {
                    cout << "\tNumber of parameters mismatch for the command P\n";
                    break;
                }

                if (scope == 'A') {
                    table.print_all_scope_table();
                } else if (scope == 'C') {
                    table.print_current_scope_table();
                } else {
                    cout << "\tInvalid print option: " << scope << endl;
                }
                break;
            }

            case 'S': {
                string extra;
                if (iss >> extra) {
                    cout << "\tNumber of parameters mismatch for the command S\n";
                    break;
                }
                table.enter_scope(size);
                break;
            }

            case 'E': {
                string extra;
                if (iss >> extra) {
                    cout << "\tNumber of parameters mismatch for the command E\n";
                    break;
                }
                table.exit_scope();
                break;
            }

            case 'Q': {
                string extra;
                if (iss >> extra) {
                    cout << "\tNumber of parameters mismatch for the command Q\n";
                    break;
                }
                table.ending();
                break;
            }

            default:
                cout << "\tInvalid command: " << command << endl;
                break;
        }
    }

    cin.rdbuf(cinbuf);
    cout.rdbuf(coutbuf);

    return 0;
}
