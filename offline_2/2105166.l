%option noyywrap
%option c++

%{
#include <iostream>
#include <fstream>
#include <string>
#include "2105166_symbol_table.hpp"
using namespace std;

ofstream token;
ofstream logs;
Symbol_table* table;
int lines = 1;
int errors = 0;
string string_buffer;
string comment_buffer;
string char_buffer;
int char_start_line;
int comment_start_line;
bool escape_flag = false;
bool char_escape_flag;
bool line_continued = false;


void insert_table(const string& name, const string& type) {
    if (!table->look_up(name)) {
        streambuf* old_buf = cout.rdbuf();    
        cout.rdbuf(logs.rdbuf());              
        table->insert(name, type);
        table->print_all_scope_table();
        cout.rdbuf(old_buf);                 
    } else {
        streambuf* old_buf = cout.rdbuf();    
        cout.rdbuf(logs.rdbuf());  
        table->look_up(name);
        cout.rdbuf(old_buf);
    }
}


    void enter_scope(){
        streambuf* old_buf = cout.rdbuf();    
        cout.rdbuf(logs.rdbuf());  
        table->enter_scope();
        cout.rdbuf(old_buf);
    }
    void exit_scope(){
        streambuf* old_buf = cout.rdbuf();    
        cout.rdbuf(logs.rdbuf());  
        table->exit_scope();
        cout.rdbuf(old_buf);
    }


void process_valid_char() {
    char actual_char;
    string val = char_buffer;
    
    if (val.length() == 3) {
        actual_char = val[1];
    } else {
        switch (val[2]) {
            case 'n': actual_char = '\n'; break;
            case 't': actual_char = '\t'; break;
            case 'r': actual_char = '\r'; break;
            case '\\': actual_char = '\\'; break;
            case '\'': actual_char = '\''; break;
            case '"': actual_char = '\"'; break;
            default: actual_char = val[2]; break;
        }
    }

    string val1(1, actual_char);
    token << "<CONST_CHAR, " << val1 << "> ";
    logs << "Line no " << char_start_line << ": Token <CONST_CHAR> Lexeme " 
         << val << " found --> <CONST_CHAR, " << val1 << ">\n";
    insert_table(val, "CONST_CHAR");
}
string process_string_content(const string& str) {
    string result;
    bool escape = false;
    bool in_string = true;  
    
    for (size_t i = 1; i < str.length() - 1; i++) {
        if (str[i] == '\\' && !escape) {
            escape = true;
            continue;
        }
        
        if (escape) {
            switch (str[i]) {
                case 'n': result += '\n'; break;
                case 't': result += '\t'; break;
                case 'r': result += '\r'; break;
                case '\\': result += '\\'; break;
                case '"': result += '"'; break;
                case '\'': result += '\''; break;
                default:
                    result += '\\';
                    result += str[i];
                    break;
            }
            escape = false;
        } else {
            result += str[i];
        }
    }
    
    size_t pos = 0;
    while ((pos = result.find("\\\n", pos)) != string::npos) {
        result.replace(pos, 2, "    ");
        pos += 4;
    }
    
    return result;
}
%}

digit         [0-9]
id            [a-zA-Z_][a-zA-Z0-9_]*
int_const     {digit}+
float_const   ({digit}+"."{digit}*([Ee][-+]?{digit}+)?)|({digit}*"."{digit}+([Ee][-+]?{digit}+)?)|({digit}+[Ee][-+]?{digit}+)
ws            [ \t\r]+

%x STRING COMMENT SINGLE_COMMENT CHAR


%%


\'              { 
                   BEGIN(CHAR); 
                   char_buffer = "'";
                   char_start_line = lines;
                   char_escape_flag = false;
               }

<CHAR>\\        { 
                   char_escape_flag = true; 
                   char_buffer += '\\'; 
               }

<CHAR>\'        { 
    char_buffer += '\'';
    if (char_buffer.length() == 3 ||  
       (char_buffer.length() == 4 && char_buffer[1] == '\\')) {  
        
        if (char_buffer == "'\\'") {
            logs << "Error at line no " << char_start_line 
                 << ": Unterminated character '\\'\n\n";
            errors++;
        } else {
            process_valid_char();
        }
    } else {
        logs << "Error at line no " << char_start_line 
             << ": Multi character constant error " << char_buffer << "\n\n";
        errors++;
    }
    BEGIN(INITIAL);
}

