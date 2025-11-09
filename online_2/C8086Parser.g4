
parser grammar C8086Parser;

options {
    tokenVocab = C8086Lexer;
}

@parser::header {
    #include <iostream>
    #include <fstream>
    #include <string>
    #include <vector>
    #include <sstream>
    #include <unordered_set>
    #include <cctype>
    #include "2105166_symbol_table.hpp"
    using namespace std;
    extern ofstream parserLogFile;
    extern ofstream errorFile;
    extern int syntaxErrorCount;
    extern Symbol_table symbolTable;
}

@parser::members {

    string currentFunctionName = "";
    bool enter_param=false;
    unordered_map<string, bool> declaredFunctions;
    unordered_map<string, int> functionParam;
    string currentFunctionReturnType = "";
    bool inex = false;
    string show="";
    string label="";
    
    void log_table() {
        streambuf* oldCout = cout.rdbuf();  
        cout.rdbuf(parserLogFile.rdbuf());      
        symbolTable.print_all_scope_table();         
        cout.rdbuf(oldCout);     
    }

    void writeIntoparserLogFile(const string& message) {
        if (!parserLogFile) {
            cout << "Error opening parserLogFile.txt" << endl;
            return;
        }
        parserLogFile << message << "\n";
        parserLogFile.flush();
    }

    void writeIntoErrorFile(const string& message) {
        if (!errorFile) {
            cout << "Error opening errorFile.txt" << endl;
            return;
        }
        errorFile << message << endl;
        errorFile.flush();
    }

string join(const vector<string>& vec, const string& delim = ", ") {
    ostringstream oss;
    for (size_t i = 0; i < vec.size(); ++i) {
        if (i > 0) oss << delim;
        oss << vec[i];
    }
    return oss.str();
}

string formatCode(const string& input) {
    string output, token;
    const unordered_set<string> keywords = {"int", "float", "char", "void", "double", "return"};
    
    bool insideForHeader = false;
    int parenDepth = 0;

    auto isIdentifierChar = [](char c) {
        return isalnum(c) || c == '_';
    };

    auto isKeyword = [&](const string& tok) {
        for (const auto& kw : keywords) {
            if (tok.substr(0, kw.size()) == kw) {
                return kw;
            }
        }
        return string();
    };

    auto lookaheadIsFor = [&](size_t i) {
        while (i < input.length() && isspace(input[i])) ++i;
        return input.compare(i, 4, "for(") == 0 || input.compare(i, 5, "for (") == 0;
    };

    auto handleElse = [&](size_t& i) {
        size_t pos = i + 1;
        while (pos < input.length() && isspace(input[pos])) ++pos;
        if (input.substr(pos, 4) == "else") {
            output += "else ";
            i = pos + 3;
            return true;
        }
        return false;
    };

    for (size_t i = 0; i < input.length(); ++i) {
        char c = input[i];

        if (lookaheadIsFor(i)) {
            insideForHeader = true;
            parenDepth = 0;
        }

        if (isIdentifierChar(c) || (c == '.' && i + 1 < input.length() && isdigit(input[i + 1]))) {
            token += c;
            continue;
        }

        if (!token.empty()) {
            string kw = isKeyword(token);
            if (!kw.empty()) {
                output += kw + " " + token.substr(kw.size());
            } else {
                output += token;
            }
            token.clear();
        }

        switch (c) {
            case ';':
                output += ';';
                if (!insideForHeader || parenDepth == 0)
                    output += '\n';
                break;

            case ',':
                output += ',';
                break;

            case '{':
                output += "{\n";
                break;

            case '}':
                output += "}";
                if (!handleElse(i)) {
                    output += "\n";
                }
                break;

            case '(':
                output += '(';
                if (insideForHeader) ++parenDepth;
                break;

            case ')':
                output += ')';
                if (insideForHeader && --parenDepth == 0) {
                    insideForHeader = false;
                }
                break;

            case '[':
                output += '[';
                break;

            case ']':
                output += ']';
                break;

            case ' ':
                break;

            default:
                output += c;
                break;
        }
    }

    if (!token.empty()) {
        string kw = isKeyword(token);
        if (!kw.empty()) {
            output += kw + " " + token.substr(kw.size());
        } else {
            output += token;
        }
    }

    return output;
}



}

