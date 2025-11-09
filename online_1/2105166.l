%option noyywrap
%option c++

%{
#include <iostream>
#include <string.h>
#include <fstream>
#include <stdlib.h>
#include "FlexLexer.h"

using namespace std;

int line_num = 0;
int expected_stars = -1;
int expected_pluses = -1;
bool last_line_found = false;

void error_stars(int line) {
    cout << "Error at line " << line << ": Stars on left and right not equal" << endl;
    exit(0);
}

void error_plus(int line) {
    cout << "Error at line " << line << ": Number of pluses incorrect" << endl;
    exit(0);
}

void error_pattern(int line) {
    cout << "Error at line " << line << ": Invalid character or format" << endl;
    exit(0);
}

void error_incomplete(int line) {
    cout << "Error at line " << line << ": Unexpected end of file; incomplete pyramid" << endl;
    exit(0);
}

void error_last_line(int line) {
    cout << "Error at line " << line << ": Last line must have no stars" << endl;
    exit(0);
}
%}

%%
.*\n {
    line_num++;
    char *line = strdup(yytext);
    line[strcspn(line, "\n")] = 0;

    int len = strlen(line);
    if (len == 0) {
        free(line);
        error_pattern(line_num);
    }


    int i = 0;
    while (i < len && line[i] == '*') i++;
    int left_stars = i;


    int j = i;
    while (j < len && line[j] == '+') j++;
    int pluses = j - i;

    int k = j;
    while (k < len && line[k] == '*') k++;
    int right_stars = k - j;

    if (k != len) {
        free(line);
        error_pattern(line_num);
    }


    if (left_stars == 0 && right_stars == 0 && pluses == len) {
        last_line_found = true;
        cout << "Pattern matched successfully!" << endl;
        exit(0);
    }


    if (left_stars != right_stars) {
        free(line);
        error_stars(line_num);
    }


    if (line_num == 1) {
        expected_stars = left_stars;
        expected_pluses = pluses;
        if (pluses != 1) {
            free(line);
            error_plus(line_num);
        }
    } else {
        if (left_stars != expected_stars - 1) {
            free(line);
            error_pattern(line_num);
        }
        if (pluses != expected_pluses + 2) {
            free(line);
            error_plus(line_num);
        }
        expected_stars = left_stars;
        expected_pluses = pluses;
    }

    free(line);
}

. {
    error_pattern(line_num + 1);
}
%%

int main(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " input_file.txt" << endl;
        return 1;
    }

    ifstream input(argv[1]);
    if (!input.is_open()) {
        perror("Can't open file");
        return 1;
    }

    yyFlexLexer lexer(&input);
    lexer.yylex();

    if (!last_line_found) {
        error_incomplete(line_num + 1);
    }

    return 0;
}
