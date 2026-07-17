# PatLang Compiler Frontend - Token Types
# Written in PatLang for self-hosting

# Token types as a module
make a module called TokenType {
    # Literals
    INTEGER_LITERAL is :INTEGER_LITERAL
    FLOAT_LITERAL is :FLOAT_LITERAL
    STRING_LITERAL is :STRING_LITERAL
    TRUE_KEYWORD is :TRUE_KEYWORD
    FALSE_KEYWORD is :FALSE_KEYWORD
    NIL_KEYWORD is :NIL_KEYWORD
    
    # Identifiers and operators
    IDENTIFIER is :IDENTIFIER
    ARTICLE is :ARTICLE
    
    # Keywords - declarations
    MAKE_KEYWORD is :MAKE_KEYWORD
    FUNCTION_KW is :FUNCTION_KW
    CLASS_KW is :CLASS_KW
    TEMPLATE_KW is :TEMPLATE_KW
    GOAL_KW is :GOAL_KW
    LIST_KW is :LIST_KW
    TYPE_KW is :TYPE_KW
    DECL_TYPE is :DECL_TYPE
    CALLED is :CALLED
    TAKES_KEYWORD is :TAKES_KEYWORD
    RETURNS_KEYWORD is :RETURNS_KEYWORD
    REQUIRES_KEYWORD is :REQUIRES_KEYWORD
    ENSURES_KEYWORD is :ENSURES_KEYWORD
    INHERITS_KEYWORD is :INHERITS_KEYWORD
    HAS_KEYWORD is :HAS_KEYWORD
    MAINTAINS_KEYWORD is :MAINTAINS_KEYWORD
    
    # Keywords - control flow
    IF_KW is :IF_KW
    THEN_KEYWORD is :THEN_KEYWORD
    ELSIF_KEYWORD is :ELSIF_KEYWORD
    ELSE_KEYWORD is :ELSE_KEYWORD
    END_KEYWORD is :END_KEYWORD
    WHEN_KEYWORD is :WHEN_KEYWORD
    DO_KEYWORD is :DO_KEYWORD
    WHILE_KEYWORD is :WHILE_KEYWORD
    FOR_KEYWORD is :FOR_KEYWORD
    IN_KEYWORD is :IN_KEYWORD
    RANGE_KEYWORD is :RANGE_KEYWORD
    
    # Keywords - assignment
    IS_KEYWORD is :IS_KEYWORD
    IS_NOT_KEYWORD is :IS_NOT_KEYWORD
    BECOMES_KEYWORD is :BECOMES_KEYWORD
    
    # Keywords - other statements
    RETURN_KEYWORD is :RETURN_KEYWORD
    ACTIVATE_KEYWORD is :ACTIVATE_KEYWORD
    WITH_KEYWORD is :WITH_KEYWORD
    QUERY_KEYWORD is :QUERY_KEYWORD
    ASSERT_KEYWORD is :ASSERT_KEYWORD
    
    # Keywords - logic
    AND_KEYWORD is :AND_KEYWORD
    OR_KEYWORD is :OR_KEYWORD
    NOT_KEYWORD is :NOT_KEYWORD
    
    # Operators
    PLUS is :PLUS
    MINUS is :MINUS
    STAR is :STAR
    SLASH is :SLASH
    PERCENT is :PERCENT
    EQ is :EQ
    NEQ is :NEQ
    LT is :LT
    GT is :GT
    LTE is :LTE
    GTE is :GTE
    ARROW is :ARROW
    PIPE is :PIPE
    COLON is :COLON
    COMMA is :COMMA
    SEMICOLON is :SEMICOLON
    DOT is :DOT
    LPAREN is :LPAREN
    RPAREN is :RPAREN
    LBRACKET is :LBRACKET
    RBRACKET is :RBRACKET
    LBRACE is :LBRACE
    RBRACE is :LBRACE
    BLOCK_START is :BLOCK_START
    BLOCK_END is :BLOCK_END
    BLOCK_PARAM_START is :BLOCK_PARAM_START
    BLOCK_PARAM_END is :BLOCK_PARAM_END
    NEWLINE is :NEWLINE
    EOF is :EOF
}

# Token struct
make a class called Token {
    takes: type, value, line, column
    returns: {
        # Token is a simple data holder
        type is type
        value is value
        line is line
        column is column
    }
}

# Lexer error
make a class called LexerError {
    takes: message
    returns: {
        message is message
    }
}