start
    : p=program EOF {
        writeIntoparserLogFile("Line " + to_string(_input->get(_input->size() - 1)->getLine()) + ": start : program\n");
        log_table();
        writeIntoparserLogFile("Total number of lines: " + to_string(_input->get(_input->size() - 1)->getLine()));
        writeIntoparserLogFile("Total number of errors: " + to_string(syntaxErrorCount));
    }
    ;

program
    : p1=program u=unit {
        writeIntoparserLogFile("Line " + to_string($u.e) + ": program : program unit\n" +
                               formatCode($text) + "\n");
    }
    | u=unit {
        writeIntoparserLogFile("Line " + to_string($u.e) + ": program : unit\n" +
                               formatCode($text) + "\n");
    }
    ;

unit returns [int e]
    : vd=var_declaration {
        $e=$vd.start->getLine();
        writeIntoparserLogFile("Line " + to_string($vd.start->getLine()) + ": unit : var_declaration\n" + 
                              formatCode($text) + "\n");
    }
    | fd_decl=func_declaration {
        $e=$fd_decl.start->getLine();
        writeIntoparserLogFile("Line " + to_string($fd_decl.start->getLine()) + ": unit : func_declaration\n" + 
                              formatCode($text) + "\n");
    }
    | fd_def=func_definition {
        $e=$fd_def.end;
        writeIntoparserLogFile("Line " + to_string($fd_def.end) + ": unit : func_definition\n" + 
                              formatCode($text) + "\n");
    }
    ;

func_declaration
    : t=type_specifier id=ID LPAREN 
      {
        currentFunctionReturnType = $t.name;
        if (!symbolTable.insert($id.text, "ID")) {
            writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                              ": Multiple declaration of " + $id.text);
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                              ": Multiple declaration of " + $id.text);
        } else {
            declaredFunctions[$id.text] = true;
            Symbol_info* temp = symbolTable.look_up($id.text);
            if (temp) {
                temp->is_type = $t.name;
            }
            
        }
      }
      pl=parameter_list
       RPAREN SEMICOLON 
      {
        Symbol_info* temp1 = symbolTable.look_up($id.text);
            if (temp1) {
                temp1->p_count=$pl.count;
            }
        writeIntoparserLogFile("Line " + to_string($t.start->getLine()) +
            ": func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n\n" +
            formatCode($text) + "\n");
      }

    | t=type_specifier id=ID LPAREN 
      {
        currentFunctionReturnType = $t.name;
        if (!symbolTable.insert($id.text, "ID")) {
            writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                              ": Multiple declaration of " + $id.text);
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                              ": Multiple declaration of " + $id.text);
        } else {
            declaredFunctions[$id.text] = true;
            Symbol_info* temp = symbolTable.look_up($id.text);
            if (temp) {
                temp->is_type = $t.name;
            }
        }
      }
      RPAREN SEMICOLON 
      {
        writeIntoparserLogFile("Line " + to_string($t.start->getLine()) +
            ": func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON\n\n" +
            formatCode($text) + "\n");
      }
    ;


func_definition returns [int end]
    : t=type_specifier id=ID 
      {
         currentFunctionReturnType = $t.name;
         currentFunctionName = $id.text;
        if (!declaredFunctions[$id.text]) {
            if (!symbolTable.insert($id.text, "ID")) {
                writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                                  ": Multiple declaration of " + $id.text);
                syntaxErrorCount++;
                
                writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                                  ": Multiple declaration of n" + $id.text);
            }
        }
        Symbol_info* temp = symbolTable.look_up($id.text);
            if (temp) {
                temp->is_type = $t.name;
            }
      }
      LPAREN 
      {
        symbolTable.enter_scope();
        enter_param = true;
      }
      pl=parameter_list RPAREN 
      cs=compound_statement 
      {

        Symbol_info* temp1 = symbolTable.look_up($id.text);
            if (temp1) {
                if(declaredFunctions[$id.text]){
                    if(temp1->p_count!=$pl.count){
                        writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                ": Total number of arguments mismatch with declaration in function " + $id.text + "\n");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                ": Total number of arguments mismatch with declaration in function " + $id.text + "\n");
                    }
                }
                else{ 
                temp1->p_count=$pl.count;
                temp1->param_types=$pl.params;
                }
            }
        $end = $cs.endLine;
        writeIntoparserLogFile("Line " + to_string($cs.endLine) +
            ": func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement\n\n" +
            formatCode($text) + "\n");
        enter_param = false;
        symbolTable.exit_scope();
      }

    | t=type_specifier id=ID 
      {
        currentFunctionReturnType = $t.name;
        currentFunctionName = $id.text;
        if (!declaredFunctions[$id.text]) {
            if (!symbolTable.insert($id.text, "ID")) {
                writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                                  ": Multiple declaration of " + $id.text);
                syntaxErrorCount++;
                writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                                  ": Multiple declaration of " + $id.text);
            }
        }
        Symbol_info* temp = symbolTable.look_up($id.text);
            if (temp) {
                temp->is_type = $t.name;
            }
      }
      LPAREN 
      {
        symbolTable.enter_scope();
      }
      RPAREN 
      cs=compound_statement 
      {
        // currentFunctionName = $id.text;
        $end = $cs.endLine;
        writeIntoparserLogFile("Line " + to_string($cs.endLine) +
            ": func_definition : type_specifier ID LPAREN RPAREN compound_statement\n\n" +
            formatCode($text) + "\n");
        symbolTable.exit_scope();
      }
    ;



