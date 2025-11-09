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
    bool rel_assign=true;
    string show="";
    string label="";
    string last_true="";
    string last_false="";
    int paramOffset = 4;
    bool arr_assign = true;
    
    unordered_map<string, vector<string>> functionLocals;
    unordered_map<string, vector<pair<string, string>>> functionParams;
    unordered_map<string, string> variableToFunction; 
    unordered_map<string, int> labelLines;
    bool is_label=false;
    bool is_val=false;
    bool is_mul=false;
    bool is_andor=false;
    bool in_while= false;
    bool in_while2=false;
    bool in_inc=false;
    bool mul_add = false;
    bool code=true;
    bool three_code=false;
    void log_table() { 
    }

    bool is_digit(const string &s) {
    return !s.empty() && all_of(s.begin(), s.end(), ::isdigit);
}


    int labelCount = 0;
    int label_num=1;
    string generateLabel(string base) {
        return base + "L" + to_string(labelCount++);
    }
    string generateLabel() {
        is_label=true;
        return  "L" + to_string(label_num++);
    }
    void log(const string& message) {
    if (!parserLogFile) {
        cout << "Error opening parserLogFile.txt" << endl;
        return;
    }

    if (is_label) {
        parserLogFile << message << ":\n";
        is_label = false; // Reset after label
    } else {
        parserLogFile << "\t" << message << "\n";
    }

    parserLogFile.flush();
}

string toLowercase(const std::string& s) {
    std::string result = s;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c){ return std::tolower(c); });
    return result;
}

int getoffset(string varName) {
    Symbol_info* sym = symbolTable.look_up(varName);
    if (!sym) return -1;          

    if (sym->stack_offset <= 0) { 
        return -1;                
    }
    return sym->stack_offset;     
}


}

start
    : {
        log(".MODEL SMALL\n.STACK 1000H\n.DATA\n        number DB \"00000$\"");
        }p=program {
        
    } EOF {
        // log("END main");
    }
    ;

program
    :
    p1=program u=unit {
    }
    | u=unit {
    }
    ;

unit returns [int e]
    : vd=var_declaration {
        $e=$vd.start->getLine();
    }
    | fd_decl=func_declaration {
        $e=$fd_decl.start->getLine();

    }
    | fd_def=func_definition {
        $e=$fd_def.end;

    }
    ;

