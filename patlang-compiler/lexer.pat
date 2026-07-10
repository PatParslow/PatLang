# PatLang Compiler Frontend - Lexer
# Written in PatLang for self-hosting
# Expectation-driven lexer with parser feedback loop

import "token.pat"

make a class called Lexer {
    takes: source
    returns: {
        source is source
        position is 0
        line is 1
        column is 1
        current_char is nil
        # Context tracking for disambiguation
        in_declaration_article_expected is false
        in_parameter_list is false
        in_lambda_params is false
        in_event_spec is false
        expectations is nil
        
        # Initialize
        advance()
    }
    
    # Main entry point - tokenize with optional expectations
    make a function called tokenize {
        takes: expectations_override
        expectations_override is nil
        returns: {
            tokens is []
            # Reset position for fresh tokenize
            position is 0
            line is 1
            column is 1
            advance()
            
            while not at_end() {
                token is next_token(expectations: expectations_override)
                if token.type != TokenType::NEWLINE {
                    tokens.append(token)
                }
                if token.type == TokenType::EOF {
                    break
                }
            }
            tokens.append(Token(TokenType::EOF, "", line, column))
            tokens
        }
    }
    
    # Expectation-driven next token (for parser feedback loop)
    make a function called next_token {
        takes: expectations
        expectations is nil
        returns: {
            # Set expectations for this tokenization
            saved_expectations is expectations
            @expectations is expectations
            
            skip_whitespace()
            
            if at_end() {
                return make_eof_token()
            }
            
            char is current_char
            
            # Handle newlines
            if char == "\n" {
                advance()
                return Token(TokenType::NEWLINE, "\n", line, column - 1)
            }
            
            # Handle identifiers and keywords
            if is_alpha(char) or char == "_" {
                return read_identifier()
            }
            
            # Handle numbers
            if is_digit(char) {
                return read_number()
            }
            
            # Handle strings
            if char == "\"" {
                return read_string()
            }
            
            # Handle operators and punctuation
            return read_operator()
        }
    }
    
    # Advance to next character
    make a function called advance {
        if position >= source.length {
            current_char is nil
        } else {
            current_char is source[position]
            position is position + 1
            if current_char == "\n" {
                line is line + 1
                column is 1
            } else {
                column is column + 1
            }
        }
    }
    
    # Peek at next character without consuming
    make a function called peek {
        if position >= source.length {
            nil
        } else {
            source[position]
        }
    }
    
    # Check if at end of input
    make a function called at_end {
        position >= source.length or current_char is nil
    }
    
    # Skip whitespace (but not newlines)
    make a function called skip_whitespace {
        while not at_end() and current_char != "\n" and (current_char == " " or current_char == "\t" or current_char == "\r") {
            advance()
        }
    }
    
    # Make EOF token
    make a function called make_eof_token {
        Token(TokenType::EOF, "", line, column)
    }
    
    # Read identifier or keyword
    make a function called read_identifier {
        start_line is line
        start_col is column
        value is ""
        
        while not at_end() and (is_alpha(current_char) or is_digit(current_char) or current_char == "_") {
            value is value + current_char
            advance()
        }
        
        # Check for keywords with context sensitivity
        token_type is classify_identifier(value)
        
        # Handle context-sensitive disambiguation
        if token_type == TokenType::ARTICLE and not in_declaration_article_expected {
            token_type is TokenType::IDENTIFIER
        }
        
        if token_type == TokenType::COLON and in_event_spec {
            # Colon in event spec context already handled
        }
        
        Token(token_type, value, start_line, start_col)
    }
    
    # Classify identifier - maps string to token type
    make a function called classify_identifier {
        takes: value
        returns: {
            # Articles
            if value == "a" or value == "an" {
                TokenType::ARTICLE
            }
            
            # Declaration keywords
            else if value == "make" {
                in_declaration_article_expected is true
                TokenType::MAKE_KEYWORD
            }
            else if value == "function" {
                TokenType::FUNCTION_KW
            }
            else if value == "class" {
                TokenType::CLASS_KW
            }
            else if value == "template" {
                TokenType::TEMPLATE_KW
            }
            else if value == "goal" {
                TokenType::GOAL_KW
            }
            else if value == "list" {
                TokenType::LIST_KW
            }
            else if value == "number" or value == "text" or value == "boolean" {
                TokenType::TYPE_KW
            }
            else if value == "called" {
                in_declaration_article_expected is false
                TokenType::CALLED
            }
            else if value == "takes" {
                in_parameter_list is true
                TokenType::TAKES_KEYWORD
            }
            else if value == "returns" {
                TokenType::RETURNS_KEYWORD
            }
            else if value == "requires" {
                TokenType::REQUIRES_KEYWORD
            }
            else if value == "ensures" {
                TokenType::ENSURES_KEYWORD
            }
            else if value == "inherits" {
                TokenType::INHERITS_KEYWORD
            }
            else if value == "has" {
                TokenType::HAS_KEYWORD
            }
            else if value == "maintains" {
                TokenType::MAINTAINS_KEYWORD
            }
            
            # Control flow
            else if value == "if" {
                TokenType::IF_KW
            }
            else if value == "then" {
                TokenType::THEN_KEYWORD
            }
            else if value == "elsif" {
                TokenType::ELSIF_KEYWORD
            }
            else if value == "else" {
                TokenType::ELSE_KEYWORD
            }
            else if value == "end" {
                TokenType::END_KEYWORD
            }
            else if value == "when" {
                in_event_spec is true
                TokenType::WHEN_KEYWORD
            }
            else if value == "do" {
                TokenType::DO_KEYWORD
            }
            else if value == "while" {
                TokenType::WHILE_KEYWORD
            }
            else if value == "for" {
                TokenType::FOR_KW
            }
            else if value == "in" {
                TokenType::IN_KEYWORD
            }
            else if value == "range" {
                TokenType::RANGE_KEYWORD
            }
            else if value == "import" {
                TokenType::IMPORT_KEYWORD
            }
            
            # Assignment
            else if value == "is" {
                # Check for "is not" - peek ahead
                if peek_identifier_starts_with("not") {
                    advance_to_skip("is")
                    advance_to_skip("not")
                    TokenType::IS_NOT_KEYWORD
                } else {
                    TokenType::IS_KEYWORD
                }
            }
            else if value == "becomes" {
                TokenType::BECOMES_KEYWORD
            }
            
            # Other statements
            else if value == "return" {
                TokenType::RETURN_KEYWORD
            }
            else if value == "activate" {
                TokenType::ACTIVATE_KEYWORD
            }
            else if value == "with" {
                TokenType::WITH_KEYWORD
            }
            else if value == "query" {
                TokenType::QUERY_KEYWORD
            }
            else if value == "assert" {
                TokenType::ASSERT_KEYWORD
            }
            
            # Logic
            else if value == "and" {
                TokenType::AND_KEYWORD
            }
            else if value == "or" {
                TokenType::OR_KEYWORD
            }
            else if value == "not" {
                TokenType::NOT_KEYWORD
            }
            else if value == "true" {
                TokenType::TRUE_KEYWORD
            }
            else if value == "false" {
                TokenType::FALSE_KEYWORD
            }
            else if value == "nil" {
                TokenType::NIL_KEYWORD
            }
            
            # Event actions
            else if value == "called" {
                TokenType::CALLED
            }
            else if value == "completed" {
                TokenType::COMPLETED
            }
            else if value == "error" {
                TokenType::ERROR_KEYWORD
            }
            else if value == "changed" {
                TokenType::CHANGED
            }
            else if value == "activated" {
                TokenType::ACTIVATED
            }
            
            # Default: identifier
            else {
                TokenType::IDENTIFIER
            }
        }
    }
    
    # Check if next identifier starts with given string
    make a function called peek_identifier_starts_with {
        takes: prefix
        save_pos is position
        save_line is line
        save_col is column
        save_char is current_char
        
        # Skip whitespace
        while not at_end() and (current_char == " " or current_char == "\t") {
            advance()
        }
        
        result is false
        if not at_end() and is_alpha(current_char) {
            ident is ""
            while not at_end() and (is_alpha(current_char) or is_digit(current_char) or current_char == "_") {
                ident is ident + current_char
                advance()
            }
            if ident.starts_with(prefix) {
                result is true
            }
        }
        
        # Restore position
        position is save_pos
        line is save_line
        column is save_col
        current_char is save_char
        
        result
    }
    
    # Advance to skip a specific identifier
    make a function called advance_to_skip {
        takes: expected
        word is ""
        while not at_end() and (is_alpha(current_char) or is_digit(current_char) or current_char == "_") {
            word is word + current_char
            advance()
        }
    }
    
    # Read number (integer or float)
    make a function called read_number {
        start_line is line
        start_col is column
        value is ""
        is_float is false
        
        while not at_end() and is_digit(current_char) {
            value is value + current_char
            advance()
        }
        
        if not at_end() and current_char == "." and peek() != "." {
            is_float is true
            value is value + "."
            advance()
            while not at_end() and is_digit(current_char) {
                value is value + current_char
                advance()
            }
        }
        
        if is_float {
            Token(TokenType::FLOAT_LITERAL, value.to_float(), start_line, start_col)
        } else {
            Token(TokenType::INTEGER_LITERAL, value.to_int(), start_line, start_col)
        }
    }
    
    # Read string literal
    make a function called read_string {
        start_line is line
        start_col is column
        advance()  # Skip opening quote
        value is ""
        
        while not at_end() and current_char != "\"" {
            if current_char == "\\" {
                advance()
                if not at_end() {
                    escaped is escape_char(current_char)
                    value is value + escaped
                    advance()
                }
            } else {
                value is value + current_char
                advance()
            }
        }
        
        if at_end() {
            raise(LexerError("Unterminated string literal"))
        }
        
        advance()  # Skip closing quote
        Token(TokenType::STRING_LITERAL, value, start_line, start_col)
    }
    
    # Handle escape sequences
    make a function called escape_char {
        takes: char
        returns: {
            if char == "n" {"\n"}
            else if char == "t" {"\t"}
            else if char == "r" {"\r"}
            else if char == "\\" {"\\"}
            else if char == "\"" {"\""}
            else {char}
        }
    }
    
    # Read operators and punctuation
    make a function called read_operator {
        start_line is line
        start_col is column
        char is current_char
        next_c is peek()
        
        # Two-character operators
        if char == "=" and next_c == "=" {
            advance()
            advance()
            Token(TokenType::EQ, "==", start_line, start_col)
        }
        else if char == "!" and next_c == "=" {
            advance()
            advance()
            Token(TokenType::NEQ, "!=", start_line, start_col)
        }
        else if char == "<" and next_c == "=" {
            advance()
            advance()
            Token(TokenType::LTE, "<=", start_line, start_col)
        }
        else if char == ">" and next_c == "=" {
            advance()
            advance()
            Token(TokenType::GTE, ">=", start_line, start_col)
        }
        else if char == "-" and next_c == ">" {
            advance()
            advance()
            Token(TokenType::ARROW, "=>", start_line, start_col)
        }
        else if char == "|" and next_c == "|" {
            advance()
            advance()
            Token(TokenType::PIPE, "||", start_line, start_col)
        }
        # Single-character operators and punctuation
        else if char == "+" {
            advance()
            Token(TokenType::PLUS, "+", start_line, start_col)
        }
        else if char == "-" {
            advance()
            Token(TokenType::MINUS, "-", start_line, start_col)
        }
        else if char == "*" {
            advance()
            Token(TokenType::STAR, "*", start_line, start_col)
        }
        else if char == "/" {
            advance()
            Token(TokenType::SLASH, "/", start_line, start_col)
        }
        else if char == "%" {
            advance()
            Token(TokenType::PERCENT, "%", start_line, start_col)
        }
        else if char == "<" {
            advance()
            Token(TokenType::LT, "<", start_line, start_col)
        }
        else if char == ">" {
            advance()
            Token(TokenType::GT, ">", start_line, start_col)
        }
        else if char == ":" {
            advance()
            if in_event_spec {
                in_event_spec is false
                Token(TokenType::COLON, ":", start_line, start_col)
            } else {
                Token(TokenType::COLON, ":", start_line, start_col)
            }
        }
        else if char == "," {
            advance()
            # In parameter list, '|' might appear
            if in_parameter_list and peek() == "|" {
                # Will be handled next iteration
            }
            Token(TokenType::COMMA, ",", start_line, start_col)
        }
        else if char == ";" {
            advance()
            Token(TokenType::SEMICOLON, ";", start_line, start_col)
        }
        else if char == "." {
            advance()
            Token(TokenType::DOT, ".", start_line, start_col)
        }
        else if char == "(" {
            advance()
            Token(TokenType::LPAREN, "(", start_line, start_col)
        }
        else if char == ")" {
            advance()
            Token(TokenType::RPAREN, ")", start_line, start_col)
        }
        else if char == "[" {
            advance()
            Token(TokenType::LBRACKET, "[", start_line, start_col)
        }
        else if char == "]" {
            advance()
            Token(TokenType::RBRACKET, "]", start_line, start_col)
        }
        else if char == "{" {
            advance()
            Token(TokenType::BLOCK_START, "{", start_line, start_col)
        }
        else if char == "}" {
            advance()
            # Reset parameter list context on block end
            in_parameter_list is false
            in_lambda_params is false
            Token(TokenType::BLOCK_END, "}", start_line, start_col)
        }
        else if char == "|" {
            advance()
            if not in_lambda_params {
                in_lambda_params is true
                Token(TokenType::BLOCK_PARAM_START, "|", start_line, start_col)
            } else {
                in_lambda_params is false
                Token(TokenType::BLOCK_PARAM_END, "|", start_line, start_col)
            }
        }
        else {
            raise(LexerError("Unexpected character: " + char))
        }
    }
    
    # Character classification
    make a function called is_alpha {
        takes: char
        char >= "a" and char <= "z" or char >= "A" and char <= "Z"
    }
    
    make a function called is_digit {
        takes: char
        char >= "0" and char <= "9"
    }
}