parameter_list returns [int count, vector<string> params]
    : pl=parameter_list COMMA ts=type_specifier id=ID {
        $count = $pl.count + 1;
        $params = $pl.params;
        $params.push_back($ts.name);

        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": parameter_list : parameter_list COMMA type_specifier ID\n\n" +
            formatCode($text) + "\n");

        if (enter_param) {
            if (!symbolTable.insert($id->getText(), "ID")) {
                writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                    ": Multiple declaration of "+ $id->getText() + " in parameter\n" );
                syntaxErrorCount++;

                writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                    ": Multiple declaration of "+ $id->getText() + " in parameter\n" );
            }
            Symbol_info* temp = symbolTable.look_up($id->getText());
            if (temp) temp->is_type = $ts.name;
        }
    }

    | pl=parameter_list COMMA ts=type_specifier {
        $count = $pl.count;
        $params = $pl.params;

        syntaxErrorCount++;
        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": parameter_list : parameter_list COMMA type_specifier\n\n" +
            formatCode($ts.name) + "\n");

        writeIntoErrorFile("Error at line " + to_string($ts.start->getLine()) +
            ": parameter name missing after type_specifier");
    }

    | ts=type_specifier id=ID {
        $count = 1;
        $params.push_back($ts.name);

        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": parameter_list : type_specifier ID\n\n" + $ts.name + " " + $id->getText() + "\n");

        if (enter_param) {
            if (!symbolTable.insert($id->getText(), "ID")) {
                writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                    ": Multiple declaration of parameter " + $id->getText());
                syntaxErrorCount++;

                writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                    ": Multiple declaration of parameter " + $id->getText());
            }
            Symbol_info* temp = symbolTable.look_up($id->getText());
            if (temp) temp->is_type = $ts.name;
        }
    }

    | ts=type_specifier {
        $count = 0;
        $params.clear(); // Or just leave as empty

        syntaxErrorCount++;
        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": type_specifier : " + $ts.name + "\n" + $ts.name + "\n");

        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": parameter_list : type_specifier\n" + $ts.name + "\n");

        writeIntoErrorFile("Error at line " + to_string($ts.start->getLine()) +
            ": syntax error\n");

        writeIntoErrorFile("Error at line " + to_string($ts.start->getLine()) +
            ": 1st parameter's name not given in function definition of " + currentFunctionName+"\n");

        writeIntoparserLogFile("Error at line " + to_string($ts.start->getLine()) +
            ": 1st parameter's name not given in function definition of " + currentFunctionName+"\n");
    }

    | ts=type_specifier ADDOP {
        $count = 0;
        $params.clear();

        syntaxErrorCount++;

        writeIntoparserLogFile("Line " + to_string($ts.start->getLine()) +
            ": parameter_list : type_specifier\n" +
            formatCode($ts.name) + "\n");

        writeIntoErrorFile("Error at line " + to_string($ts.start->getLine()) +
            ": syntax error, unexpected ADDOP, expecting RPAREN or COMMA\n");

        writeIntoparserLogFile("Error at line " + to_string($ts.start->getLine()) +
            ": syntax error, unexpected ADDOP, expecting RPAREN or COMMA\n");
    }
    ;





