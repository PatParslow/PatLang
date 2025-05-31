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