func_declaration
    : t=type_specifier id=ID LPAREN 
      {
        currentFunctionReturnType = $t.name;
        if (!symbolTable.insert($id.text, "ID")) {
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

      }

    | t=type_specifier id=ID LPAREN 
      {
        currentFunctionReturnType = $t.name;
        if (!symbolTable.insert($id.text, "ID")) {
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
      }
    ;


func_definition returns [int end]
    : t=type_specifier id=ID 
      {
         currentFunctionReturnType = $t.name;
         currentFunctionName = $id.text;

         Symbol_info* temp = symbolTable.look_up($id.text);
         if (temp) {
             temp->is_type = $t.name;
         }

        if(code) log(".CODE");
         code=false;

         log(currentFunctionName + " PROC");
         if(currentFunctionName == "main") log("MOV AX, @DATA\n\tMOV DS, AX");
         log("PUSH BP");
         log("MOV BP, SP");

         // Allocate local variables space here (after BP setup)
         int frameSize = functionLocals[currentFunctionName].size() * 2;
         if(frameSize > 0) {
             log("SUB SP, " + to_string(frameSize));
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
             temp1->p_count = $pl.count;
             temp1->param_types = $pl.params;
         }

         $end = $cs.endLine;
         enter_param = false;
         symbolTable.exit_scope();

         log("POP BP");
         if (currentFunctionName != "main") {
             log("RET");
         } else {
             log("MOV AX, 4CH");
             log("INT 21H");
         }
         log(currentFunctionName + " ENDP");
         currentFunctionName = "";
         
      }

    | t=type_specifier id=ID 
      {
         currentFunctionReturnType = $t.name;
         currentFunctionName = $id.text;

         Symbol_info* temp = symbolTable.look_up($id.text);
         if (temp) {
             temp->is_type = $t.name;
         }

         if(code) log(".CODE");
         code=false;

         log(currentFunctionName + " PROC");
          if(currentFunctionName == "main") log("MOV AX, @DATA\n\tMOV DS, AX");
         log("PUSH BP");
         log("MOV BP, SP");

         int frameSize = functionLocals[currentFunctionName].size() * 2;
         if(frameSize > 0) {
             log("SUB SP, " + to_string(frameSize));
         }
      }
      LPAREN 
      {
         symbolTable.enter_scope();  // No params this time
      }
      RPAREN 
      cs=compound_statement 
      {
         $end = $cs.endLine;
         symbolTable.exit_scope();


         log("POP BP");
         if (currentFunctionName != "main") {
             log("RET");
         } else {
             log("MOV AX, 4CH");
             log("INT 21H");
         }
         log(currentFunctionName + " ENDP");
         currentFunctionName = "";
      }
    ;


parameter_list returns [int count, vector<string> params]
    : pl=parameter_list COMMA ts=type_specifier id=ID {
        $count = $pl.count + 1;
        $params = $pl.params;
        $params.push_back($id->getText());

        if (enter_param) {
            if (!symbolTable.insert($id->getText(), "ID")) {
                // handle error if needed
            }
            Symbol_info* temp = symbolTable.look_up($id->getText());
            if (temp) {
                temp->is_type = $ts.name;
                // Use a global or parser-wide variable, not static here, to track offset
                temp->stack_offset = paramOffset;
                temp->global = false;
                temp->is_param = true;
                paramOffset += 2;
            }
        }
    }
    | pl=parameter_list COMMA ts=type_specifier {
        $count = $pl.count;
        $params = $pl.params;
    }
    | ts=type_specifier id=ID {
        $count = 1;
        $params.clear();  // Clear params to avoid appending to old list
        $params.push_back($id->getText());

        if (enter_param) {
            if (!symbolTable.insert($id->getText(), "ID")) {
                // handle error if needed
            }
            Symbol_info* temp = symbolTable.look_up($id->getText());
            if (temp) {
                temp->is_type = $ts.name;
                paramOffset = 4; // reset offset for first parameter on fresh call
                temp->stack_offset = paramOffset;
                temp->global = false;
                temp->is_param = true;
                paramOffset += 2;
            }
        }
    }
    | ts=type_specifier {
        $count = 0;
        $params.clear();
        paramOffset = 4;  // Reset offset when no params present
    }
;



compound_statement returns [int endLine]
    : LCURL statements  RCURL {
        $endLine = $RCURL->getLine();
    }
    | LCURL RCURL {
        $endLine = $RCURL->getLine();        
    }
    ;


var_declaration 
    : t=type_specifier dl=declaration_list sm=SEMICOLON {
        for (auto& name : $dl.names) {  
            bool isArray = false;
            string symbolName = name;
            string declarationLine;
            size_t bracketPos = symbolName.find('[');
            int arraySize = 0;

            // Check if it's an array declaration like w[5]
            if (bracketPos != string::npos) {
                isArray = true;
                string base = symbolName.substr(0, bracketPos);
                string sizeStr = symbolName.substr(bracketPos + 1);
                sizeStr.pop_back(); // remove ']'
                arraySize = stoi(sizeStr);
                declarationLine = base + " DW " + sizeStr + " DUP(0000H)";
                symbolName = base;  // remove [] for identifier name
            } else {
                declarationLine = symbolName + " DW 1 DUP(0000H)";
            }

            // Insert symbol in symbol table
            if (!symbolTable.insert(symbolName, "ID")) {
            } else {
                Symbol_info* temp = symbolTable.look_up(symbolName);
                if (temp) {
                    temp->is_array = isArray;
                    temp->is_type = $t.text;
                    temp->array_size = arraySize;
                }
            }

            // Local variable (inside a function)
            if (currentFunctionName != "") {
                functionLocals[currentFunctionName].push_back(symbolName);
                variableToFunction[symbolName] = currentFunctionName;

                // Static map to track offset per function
                static unordered_map<string, int> offsetBase;
                static unordered_map<string, int> offsetMap;

                if (offsetBase.find(currentFunctionName) == offsetBase.end()) {
                    offsetBase[currentFunctionName] = 2; 
                }

                int offset = offsetBase[currentFunctionName];

                // Set offset in map and symbol table
                offsetMap[symbolName] = offset;
                offsetBase[currentFunctionName] += (isArray ? 2 * arraySize : 2); 

                Symbol_info* temp = symbolTable.look_up(symbolName);
                if (temp) { 
                    temp->stack_offset = offset;
                    temp->global = false;

                    if (!temp->is_array) {
                        log("SUB SP, 2");
                    } else {
                        log("SUB SP, " + to_string(2 * arraySize));
                    }
                }
            }

            else {
                log("\t" + declarationLine);   
            }
        }
    }
;


type_specifier returns [string name]
    : INT {
        $name = "int";
        
    }
    | FLOAT {
        $name = "float";
       
    }
    | VOID {
        $name = "void";
    }
    ;

declaration_list
returns [vector<string> names]
    : dl=declaration_list COMMA idToken=ID LTHIRD CONST_INT RTHIRD {
        $names = $dl.names;
        $names.push_back($idToken->getText() + "[" + $CONST_INT->getText() + "]");
    }
    
    | dl=declaration_list COMMA idToken=ID {
        $names = $dl.names;
        $names.push_back($idToken.text);
    }
    | idToken=ID LTHIRD CONST_INT RTHIRD {
        $names.push_back($idToken->getText() + "[" + $CONST_INT->getText() + "]");
    }
    |idToken=ID op=ADDOP ID {
    $names.push_back($idToken.text);
    } 
     | idToken=ID {
        $names.push_back($idToken->getText());
    } 
       
    ;



statements
    : s1=statements s2=statement {
        
    }
    | s=statement {
        
    }
    ;




statement returns [int endLine]
    : {
        log(generateLabel());
        is_label=false;
        
    }
     

    v=var_declaration {
        $endLine = $v.stop->getLine();
    }

    | {
        log(generateLabel());
    }
    exprStmt=expression_statement {
        $endLine = $exprStmt.stop->getLine();
    }

    | {
        //log(generateLabel() + ":");
        symbolTable.enter_scope();
    } 
    c=compound_statement 
    {
        symbolTable.exit_scope();
        $endLine = $c.endLine; 
    }

    | {
        //log(generateLabel() + ":");
    }
    FOR LPAREN es1=expression_statement 
    {
        string startLabel = generateLabel("FOR_START");
        string continueLabel = generateLabel("FOR_CONTINUE");
        string endLabel = generateLabel("FOR_END");
        log(startLabel + ":");
    }
    es2=expression_statement 
    {
        log("JMP " + continueLabel);
        log(endLabel + ":");
        is_val=false;
    }
    ex3=expression RPAREN
    {
        log("JMP " + startLabel);
        log(continueLabel + ":");
    }
    s=statement {
        log("JMP " + endLabel);
        log($es2.falseLabel + ":");
        $endLine = $s.endLine;
    }

    | {
        //log(generateLabel() + ":");
    }
    IF LPAREN cond=expression 
    {
        
        log($cond.trueLabel + ":");
    }
    RPAREN {is_val=false;} thenStmt=statement ELSE 
    {
        is_val=false;
        log($cond.falseLabel + ":");
    }
    elseStmt=statement {
        is_val=false;
        $endLine = $elseStmt.endLine;
    }
    IF LPAREN cond=expression 
    {
        log($cond.trueLabel + ":");
    }
    RPAREN {is_val=false;} thenStmt=statement {
        is_val=false;
        log($cond.falseLabel + ":");
        $endLine = $thenStmt.endLine;
    }
    |WHILE 
    {
        string startLabel = generateLabel("WHILE_START");
        log(startLabel + ":");
        in_while=true;
    }
    LPAREN cond=expression 
    {   
        
        string check_Label = $cond.trueLabel;
        string endLabel = $cond.falseLabel;
        if(in_while && in_while2)log("JE "+endLabel);
        in_while=false;
        in_while=false;
        log(check_Label + ":");
    } 
    RPAREN {is_val=false;} loopStmt=statement 
    {
        log("JMP " + startLabel);
        log($cond.falseLabel + ":");
        
        $endLine = $loopStmt.endLine;
    }


    RETURN val=expression SEMICOLON {
        $endLine = $SEMICOLON->getLine();
            Symbol_info* sym = symbolTable.look_up($val.text);
            int offset = getoffset($val.text);
                if (offset == -1) {
                    log("MOV AX, " + $val.text);
                }
                else if (offset > 0) {
                    log("MOV AX, [BP+" + to_string(offset) + "]");
                }
                else {
                    log("MOV AX, [BP" + to_string(offset) + "]"); // offset is already negative
                }


    }

;



expression_statement returns [string trueLabel, string falseLabel]
    : s=SEMICOLON {
        $trueLabel = "";
        $falseLabel = "";
    }
    | e=expression s=SEMICOLON {
        $trueLabel = $e.trueLabel;
        $falseLabel = $e.falseLabel;
    }
    ;


variable returns [string text]
    : id=ID {
        $text = $id->getText();
        Symbol_info* temp = symbolTable.look_up($id->getText());

        // Only load value if NOT in left-hand side of assignment
        // if (temp && !arr_assign) {
        //     if (temp->global) {
        //         log("MOV AX, " + $id->getText());
        //     } else {
        //         int offset = temp->stack_offset;
        //         if (temp->is_param) {
        //             log("MOV AX, [BP+" + to_string(offset) + "]");
        //         } else {
        //             log("MOV AX, [BP-" + to_string(offset) + "]");
        //         }
        //     }
        // }
    }
    | id=ID LTHIRD e=expression RTHIRD {
    $text = $id->getText() + "[" + $e.text + "]";
    Symbol_info* temp = symbolTable.look_up($id->getText());

    if (temp && temp->is_array) {
        if (is_digit($e.text)) {
            log("MOV AX, " + $e.text);
             log("PUSH AX");
        } else {
            Symbol_info* indexSym = symbolTable.look_up($e.text);
            if (indexSym) {
                int offset = getoffset($e.text);
                if (indexSym->is_param)
                    log("MOV AX, [BP+" + to_string(offset) + "]");
                else
                    log("MOV AX, [BP-" + to_string(offset) + "]");
            } else {
                log("MOV AX, " + $e.text); // fallback
            }
        }
        
        // log("SHL AX, 1");
        arr_assign=true;
        // cout<<"koi2";
    }
}

    ;




    expression returns [string trueLabel, string falseLabel]
    : l=logic_expression {
        $trueLabel = $l.trueLabel;
        $falseLabel = $l.falseLabel;
    }
    | v=variable op=ASSIGNOP {in_inc=true;} l=logic_expression {
        // Transfer true/false labels for logical expressions
        $trueLabel = $l.trueLabel;
        $falseLabel = $l.falseLabel;
        
        string lhs = $v.text;
        string rhs = $l.text;

        // Remove array indexing from lhs if any, keep base name only
        size_t bracketPos = lhs.find('[');
        if (bracketPos != string::npos) {
            lhs = lhs.substr(0, bracketPos);
        }
        size_t bracketPos2 = rhs.find('[');
        if (bracketPos2 != string::npos) {
            rhs = rhs.substr(0, bracketPos2);
        }

        Symbol_info* var1 = symbolTable.look_up(lhs);
        Symbol_info* var2 = symbolTable.look_up(rhs);

        int lhsoff = getoffset(lhs);
        int rhsoff = getoffset(rhs);
        bool already = false;

        if (var2 && var2->is_array) {
            if (var2->global) {
                log("POP BX");
                log("SHL BX, 1");

                log("MOV AX, " + rhs + "["+ "BX]");
                if(var1 && !var1->is_array){
                if(var1->global)log("MOV "+lhs+", AX");
                else log("MOV [BP-" + to_string(lhsoff) + "], AX");
                }
            } else {
                log("POP BX");
                log("SHL BX, 1");
                int full_offset= 2*var2->array_size+2;
                log("MOV AX, "+ to_string(full_offset));
                log("SUB AX, BX");
                log("MOV BX, AX");
                log("POP AX");
                if(!in_inc)log("MOV CX, AX");
                log("MOV SI, BX\n\tNEG SI");
                log("MOV AX, [BP+SI]");
                if(var1 && !var1->is_array){
                if(var1 && var1->global)log("MOV "+lhs+", AX");
                else log("MOV [BP-" + to_string(lhsoff) + "], AX");
                }
            }
            already=true;
        }

        if (var1 && var1->is_array) {
            cout << "koi"; 
            if(!var2) log("PUSH AX");
            if (var1->global) {
                if(!var2)log("POP AX");
                log("POP BX");
                log("SHL BX, 1");

                log("MOV " + lhs + "["+ "BX], AX");
            } else {
                int offset = var1->stack_offset;
                log("POP BX");
                log("SHL BX, 1");
                int full_offset= 2*var2->array_size+2;
                log("MOV AX, "+ to_string(full_offset));
                log("SUB AX, BX");
                log("MOV BX, AX");
                log("POP AX");
                log("MOV SI, BX\n\tNEG SI");
                if(!in_inc)log("MOV CX, AX");
                log("MOV [BP+SI], AX");
            }
            already=true;
        }


        if (is_val && !already && var1) {
            if (var1->global) {
                log("MOV " + lhs + ", 1");
            } else {
                if (is_andor) log($l.trueLabel + ":");
                log("MOV AX, 1");
                if (var1->is_param)
                    log("MOV [BP+" + to_string(lhsoff) + "], AX");
                else
                    log("MOV [BP-" + to_string(lhsoff) + "], AX");
            }
            is_andor = false;

            log("JMP L" + to_string(label_num));
            log($l.falseLabel + ":");

            if (var1->global) {
                log("MOV " + lhs + ", 0");
            } else {
                log("MOV AX, 0");
                if (var1->is_param)
                    log("MOV [BP+" + to_string(lhsoff) + "], AX");
                else {
                    log("MOV [BP-" + to_string(lhsoff) + "], AX");
                    already = true;
                }
            }
        }
        is_val = false;

        if (var1 && !var1->global && !var2 && is_digit(rhs) && !already) {
            log("MOV AX, " + rhs);
            if (var1->is_param)
                log("MOV [BP+" + to_string(lhsoff) + "], AX");
            else
                log("MOV [BP-" + to_string(lhsoff) + "], AX");
            already = true;
        }

        if (var1 && var1->global && !var2 && is_digit(rhs) && !already) {
            log("MOV " + lhs + ", " + rhs);
            already = true;
        }

        if (var2 && var1 && !already) {
            if (var1->global && !var2->global && !var2->is_array) {
                if (var2->is_param)
                    log("MOV AX, [BP+" + to_string(rhsoff) + "]");
                else
                    log("MOV AX, [BP-" + to_string(rhsoff) + "]");
                log("MOV " + lhs + ", AX");
            }
            else if (!var1->global && !var2->global) {
                if (var2->is_param)
                    log("MOV AX, [BP+" + to_string(rhsoff) + "]");
                else
                    log("MOV AX, [BP-" + to_string(rhsoff) + "]");
                if (var1->is_param)
                    log("MOV [BP+" + to_string(lhsoff) + "], AX");
                else
                    log("MOV [BP-" + to_string(lhsoff) + "], AX");
            }
            else if (var1->global && var2->global) {
                log("MOV AX, " + rhs);
                log("MOV " + lhs + ", AX");
            }
            else if (!var1->global && var2->global) {
                log("MOV AX, " + rhs);
                if (var1->is_param)
                    log("MOV [BP+" + to_string(lhsoff) + "], AX");
                else
                    log("MOV [BP-" + to_string(lhsoff) + "], AX");
            }
            already = true;
        }

        // Case: result is in AX, assign to lhs
        if (var1 && !var2 && !already) {
            if (var1->global)
                log("MOV " + lhs + ", AX");
            else {
                if (var1->is_param)
                    log("MOV [BP+" + to_string(lhsoff) + "], AX");
                else
                    log("MOV [BP-" + to_string(lhsoff) + "], AX");
            }
        }
    }
    ;

logic_expression returns [string type, string trueLabel, string falseLabel]
    : r=rel_expression {
        $type = $r.type;
        $trueLabel = $r.trueLabel;
        $falseLabel = $r.falseLabel;
    }
    | r1=rel_expression op=LOGICOP r2=rel_expression {
        if ($r1.type == "float" || $r2.type == "float") $type = "float";
        else $type = "int";

        is_andor = true;
        $trueLabel = generateLabel("LOGIC_TRUE");
        $falseLabel = generateLabel("LOGIC_FALSE");

        string rhs1 = $r1.text;
        Symbol_info *rh1 = symbolTable.look_up(rhs1);
        if (rh1) {
            int offset1 = getoffset(rhs1);
            if (offset1 < 0) log("MOV AX, " + rhs1);
            else {
                if(rh1->is_param)
                    log("MOV AX, [BP+" + to_string(offset1) + "]");
                else
                    log("MOV AX, [BP-" + to_string(offset1) + "]");
            }
            log("CMP AX, 0");

            if ($op.text == "&&") log("JE " + $falseLabel);
            else if ($op.text == "||") log("JNE " + $trueLabel);
        } else {
            if ($op.text == "&&") {
                log($r1.falseLabel + ":");
                log("JMP " + $falseLabel);
            }
            if ($op.text == "||") {
                log("JMP " + $trueLabel);
                log($r1.falseLabel + ":");
            }
        }

        string rhs2 = $r2.text;
        Symbol_info *rh2 = symbolTable.look_up(rhs2);
        if (rh2) {
            int offset2 = getoffset(rhs2);
            if (offset2 < 0) log("MOV AX, " + rhs2);
            else {
                if(rh2->is_param)
                    log("MOV AX, [BP+" + to_string(offset2) + "]");
                else
                    log("MOV AX, [BP-" + to_string(offset2) + "]");
            }
            log("CMP AX, 0");

            if ($op.text == "&&") {
                log("JE " + $falseLabel);
                log("JMP " + $trueLabel);
            } else if ($op.text == "||") {
                log("JNE " + $trueLabel);
                log("JMP " + $falseLabel);
            }
        } else {
            if ($op.text == "&&") {
                log("JMP " + $trueLabel);
                log($r2.falseLabel + ":");
                log("JMP " + $falseLabel);
            } else if ($op.text == "||") {
                log("JMP " + $trueLabel);
                log($r2.falseLabel + ":");
                log("JMP " + $falseLabel);
            }
        }
        is_val = true;
    }
    ;

rel_expression returns [string type, string trueLabel, string falseLabel]
    : s=simple_expression {
        $type = $s.type;
        $trueLabel = generateLabel("REL_TRUE");
        $falseLabel = generateLabel("REL_FALSE");
        
        
    }
    | s1=simple_expression op=RELOP s2=simple_expression {
        if ($s1.type == "float" || $s2.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        
        string left = $s1.text;
        string right = $s2.text;
        int leftOffset = getoffset(left);
        int rightOffset = getoffset(right);

        $trueLabel = generateLabel("REL_TRUE");
        $falseLabel = generateLabel("REL_FALSE");

        // MOV AX, left
        if (leftOffset < 0) {
            log("MOV AX, " + left);
        } else {
            if(symbolTable.look_up(left)->is_param)
                log("MOV AX, [BP+" + to_string(leftOffset) + "]");
            else
                log("MOV AX, [BP-" + to_string(leftOffset) + "]");
        }

        // CMP AX, right
        if (rightOffset < 0) {
            log("CMP AX, " + right);
        } else {
            if(symbolTable.look_up(right)->is_param)
                log("CMP AX, [BP+" + to_string(rightOffset) + "]");
            else
                log("CMP AX, [BP-" + to_string(rightOffset) + "]");
        }

        // Use reversed condition for better fall-through
        if ($op.text == "<") {
            log("JGE " + $falseLabel);
        } else if ($op.text == "<=") {
            log("JG " + $falseLabel);
        } else if ($op.text == ">") {
            log("JLE " + $falseLabel);
        } else if ($op.text == ">=") {
            log("JL " + $falseLabel);
        } else if ($op.text == "==") {
            log("JNE " + $falseLabel);
        } else if ($op.text == "!=") {
            log("JE " + $falseLabel);
        }
        is_val=true;
    }
    ;

    simple_expression returns [string type]
        : t=term {
            $type = $t.type;
        }
        | s=simple_expression op=ADDOP ap=ASSIGNOP t=term {
            if ($s.type == "float" || $t.type == "float") {
                $type = "float";
            } else {
                $type = "int";
            }
        }
    | s=simple_expression op=ADDOP {mul_add=true;} t=term {
        if ($s.type == "float" || $t.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }
        string left = $s.text;
        string right = $t.text;

        bool isLeftConst = is_digit(left);
        bool isRightConst = is_digit(right);

        Symbol_info* varLeft = symbolTable.look_up(left);
        Symbol_info* varRight = symbolTable.look_up(right);

        int leftOffset = getoffset(left);
        int rightOffset = getoffset(right);
        
        if (is_mul) {
            if(varLeft){
                log("POP DX");
                if(varLeft->global)log("MOV AX,"+left);
                else {
                    log("MOV AX, [BP-" + to_string(leftOffset) + "]"); 
                }
            }
            if(!varLeft && !varRight){
                if(!is_digit(left)){
                log("POP DX");
                log("POP AX");
                }
                else { 
                    log("POP AX");
                    log("ADD AX, "+left);
                }
            }

                if ($op->getText() == "+") {
                    log("ADD AX, DX");
                } else if ($op->getText() == "-") {
                    log("SUB AX, DX");
                }
                is_mul = false;


        }

        if ((varLeft || isLeftConst) && (varRight || isRightConst)) {

            

            if (isLeftConst) {
                log("MOV AX, " + left);
            } else if (varLeft && varLeft->global) {
                log("MOV AX, " + left);
            } else if (varLeft) {
                if (varLeft->is_param)
                    log("MOV AX, [BP+" + to_string(leftOffset) + "]");
                else
                    log("MOV AX, [BP-" + to_string(leftOffset) + "]");
            } else {
                log("MOV AX, " + left);
            }

                if ($op->getText() == "+") {
                    if (isRightConst) {
                        log("ADD AX, " + right);
                    } else if (varRight && varRight->global) {
                        log("ADD AX, " + right);
                    } else if (varRight) {
                        if (varRight->is_param)
                            log("ADD AX, [BP+" + to_string(rightOffset) + "]");
                        else
                            log("ADD AX, [BP-" + to_string(rightOffset) + "]");
                    } else {
                        log("ADD AX, " + right);
                    }
                } else if ($op->getText() == "-") {
                    if (isRightConst) {
                        log("SUB AX, " + right);
                    } else if (varRight && varRight->global) {
                        log("SUB AX, " + right);
                    } else if (varRight) {
                        if (varRight->is_param)
                            log("SUB AX, [BP+" + to_string(rightOffset) + "]");
                        else
                            log("SUB AX, [BP-" + to_string(rightOffset) + "]");
                    } else {
                        log("SUB AX, " + right);
                    }
                }
        }  
        log("PUSH AX");
    }
    ;


term returns [string type]
    : u=unary_expression {
        $type = $u.type;
    }
    | t=term op=MULOP {is_mul = true;} u=unary_expression {
        if ($t.type == "float" || $u.type == "float") {
            $type = "float";
        } else {
            $type = "int";
        }

        string left = $t.text;
        string right = $u.text;

        Symbol_info *lhs = symbolTable.look_up(left);
        Symbol_info *rhs = symbolTable.look_up(right);

        int leftOffset = getoffset(left);
        int rightOffset = getoffset(right);

        if (is_digit(left) && !is_digit(right) && !rhs) {
            log("MOV CX, AX");
            log("MOV AX, " + left);
            log("CWD");
            log("MUL CX");
            log("PUSH AX");
        }
        else if (!is_digit(left) && !lhs && is_digit(right)) {
            log("MOV CX, AX");
            log("MOV AX, " + right);
            log("CWD");
            log("MUL CX");
            log("PUSH AX");
        }

        else if ((lhs || is_digit(left)) && (rhs || is_digit(right))) {
            if ($op->getText() == "*") {
                if (leftOffset < 0) {
                    log("MOV AX, " + left);
                } else {
                    if (lhs->is_param)
                        log("MOV AX, [BP+" + to_string(leftOffset) + "]");
                    else
                        log("MOV AX, [BP-" + to_string(leftOffset) + "]");
                }

                if (rightOffset < 0) {
                    log("MOV CX, " + right);
                } else {
                    if (rhs->is_param)
                        log("MOV CX, [BP+" + to_string(rightOffset) + "]");
                    else
                        log("MOV CX, [BP-" + to_string(rightOffset) + "]");
                }

                log("CWD");
                log("MUL CX");
                log("PUSH AX");
            }
            else if ($op->getText() == "/") {
                if (rightOffset < 0) {
                    log("MOV CX, " + right);
                } else {
                    if (rhs->is_param)
                        log("MOV CX, [BP+" + to_string(rightOffset) + "]");
                    else
                        log("MOV CX, [BP-" + to_string(rightOffset) + "]");
                }

                if (leftOffset < 0) {
                    log("MOV AX, " + left);
                } else {
                    if (lhs->is_param)
                        log("MOV AX, [BP+" + to_string(leftOffset) + "]");
                    else
                        log("MOV AX, [BP-" + to_string(leftOffset) + "]");
                }

                log("CWD");
                log("DIV CX");
            }
            else if ($op->getText() == "%") {
                if (leftOffset < 0) {
                    log("MOV AX, " + left);
                } else {
                    if (lhs->is_param)
                        log("MOV AX, [BP+" + to_string(leftOffset) + "]");
                    else
                        log("MOV AX, [BP-" + to_string(leftOffset) + "]");
                }

                if (rightOffset < 0) {
                    log("MOV CX, " + right);
                } else {
                    if (rhs->is_param)
                        log("MOV CX, [BP+" + to_string(rightOffset) + "]");
                    else
                        log("MOV CX, [BP-" + to_string(rightOffset) + "]");
                }

                log("CWD");
                log("DIV CX");
                log("MOV AX, DX");
            }
        }
    }
;





unary_expression returns [string type]
    :op=ADDOP u=unary_expression {
    $type = $u.type;
    Symbol_info* sym = symbolTable.look_up($u.text);

    if (sym) {
        if (sym->is_array) {
        } else if (sym->global) {
            log("MOV AX, " + $u.text);
        } else {
            int offset = sym->stack_offset;
            if (sym->is_param) {
                log("MOV AX, [BP+" + to_string(offset) + "]");
            } else {
                log("MOV AX, [BP-" + to_string(offset) + "]");
            }
        }
    } else if (isdigit($u.text[0])) {
        // handle constant values like 5, 10, etc.
        log("MOV AX, " + $u.text);
    } 

    if ($op.text == "-") {
        log("NEG AX");
    }
}


    | n=NOT u=unary_expression {
        $type=$u.type;

    }
    | f=factor {
        $type=$f.type;

    }
    ;

factor returns [string type]
    : v=variable {
        $type = "";
    }
    | id=ID LPAREN a=argument_list RPAREN {
        $type = "";

        if (toLowercase($id.text) == "println") {
            // println handling (looks correct)
            for (auto& arg : $a.args) {
                Symbol_info* symbol = symbolTable.look_up(arg);
                if (symbol) {
                    if (symbol->global) {
                        log("MOV AX, " + arg);
                    } else if (symbol->is_param) {
                        log("MOV AX, [BP+" + to_string(symbol->stack_offset) + "]");
                    } else {
                        log("MOV AX, [BP-" + to_string(symbol->stack_offset) + "]");
                    }
                    log("CALL print_output");
                } else {
                    log("MOV AX, " + arg);
                    log("CALL print_output");
                }
            }
            log("CALL new_line");
        } else {
            // Regular function call - FIXED VERSION
            
            for (int i = (int)$a.args.size() - 1; i >= 0; --i) {
                Symbol_info* argSym = symbolTable.look_up($a.args[i]);
                if (argSym) {
                    if (argSym->global) {
                        log("PUSH " + $a.args[i]);
                    } else if (argSym->is_param) {
                        log("PUSH [BP+" + to_string(argSym->stack_offset) + "]");
                    } else {
                        log("PUSH [BP-" + to_string(argSym->stack_offset) + "]");
                    }
                } else {
                    log("PUSH " + $a.args[i]);
                }
            }
            
            // Call the function
            log("CALL " + $id.text);
            
            // Clean up stack (remove pushed arguments)
            if ($a.args.size() > 0) {
                log("ADD SP, " + to_string(2 * $a.args.size()));
            }
        }
    }



    | LPAREN e=expression RPAREN {
        $type="";

    }
    | ci=CONST_INT {
        $type="int";
    }
    | cf=CONST_FLOAT {
        $type="float";
    }
    | v=variable INCOP {
        $type = "";

        
        string lhs = $v.text;

        

        size_t bracketPos = lhs.find('[');
        if (bracketPos != string::npos) {
            lhs = lhs.substr(0, bracketPos);
        }
        Symbol_info* var = symbolTable.look_up(lhs);
        int offset = getoffset(lhs);

        if (var) {
            if (var->global) {
                if(!var->is_array)log("INC " + lhs);
                else {if(in_inc)log("INC AX\n\tMOV CX, AX");}
            } else {
                if(in_inc && var->is_array)log("INC AX");
                else {
                log("MOV AX, [BP-" + to_string(offset) + "]");
                log("INC AX");
                log("MOV [BP-" + to_string(offset) + "], AX");
            }
            }
        }
        in_inc=false;
    }
    | v=variable DECOP {
        $type = "";

        Symbol_info* var = symbolTable.look_up($v.text);
        string varName = $v.text;
        int offset = getoffset(varName);

        if (var) {
            if (var->global) {
                log("DEC " + varName);
            } else {
                log("MOV AX, [BP-" + to_string(offset) + "]");
                // log("PUSH AX");
                log("DEC AX");
                log("MOV [BP-" + to_string(offset) + "], AX");
                // log("POP AX");
                if(in_while){
                    in_while2=true;

                    log("CMP AX, 0");
                }
            }
        }
    }
    ;
argument_list returns [vector<string> args, vector<string> types]
    : a=arguments {
        $args = $a.args;
        $types = $a.types;
    }
    |  {
        $args.clear();
        $types.clear();
    }
    ;

arguments returns [vector<string> args, vector<string> types]
    : a=arguments COMMA l=logic_expression {
        $args = $a.args;
        $types = $a.types;
        $args.push_back($l.text);
        if ($l.type != "") $types.push_back($l.type);
    }
    | l=logic_expression {
        $args.clear();
        $types.clear();
        $args.push_back($l.text);
        if ($l.type != "") $types.push_back($l.type);
    }
    ;