compound_statement returns [int endLine]
    : LCURL statements  RCURL {
        $endLine = $RCURL->getLine();
        writeIntoparserLogFile("Line " + to_string($RCURL->getLine()) +
            ": compound_statement : LCURL statements RCURL\n" +
            formatCode($text) + "\n");
            log_table();
            

    }
    | LCURL RCURL {
        $endLine = $RCURL->getLine();
        writeIntoparserLogFile("Line " + to_string($RCURL->getLine()) +
            ": compound_statement : LCURL RCURL\n" +
            formatCode("{}") + "\n");
            log_table();

        
    }
    ;


var_declaration 
    : t=type_specifier dl=declaration_list sm=SEMICOLON {
        if ($t.name == "void") {
            writeIntoErrorFile("Error at line " + to_string($t.start->getLine()) +
                ": Variable type cannot be void\n");
            syntaxErrorCount++;

            writeIntoparserLogFile("Error at line " + to_string($t.start->getLine()) +
                ": Variable type cannot be void\n");
        }
        for (auto& name : $dl.names) {  
            bool isArray = false;
            string symbolName = name;

            size_t bracketPos = symbolName.find('[');
            if (bracketPos != string::npos) {
                isArray = true;
                symbolName = symbolName.substr(0, bracketPos); 
            }

            if (!symbolTable.insert(symbolName, "ID")) {
                writeIntoErrorFile("Error at line " + to_string($sm->getLine()) + 
                                   ": Multiple declaration of " + symbolName);
                syntaxErrorCount++;

                writeIntoparserLogFile("Error at line " + to_string($sm->getLine()) + 
                                       ": Multiple declaration of " + symbolName);
            } else {
                Symbol_info* temp = symbolTable.look_up(symbolName);
                if (temp){ temp->is_array = isArray;
                    temp->is_type=$t.text;
                }
            }
        }


            writeIntoparserLogFile("Line " + to_string($sm->getLine()) + 
            ": var_declaration : type_specifier declaration_list SEMICOLON\n" + formatCode($text) + "\n");
    }

    ;

declaration_list_err returns [string error_name]
    : ID { $error_name = "Syntax error in declaration list"; }
    | ADDOP {$error_name = "syntax error, unexpected ADDOP, expecting COMMA or SEMICOLON";}
    ;

type_specifier returns [string name]
    : INT {
        $name = "int";
        writeIntoparserLogFile("Line " + to_string($INT->getLine()) + ": type_specifier : INT\nint\n");
    }
    | FLOAT {
        $name = "float";
        writeIntoparserLogFile("Line " + to_string($FLOAT->getLine()) + ": type_specifier : FLOAT\nfloat\n");
    }
    | VOID {
        $name = "void";
        writeIntoparserLogFile("Line " + to_string($VOID->getLine()) + ": type_specifier : VOID\nvoid\n");
    }
    ;

declaration_list
returns [vector<string> names]
    : dl=declaration_list COMMA idToken=ID LTHIRD CONST_INT RTHIRD {
        $names = $dl.names;
        $names.push_back($idToken->getText() + "[" + $CONST_INT->getText() + "]");
        writeIntoparserLogFile("Line " + to_string($idToken->getLine()) + 
            ": declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n" +
            formatCode(join($names)) + "\n");
    }
    
    | dl=declaration_list COMMA idToken=ID {


        $names = $dl.names;
        $names.push_back($idToken.text);
        writeIntoparserLogFile("Line " + to_string($idToken->getLine()) + 
            ": declaration_list : declaration_list COMMA ID\n" +
            formatCode(join($names)) + "\n");
    }
    | idToken=ID LTHIRD CONST_INT RTHIRD {
        $names.push_back($idToken->getText() + "[" + $CONST_INT->getText() + "]");
        writeIntoparserLogFile("Line " + to_string($idToken->getLine()) + 
            ": declaration_list : ID LTHIRD CONST_INT RTHIRD\n" +
            formatCode(join($names)) + "\n");
    }
    |idToken=ID op=ADDOP ID {
    $names.push_back($idToken.text);

    writeIntoparserLogFile("Line " + to_string($idToken->getLine()) + 
            ": declaration_list : ID\n" +
            formatCode(join($names)) + "\n");
    writeIntoErrorFile(
        "Error at line " + to_string($idToken->getLine()) +
        ": syntax error, unexpected ADDOP, expecting COMMA or SEMICOLON\n");

    syntaxErrorCount++;

    writeIntoparserLogFile(
        "Error at line " + to_string($idToken->getLine()) +
        ": syntax error, unexpected ADDOP, expecting COMMA or SEMICOLON\n");
    } 
     | idToken=ID {
        $names.push_back($idToken->getText());
        writeIntoparserLogFile("Line " + to_string($idToken->getLine()) + 
            ": declaration_list : ID\n" +
            formatCode(join($names)) + "\n");
    } 
       
    ;