<CHAR>\n        { 
                   logs << "Error at line no " << char_start_line 
                        << ": Unterminated character " << char_buffer << "\n\n";
                   errors++;
                   lines++;
                   BEGIN(INITIAL);
               }

<CHAR>.         { 
                   if (!char_escape_flag && char_buffer.length() > 1) {
                       char_buffer += yytext;
                   } else {
                       char_buffer += yytext;
                       char_escape_flag = false;
                   }
               }

<CHAR><<EOF>>   {
                   logs << "Error at line no " << char_start_line 
                        << ": Unterminated character " << char_buffer << "\n\n";
                   errors++;
                   BEGIN(INITIAL);
               }




\"            { 
    BEGIN(STRING); 
    string_buffer = "\"";
    escape_flag = false;
}

<STRING>\\    { 
    escape_flag = !escape_flag; 
    string_buffer += '\\'; 
}

<STRING>\"    { 
    if (escape_flag) {
        string_buffer += '\"';
        escape_flag = false;
    } else {
        string_buffer += '\"';
        BEGIN(INITIAL);
        string processed = process_string_content(string_buffer);
        logs << "Line no " << lines << ": Token <STRING> Lexeme " << string_buffer 
             << " found --> <STRING, " << processed << ">\n\n"; 
        token << "<STRING, "<<processed<<"> ";
    }
}

<STRING>\\\n  { 
    string_buffer += "\\\n"; 
    lines++; 
}

<STRING>\n    { 
    logs << "Error at line no " << lines << ": Unterminated string " << string_buffer <<"\n\n"; 
    errors++; 
    lines++; 
    BEGIN(INITIAL); 
}

<STRING><<EOF>> {
    logs << "Error at line no " << lines << ": Unterminated string \"" 
         << string_buffer << "\"\n\n";
    errors++;
    BEGIN(INITIAL);
}

<STRING>.     { 
    escape_flag = false;
    string_buffer += yytext; 
}

"//"          { 
                 BEGIN(SINGLE_COMMENT); 
                 comment_buffer = "//";
                 comment_start_line = lines;
             }

<SINGLE_COMMENT>\\\n { 
                 lines++; 
                 comment_buffer += "\\\n";
             }

<SINGLE_COMMENT>\n   { 
                 lines++; 
                 logs << "Line no " << comment_start_line << ": Token <COMMENT> Lexeme " << comment_buffer << " found\n\n";
                 comment_buffer.clear();
                 BEGIN(INITIAL); 
             }

<SINGLE_COMMENT><<EOF>> {
                 logs << "Error at line no " << comment_start_line << ": Unterminated comment "<<comment_buffer<<"\n\n";
                 errors++;
                 comment_buffer.clear();
                 BEGIN(INITIAL);
             }

<SINGLE_COMMENT>.  { comment_buffer += yytext; }

"/*"          { 
                 BEGIN(COMMENT); 
                 comment_buffer = "/*";
                 comment_start_line = lines;
             }

<COMMENT>"*/" { 
                 comment_buffer += "*/";
                 logs << "Line no " << comment_start_line << ": Token <COMMENT> Lexeme " << comment_buffer << " found\n\n";
                 comment_buffer.clear();
                 BEGIN(INITIAL); 
             }

<COMMENT>\n  { 
                 comment_buffer += "\n";
                 lines++; 
             }

<COMMENT><<EOF>> {
                 logs << "Error at line no " << comment_start_line << ": Unterminated comment "<<comment_buffer<<"\n\n";
                 errors++;
                 comment_buffer.clear();
                 BEGIN(INITIAL);
             }

<COMMENT>.    { comment_buffer += yytext; }

