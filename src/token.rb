# Token class representing lexical tokens in Patlang
class Token
  # Token types for minimal arithmetic expressions
  TOKEN_TYPES = {
    NUMBER: :NUMBER,
    PLUS: :PLUS,
    MINUS: :MINUS,
    MULTIPLY: :MULTIPLY,
    STAR: :MULTIPLY,  # Alias for backward compatibility
    DIVIDE: :DIVIDE,
    SLASH: :DIVIDE,   # Alias for backward compatibility
    PERCENT: :PERCENT,
    MODULO: :PERCENT,  # Alias for backward compatibility
    LPAREN: :LPAREN,
    RPAREN: :RPAREN,
    IDENTIFIER: :IDENTIFIER,
    ASSIGN: :ASSIGN,
    EQUALS: :ASSIGN,  # Alias for backward compatibility
    # Boolean literals
    TRUE: :TRUE,
    FALSE: :FALSE,
    # Comparison operators
    NOT: :NOT,
    EQUAL: :EQUAL,
    NOT_EQUAL: :NOT_EQUAL,
    LESS_THAN: :LESS_THAN,
    LESS: :LESS_THAN,  # Alias for backward compatibility
    GREATER_THAN: :GREATER_THAN,
    GREATER: :GREATER_THAN,  # Alias for backward compatibility
    LESS_EQUAL: :LESS_EQUAL,
    GREATER_EQUAL: :GREATER_EQUAL,
    # Control flow keywords
    IF: :IF,
    THEN: :THEN,
    ELSE: :ELSE,
    END: :END,
    WHILE: :WHILE,
    DO: :DO,
    PRINT: :PRINT,
    # String operations
    STRING: :STRING,
    DOT: :DOT,
    LBRACKET: :LBRACKET,
    RBRACKET: :RBRACKET,
    COMMA: :COMMA,
    # Function definition keywords
    MAKE: :MAKE,
    A: :A,
    FUNCTION: :FUNCTION,
    CALLED: :CALLED,
    TAKES: :TAKES,
    RETURNS: :RETURNS,
    RETURN: :RETURN,
    CALL: :CALL,
    WITH: :WITH,
    # Block delimiters
    LBRACE: :LBRACE,
    RBRACE: :RBRACE,
    COLON: :COLON,
    EOF: :EOF
  }.freeze

  attr_reader :type, :value, :position, :line, :column

  def initialize(type, value = nil, position = 0, line = 1, column = 1)
    @type = type
    @value = value
    @position = position
    @line = line
    @column = column
  end

  def to_s
    if @value
      "Token(#{@type}, #{@value})"
    else
      "Token(#{@type})"
    end
  end

  def inspect
    to_s
  end
end