statements
    : s1=statements s2=statement {
        writeIntoparserLogFile("Line " + to_string($s2.endLine) + ": statements : statements statement\n" +
                               formatCode($text) + "\n");
    }
    | s=statement {
        writeIntoparserLogFile("Line " + to_string($s.endLine) + ": statements : statement\n" +
                               formatCode($text) + "\n");
    }
    ;


statement returns [int endLine]
    : v=var_declaration {
        $endLine = $v.stop->getLine();
        writeIntoparserLogFile("Line " + to_string($v.start->getLine()) + ": statement : var_declaration\n" + formatCode($text) + "\n");
    }
    | exprStmt=expression_statement {
        $endLine = $exprStmt.stop->getLine();
        writeIntoparserLogFile("Line " + to_string($exprStmt.start->getLine()) + ": statement : expression_statement\n" + formatCode($text) + "\n");
    }
    | {symbolTable.enter_scope();}c=compound_statement {symbolTable.exit_scope();}{
        $endLine = $c.endLine;
        writeIntoparserLogFile("Line " + to_string($c.endLine) + ": statement : compound_statement\n" + formatCode($text) + "\n");
    }
    | FOR LPAREN es1=expression_statement es2=expression_statement ex3=expression RPAREN s=statement {
        $endLine = $s.endLine;
        writeIntoparserLogFile("Line " + to_string($endLine) + ": statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement\n" + formatCode($text) + "\n");
    }
    | IF LPAREN cond=expression RPAREN thenStmt=statement {
        $endLine = $thenStmt.endLine;
        writeIntoparserLogFile("Line " + to_string($endLine) + ": statement : IF LPAREN expression RPAREN statement\n" + formatCode($text) + "\n");
    }
    | IF LPAREN cond=expression RPAREN thenStmt=statement ELSE elseStmt=statement {
        $endLine = $elseStmt.endLine;
        writeIntoparserLogFile("Line " + to_string($endLine) + ": statement : IF LPAREN expression RPAREN statement ELSE statement\n" + formatCode($text)+ "\n");
    }
    | WHILE LPAREN cond=expression RPAREN loopStmt=statement {
        $endLine = $loopStmt.endLine;
        writeIntoparserLogFile("Line " + to_string($endLine) + ": statement : WHILE LPAREN expression RPAREN statement\n" + formatCode($text) + "\n");
    }
    | RETURN val=expression SEMICOLON {
        $endLine = $SEMICOLON->getLine();
        Symbol_info* sym = symbolTable.look_up($val.text);
         if (currentFunctionReturnType == "void") {
        writeIntoErrorFile("Error at line " + to_string($RETURN->getLine()+1) +
            ": Cannot return value from function " + currentFunctionName + " with void return type\n");
        syntaxErrorCount++;
        writeIntoparserLogFile("Error at line " + to_string($RETURN->getLine()+1) +
            ": Cannot return value from function " + currentFunctionName + " with void return type");
    }
    else if (sym && sym->is_type != currentFunctionReturnType) {
        writeIntoErrorFile("Error at line " + to_string($RETURN->getLine()) +
            ": Return type mismatch of " + currentFunctionName+ "\n");
        syntaxErrorCount++;
        writeIntoparserLogFile("Error at line " + to_string($RETURN->getLine()) +
            ": Return type mismatch of " + currentFunctionName +"\n");
    }


        writeIntoparserLogFile("Line " + to_string($RETURN->getLine()) + ": statement : RETURN expression SEMICOLON\n" + formatCode($text) + "\n");
    }
    | PRINTLN LPAREN id=ID RPAREN SEMICOLON {
        $endLine = $id->getLine();
         if (!symbolTable.look_up($id.text)) {
            writeIntoErrorFile("Error at line " + to_string($id->getLine()) + ": Undeclared variable " + $id.text+"\n");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($id->getLine()) + ": Undeclared variable " + $id.text+"\n");
        }
        writeIntoparserLogFile("Line " + to_string($id->getLine()) + ": statement : PRINTLN LPAREN ID RPAREN SEMICOLON\n" + 
                              "printf(" + $id->getText() + ");\n");
    }
    |lbl=labelstatement COLON{
        $endLine=$COLON->getLine();
        label=$lbl.l;
        writeIntoparserLogFile("Line " + to_string($endLine) + "label declared named "
                    +label + "\n");
                    }
    |GOTO lb=LABEL SEMICOLON {
        writeIntoparserLogFile("Line " + to_string($lb->getLine()) + " The new rule you wrote that matched \n"
                    +formatCode($text) + "\n");
                    if($lb.text!=label){
                        writeIntoparserLogFile("Line " + to_string($lb->getLine()) + " No label declared named "
                    +$lb.text + "\n");
                    }

    }
    ;