"if"        { token << "<IF> ";       logs << "Line no " << lines << ": Token <IF> Lexeme if found\n\n"; }
"else"      { token << "<ELSE> ";     logs << "Line no " << lines << ": Token <ELSE> Lexeme else found\n\n"; }
"goto"      { token << "<GOTO> ";     logs << "Line no " << lines << ": Token <GOTO> Lexeme goto found\n\n"; }
"for"       { token << "<FOR> ";      logs << "Line no " << lines << ": Token <FOR> Lexeme for found\n\n"; }
"while"     { token << "<WHILE> ";    logs << "Line no " << lines << ": Token <WHILE> Lexeme while found\n\n"; }
"long"      { token << "<LONG> ";     logs << "Line no " << lines << ": Token <LONG> Lexeme long found\n\n"; }
"do"        { token << "<DO> ";       logs << "Line no " << lines << ": Token <DO> Lexeme do found\n\n"; }
"break"     { token << "<BREAK> ";    logs << "Line no " << lines << ": Token <BREAK> Lexeme break found\n\n"; }
"short"     { token << "<SHORT> ";    logs << "Line no " << lines << ": Token <SHORT> Lexeme short found\n\n"; }
"int"       { token << "<INT> ";      logs << "Line no " << lines << ": Token <INT> Lexeme int found\n\n"; }
"char"      { token << "<CHAR> ";     logs << "Line no " << lines << ": Token <CHAR> Lexeme char found\n\n"; }
"static"    { token << "<STATIC> ";   logs << "Line no " << lines << ": Token <STATIC> Lexeme static found\n\n"; }
"float"     { token << "<FLOAT> ";    logs << "Line no " << lines << ": Token <FLOAT> Lexeme float found\n\n"; }
"double"    { token << "<DOUBLE> ";   logs << "Line no " << lines << ": Token <DOUBLE> Lexeme double found\n\n"; }
"unsigned"  { token << "<UNSIGNED> "; logs << "Line no " << lines << ": Token <UNSIGNED> Lexeme unsigned found\n\n"; }
"void"      { token << "<VOID> ";     logs << "Line no " << lines << ": Token <VOID> Lexeme void found\n\n"; }
"return"    { token << "<RETURN> ";   logs << "Line no " << lines << ": Token <RETURN> Lexeme return found\n\n"; }
"switch"    { token << "<SWITCH> ";   logs << "Line no " << lines << ": Token <SWITCH> Lexeme switch found\n\n"; }
"case"      { token << "<CASE> ";     logs << "Line no " << lines << ": Token <CASE> Lexeme case found\n\n"; }
"default"   { token << "<DEFAULT> ";  logs << "Line no " << lines << ": Token <DEFAULT> Lexeme default found\n\n"; }
"continue"  { token << "<CONTINUE> "; logs << "Line no " << lines << ": Token <CONTINUE> Lexeme continue found\n\n"; }
"="         { token << "<ASSIGNOP, => "; logs << "Line no " << lines << ": Token <ASSIGNOP> Lexeme = found\n\n"; }
"=="        { token << "<RELOP, ==> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme == found\n\n"; }
"!="        { token << "<RELOP, !=> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme != found\n\n"; }
"<"         { token << "<RELOP, <> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme < found\n\n"; }
">"         { token << "<RELOP, >> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme > found\n\n"; }
"<="        { token << "<RELOP, <=> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme <= found\n\n"; }
">="        { token << "<RELOP, >=> "; logs << "Line no " << lines << ": Token <RELOP> Lexeme >= found\n\n"; }
"+"         { token << "<ADDOP, +> "; logs << "Line no " << lines << ": Token <ADDOP> Lexeme + found\n\n"; }
"-"         { token << "<ADDOP, -> "; logs << "Line no " << lines << ": Token <ADDOP> Lexeme - found\n\n"; }
"*"         { token << "<MULOP, *> "; logs << "Line no " << lines << ": Token <MULOP> Lexeme * found\n\n"; }
"/"         { token << "<MULOP, /> "; logs << "Line no " << lines << ": Token <MULOP> Lexeme / found\n\n"; }
"%"         { token << "<MULOP, %> "; logs << "Line no " << lines << ": Token <MULOP> Lexeme % found\n\n"; }
"++"        { token << "<INCOP, ++> "; logs << "Line no " << lines << ": Token <INCOP> Lexeme ++ found\n\n"; }
"--"        { token << "<INCOP, --> "; logs << "Line no " << lines << ": Token <INCOP> Lexeme -- found\n\n"; }
"&&"        { token << "<LOGICOP, &&> "; logs << "Line no " << lines << ": Token <LOGICOP> Lexeme && found\n\n"; }
"||"        { token << "<LOGICOP, ||> "; logs << "Line no " << lines << ": Token <LOGICOP> Lexeme || found\n\n"; }
"!"         { token << "<NOT, !> "; logs << "Line no " << lines << ": Token <NOT> Lexeme ! found\n\n"; }
"("         { token << "<LPAREN, (> "; logs << "Line no " << lines << ": Token <LPAREN> Lexeme ( found\n\n"; }
")"         { token << "<RPAREN, )> "; logs << "Line no " << lines << ": Token <RPAREN> Lexeme ) found\n\n"; }
"{"         { token << "<LCURL, {> "; logs << "Line no " << lines << ": Token <LCURL> Lexeme { found\n\n"; enter_scope();}
"}"         { token << "<RCURL, }> "; logs << "Line no " << lines << ": Token <RCURL> Lexeme } found\n\n"; exit_scope();}
"["         { token << "<LTHIRD, [> "; logs << "Line no " << lines << ": Token <LTHIRD> Lexeme [ found\n\n"; }
"]"         { token << "<RTHIRD, ]> "; logs << "Line no " << lines << ": Token <RTHIRD> Lexeme ] found\n\n"; }
","         { token << "<COMMA, ,> "; logs << "Line no " << lines << ": Token <COMMA> Lexeme , found\n\n"; }
";"         { token << "<SEMICOLON, ;> "; logs << "Line no " << lines << ": Token <SEMICOLON> Lexeme ; found\n\n"; }

