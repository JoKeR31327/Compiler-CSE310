#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include "antlr4-runtime.h"
#include "C8086Lexer.h"
#include "C8086Parser.h"
#include <cctype>

using namespace antlr4;
using namespace std;

// Define globals exactly once here
ofstream parserLogFile;
ofstream errorFile;
ofstream lexLogFile;

int syntaxErrorCount = 0;

Symbol_table symbolTable(7);
void appendPrintAsmToOutput(const string& printAsmPath, const string& outputPath) {
    ifstream printAsmFile(printAsmPath);
    if (!printAsmFile.is_open()) {
        cerr << "Error opening print.asm file: " << printAsmPath << endl;
        return;
    }

    ofstream outFile(outputPath, ios::app); // open in append mode
    if (!outFile.is_open()) {
        cerr << "Error opening output.asm for appending: " << outputPath << endl;
        return;
    }

    string line;
    while (getline(printAsmFile, line)) {
        outFile << line << endl;
    }

    printAsmFile.close();
    outFile.close();
}


int main(int argc, const char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <input_file>" << endl;
        return 1;
    }

    // ---- Input File ----
    ifstream inputFile(argv[1]);
    if (!inputFile.is_open()) {
        cerr << "Error opening input file: " << argv[1] << endl;
        return 1;
    }

    string outputDirectory = "output/";
    string parserLogFileName = outputDirectory + "output.asm";
    string errorFileName = outputDirectory + "errorLog.txt";
    string lexLogFileName = outputDirectory + "lexerLog.txt";

    // create output directory if it doesn't exist
    system(("mkdir -p " + outputDirectory).c_str());

    // ---- Output Files ----
    parserLogFile.open(parserLogFileName);
    if (!parserLogFile.is_open()) {
        cerr << "Error opening parser log file: " << parserLogFileName << endl;
        return 1;
    }

    errorFile.open(errorFileName);
    if (!errorFile.is_open()) {
        cerr << "Error opening error log file: " << errorFileName << endl;
        return 1;
    }

    lexLogFile.open(lexLogFileName);
    if (!lexLogFile.is_open()) {
        cerr << "Error opening lexer log file: " << lexLogFileName << endl;
        return 1;
    }

    // ---- Parsing Flow ----
    ANTLRInputStream input(inputFile);
    C8086Lexer lexer(&input);
    CommonTokenStream tokens(&lexer);
    C8086Parser parser(&tokens);

    // use custom error listener (remove default)
    parser.removeErrorListeners();

    // start parsing at the 'start' rule
    parser.start();
    appendPrintAsmToOutput("print.asm", parserLogFileName);
    // clean up
    inputFile.close();
    parserLogFile.close();
    errorFile.close();
    lexLogFile.close();
    cout << "Parsing completed. Check the output files for details." << endl;

    return 0;
}