labelstatement returns [string l]
    : lb=ID COLON{
        $l=$lb.text;
    }
    ;




expression_statement
    : s=SEMICOLON {
        writeIntoparserLogFile("Line " + to_string($s->getLine()) + ": expression_statement : SEMICOLON\n;\n");
    }
    | e=expression s=SEMICOLON {
        writeIntoparserLogFile("Line " + to_string($s->getLine()) + ": expression_statement : expression SEMICOLON\n" +
                               formatCode($text) + "\n");
    }
    ;

variable
    : id=ID {
        if (!symbolTable.look_up($id->getText())) {
            writeIntoErrorFile("Error at line " + to_string($id->getLine()) + 
                              ": Undeclared variable " + $id->getText());
            syntaxErrorCount++;
             writeIntoparserLogFile("Error at line " + to_string($id->getLine()) + 
                              ": Undeclared variable " + $id->getText());
        }
        writeIntoparserLogFile("Line " + to_string($id->getLine()) + ": variable : ID\n" + $id->getText() + "\n");
    }
    | id=ID LTHIRD e=expression RTHIRD {
         string exprText = $e.text;
        if (exprText.find('.') != string::npos) {
            writeIntoErrorFile("Error at line " + to_string($e.start->getLine()) +
                               ": Expression inside third brackets not an integer");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($e.start->getLine()) +
                               ": Expression inside third brackets not an integer");
        }  
        Symbol_info* temp = symbolTable.look_up($id->getText());
        if(temp){if(!temp->is_array){
            writeIntoErrorFile("Error at line " + to_string($e.start->getLine())+": " + $id->getText() + " not an array\n");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($e.start->getLine()) +": " + $id->getText() + " not an array\n");

        }
        }
        writeIntoparserLogFile("Line " + to_string($id->getLine()) + ": variable : ID LTHIRD expression RTHIRD\n" +
                               $id->getText()+ "["+ formatCode($e.text) + "]\n");
    }
    ;

expression 
    :  l=logic_expression {
        writeIntoparserLogFile("Line " + to_string($l.start->getLine()) + ": expression : logic_expression\n" +
                               formatCode($text) + "\n");
    }
    | v=variable op=ASSIGNOP {inex=true;} l=logic_expression {inex=false;}{
        

        
        Symbol_info* varInfo = symbolTable.look_up($v.text);
        if (varInfo && varInfo->is_array) {
            writeIntoErrorFile("Error at line " + to_string($op->getLine()) +
                ": Type mismatch, " + $v.text + " is an array");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($op->getLine()) +
                ": Type mismatch, " + $v.text + " is an array");
        }
            string symbolName = $v.text;
            size_t bracketPos = symbolName.find('[');
            if (bracketPos != string::npos) {
                symbolName = symbolName.substr(0, bracketPos); 
            }
            varInfo = symbolTable.look_up(symbolName);
         if (varInfo && varInfo->is_type == "int" && $l.type=="float") {
            writeIntoErrorFile("Error at line " + to_string($op->getLine()) + ": Type Mismatch");
            syntaxErrorCount++;
            writeIntoparserLogFile("Error at line " + to_string($op->getLine()) + ": Type Mismatch");
        }
        


        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": expression : variable ASSIGNOP logic_expression\n" +
                               formatCode($text) + "\n");
    }
    | variable ASSIGNOP logic_expression ADDOP ASSIGNOP l=logic_expression{
        
    }
    ;