{float_const} { 
    token << "<CONST_FLOAT, " << yytext << "> "; 
    logs << "Line no " << lines << ": Token <CONST_FLOAT> Lexeme " << yytext << " found\n\n";
    insert_table(yytext, "CONST_FLOAT");
}

{int_const} { 
    token << "<CONST_INT, " << yytext << "> "; 
    logs << "Line no " << lines << ": Token <CONST_INT> Lexeme " << yytext << " found\n\n";
    insert_table(yytext, "CONST_INT");
}


{id}        { 
    token << "<ID, " << yytext << "> "; 
    logs << "Line no " << lines << ": Token <ID> Lexeme " << yytext << " found\n\n";
    insert_table(yytext, "ID");
}

\n          { lines++; }

{ws}        { }


[0-9]+(\.[0-9]+){2,} {
    logs << "Error at line no " << lines << ": Too many decimal points " << yytext << "\n\n";
    errors++;
}

[0-9]+[Ee][+-]?[0-9]+\.[0-9]+ {
    logs << "Error at line no " << lines << ": Ill formed number " << yytext << "\n\n";
    errors++;
}

[0-9]+[a-zA-Z_][a-zA-Z0-9_]* {
    logs << "Error at line no " << lines << ": Invalid prefix on ID or invalid suffix on Number " << yytext << "\n\n";
    errors++;
}

'' {
    logs << "Error at line no " << lines << ": Empty character constant error ''\n\n";
    errors++;
}


. {
    logs << "Error at line no " << lines << ": Unrecognized character " << yytext << "\n\n";
    errors++;
}

%%

int main(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " input_file.c\n";
        return 1;
    }

    ifstream input(argv[1]);
    if (!input.is_open()) {
        perror("Can't open file");
        return 1;
    }

    token.open("input_token.txt");
    logs.open("input_logs.txt");
    table = new Symbol_table(7);
    yyFlexLexer lexer(&input);
    lexer.yylex();

    streambuf* old_buf = cout.rdbuf();    
        cout.rdbuf(logs.rdbuf());  
        table->print_all_scope_table();
        cout.rdbuf(old_buf);

    logs << "Total lines: " << lines << endl;
    logs << "Total errors: " << errors << endl;

    delete table;
    token.close();
    logs.close();
    input.close();
    return 0;
}