# Token class representing lexical tokens in Patlang
class Token
  # Token types for minimal arithmetic expressions
  TOKEN_TYPES = {
    NUMBER: :NUMBER,
    PLUS: :PLUS,
    MINUS: :MINUS,
    MULTIPLY: :MULTIPLY,
    DIVIDE: :DIVIDE,
    LPAREN: :LPAREN,
    RPAREN: :RPAREN,
    IDENTIFIER: :IDENTIFIER,
    EQUALS: :EQUALS,
    # Boolean literals
    TRUE: :TRUE,
    FALSE: :FALSE,
    # Comparison operators
    EQUAL: :EQUAL,
    NOT_EQUAL: :NOT_EQUAL,
    LESS_THAN: :LESS_THAN,
    GREATER_THAN: :GREATER_THAN,
    LESS_EQUAL: :LESS_EQUAL,
    GREATER_EQUAL: :GREATER_EQUAL,
    # Control flow keywords
    IF: :IF,
    THEN: :THEN,
    ELSE: :ELSE,
    END: :END,
    WHILE: :WHILE,
    DO: :DO,
    EOF: :EOF
  }.freeze

  attr_reader :type, :value, :position

  def initialize(type, value = nil, position = 0)
    @type = type
    @value = value
    @position = position
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