logic_expression returns [string type]
    : r=rel_expression {
        $type=$r.type;
        writeIntoparserLogFile("Line " + to_string($r.start->getLine()) + ": logic_expression : rel_expression\n" +
                               formatCode($text) + "\n");
    }
    | r1=rel_expression op=LOGICOP r2=rel_expression {
        if ($r1.type == "float" || $r2.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": logic_expression : rel_expression LOGICOP rel_expression\n" +
                               formatCode($text) + "\n");
    }
    ;

rel_expression returns [string type]
    : s=simple_expression {
        $type=$s.type;
        writeIntoparserLogFile("Line " + to_string($s.start->getLine()) + ": rel_expression : simple_expression\n" +
                               formatCode($text) + "\n");
    }
    | s1=simple_expression op=RELOP s2=simple_expression {
        if ($s1.type == "float" || $s2.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": rel_expression : simple_expression RELOP simple_expression\n" +
                               formatCode($text) + "\n");
    }
    ;

simple_expression returns [string type]
    : t=term {
        $type=$t.type;
        writeIntoparserLogFile("Line " + to_string($t.start->getLine()) + ": simple_expression : term\n" +
                               formatCode($text) + "\n");
    }
    |s=simple_expression op=ADDOP ap=ASSIGNOP t=term {
        if ($s.type == "float" || $t.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        writeIntoparserLogFile("Error at line " + to_string($op->getLine()) + ": syntax error, unexpected ASSIGNOP\n");
        syntaxErrorCount++;
        writeIntoErrorFile("Error at line " + to_string($op->getLine()) + ": syntax error, unexpected ASSIGNOP\n");
        


    }
    | s=simple_expression op=ADDOP t=term {
        if ($s.type == "float" || $t.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": simple_expression : simple_expression ADDOP term\n" +
                               formatCode($text) + "\n");
    }
    ;

term returns [string type]
    : u=unary_expression {
        $type=$u.type;
        writeIntoparserLogFile("Line " + to_string($u.start->getLine()) + ": term : unary_expression\n" +
                               formatCode($text) + "\n");
    }
    | t=term op=MULOP u=unary_expression {
        if ($t.type == "float" || $u.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        if ($op.text == "%") {
            $type="int";
            if ($u.start->getText() == "0") {
                writeIntoErrorFile("Error at line " + to_string($op->getLine()) + ": Modulus by Zero\n");
                syntaxErrorCount++;
                writeIntoparserLogFile("Error at line " + to_string($op->getLine()) + ": Modulus by Zero\n");
            }

            if ($t.text.find('.') != string::npos || $u.text.find('.') != string::npos) {
                writeIntoErrorFile("Error at line " + to_string($op->getLine()) +
                    ": Non-Integer operand on modulus operator");
                syntaxErrorCount++;
                writeIntoparserLogFile("Error at line " + to_string($op->getLine()) +
                    ": Non-Integer operand on modulus operator");
            }
        }

        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": term : term MULOP unary_expression\n" +
                               formatCode($text) + "\n");
    }
    ;


unary_expression returns [string type]
    : op=ADDOP u=unary_expression {
        $type=$u.type;
        writeIntoparserLogFile("Line " + to_string($op->getLine()) + ": unary_expression : ADDOP unary_expression\n" +
                               formatCode($text) + "\n");
    }
    | n=NOT u=unary_expression {
        $type=$u.type;
        writeIntoparserLogFile("Line " + to_string($n->getLine()) + ": unary_expression : NOT unary_expression\n" +
                               formatCode($text) + "\n");
    }
    | f=factor {
        $type=$f.type;
        writeIntoparserLogFile("Line " + to_string($f.start->getLine()) + ": unary_expression : factor\n" +
                               formatCode($text) + "\n");
    }
    ;

factor returns [string type]
    : v=variable {
        $type="";
        writeIntoparserLogFile("Line " + to_string($v.start->getLine()) + ": factor : variable\n" +
                               formatCode($text) + "\n");
    }
    | id=ID LPAREN a=argument_list RPAREN {
        $type="";
    Symbol_info* funcSym = symbolTable.look_up($id.text);
    if (!funcSym) {
        writeIntoErrorFile("Error at line " + to_string($id->getLine()) + ": Undefined function " + $id.text + "\n");
        syntaxErrorCount++;
        writeIntoparserLogFile("Error at line " + to_string($id->getLine()) + ": Undefined function " + $id.text + "\n");
    } 
    else {
                if (inex && funcSym->is_type == "void") {
                    writeIntoErrorFile("Error at line " + to_string($id->getLine()) + ": Void function used in expression\n");
                    syntaxErrorCount++;
                    writeIntoparserLogFile("Error at line " + to_string($id->getLine()) + ": Void function used in expression\n");
                }
                if (funcSym->p_count != $a.args.size()) {
                    writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                        ": Total number of arguments mismatch with declaration in function " + $id.text + "\n");
                    syntaxErrorCount++;
                    writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                        ": Total number of arguments mismatch with declaration in function " + $id.text + "\n");
                }

                for (auto& arg : $a.args) {
                    Symbol_info* argSym = symbolTable.look_up(arg);
                    if (argSym && argSym->is_array) {
                        writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                            ": Type mismatch, " + arg + " is an array\n");
                        syntaxErrorCount++;
                        writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                            ": Type mismatch, " + arg + " is an array\n");
                    }
                    
                }
                if (funcSym && funcSym->p_count > 0) {
                    for (int i = 0; i < funcSym->p_count; i++) {
                    if (i >= $a.args.size()) break;

                    // Symbol_info* argSym = symbolTable.look_up($a.args[i]);
                    // string actualType = (argSym) ? argSym->is_type : "undefined";
                    string actualType= "";
                    if (i < $a.types.size() && !$a.types[i].empty()) {
                        actualType = $a.types[i];
                    }

                    if (!funcSym->param_types.empty() && actualType!="" && funcSym->param_types[i] != actualType) {
                        writeIntoErrorFile("Error at line " + to_string($id->getLine()) +
                            ": " + to_string(i + 1) + "th argument mismatch in function " + $id.text + "\n");
                        syntaxErrorCount++;
                        writeIntoparserLogFile("Error at line " + to_string($id->getLine()) +
                            ": " + to_string(i + 1) + "th argument mismatch in function " + $id.text + "\n");
                        break;
                    }
    }
}



    }

    writeIntoparserLogFile("Line " + to_string($id->getLine()) +
        ": factor : ID LPAREN argument_list RPAREN\n" +
        formatCode($text) + "\n");
}

    | LPAREN e=expression RPAREN {
        $type="";
        writeIntoparserLogFile("Line " + to_string($LPAREN->getLine()) + ": factor : LPAREN expression RPAREN\n" +
                               formatCode($text) + "\n");
    }
    | ci=CONST_INT {
        $type="int";
        writeIntoparserLogFile("Line " + to_string($ci->getLine()) + ": factor : CONST_INT\n" + $ci->getText() + "\n");
    }
    | cf=CONST_FLOAT {
        $type="float";
        writeIntoparserLogFile("Line " + to_string($cf->getLine()) + ": factor : CONST_FLOAT\n" + formatCode($cf->getText()) + "\n");
    }
    | v=variable INCOP {
        $type="";
        writeIntoparserLogFile("Line " + to_string($INCOP->getLine()) + ": factor : variable INCOP\n" +
                               formatCode($text) + "\n");
    }
    | v=variable DECOP {
        $type="";
        writeIntoparserLogFile("Line " + to_string($DECOP->getLine()) + ": factor : variable DECOP\n" +
                               formatCode($text) + "\n");
    }
    ;

argument_list returns [vector<string> args, vector<string> types]
    : a=arguments {
        $args = $a.args;
        $types= $a.types;
        writeIntoparserLogFile("Line " + to_string($a.start->getLine()) + ": argument_list : arguments\n" +
                               formatCode($text) + "\n");
    }
    | {
        writeIntoparserLogFile("Line " + to_string(_input->LT(1)->getLine()) + ": argument_list : /* empty */\n");
    }
    ;

arguments returns [vector<string> args, vector<string> types]
    : a=arguments COMMA l=logic_expression {
        $args = $a.args;
        $types= $a.types;
        $args.push_back($l.text);
        if($l.type!="")$types.push_back($l.type);
        writeIntoparserLogFile("Line " + to_string($COMMA->getLine()) +
            ": arguments : arguments COMMA logic_expression\n" +
            formatCode($text) + "\n");
    }
    | l=logic_expression {
        $args.push_back($l.text);
        if($l.type!="")$types.push_back($l.type);
        writeIntoparserLogFile("Line " + to_string($l.start->getLine()) +
            ": arguments : logic_expression\n" + formatCode($text) + "\n");
    }
    ;


