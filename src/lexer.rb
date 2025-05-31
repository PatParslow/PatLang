require_relative 'token'

# Lexer class for tokenizing Patlang source code
class Lexer
  def initialize(text)
    @text = text
    @position = 0
    @current_char = @text[@position]
  end

  def error
    raise "Invalid character '#{@current_char}' at position #{@position}"
  end

  def advance
    @position += 1
    @current_char = @position < @text.length ? @text[@position] : nil
  end

  def skip_whitespace
    while @current_char && @current_char.match(/\s/)
      advance
    end
  end

  def read_number
    result = ''
    while @current_char && @current_char.match(/\d/)
      result += @current_char
      advance
    end
    result.to_i
  end

  def get_next_token
    while @current_char
      if @current_char.match(/\s/)
        skip_whitespace
        next
      end

      if @current_char.match(/\d/)
        return Token.new(Token::TOKEN_TYPES[:NUMBER], read_number, @position)
      end

      case @current_char
      when '+'
        advance
        return Token.new(Token::TOKEN_TYPES[:PLUS], '+', @position - 1)
      when '-'
        advance
        return Token.new(Token::TOKEN_TYPES[:MINUS], '-', @position - 1)
      when '*'
        advance
        return Token.new(Token::TOKEN_TYPES[:MULTIPLY], '*', @position - 1)
      when '/'
        advance
        return Token.new(Token::TOKEN_TYPES[:DIVIDE], '/', @position - 1)
      when '('
        advance
        return Token.new(Token::TOKEN_TYPES[:LPAREN], '(', @position - 1)
      when ')'
        advance
        return Token.new(Token::TOKEN_TYPES[:RPAREN], ')', @position - 1)
      else
        error
      end
    end

    Token.new(Token::TOKEN_TYPES[:EOF], nil, @position)
  end

  def tokenize
    tokens = []
    token = get_next_token
    while token.type != Token::TOKEN_TYPES[:EOF]
      tokens << token
      token = get_next_token
    end
    tokens << token # Add EOF token
    tokens
  end
end