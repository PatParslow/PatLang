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
    has_decimal = false
    
    while @current_char && (@current_char.match(/\d/) || (@current_char == '.' && !has_decimal && peek_char&.match(/\d/)))
      if @current_char == '.'
        has_decimal = true
      end
      result += @current_char
      advance
    end
    
    has_decimal ? result.to_f : result.to_i
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
      when '='
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:EQUAL], '==', @position - 2)
        else
          advance
          return Token.new(Token::TOKEN_TYPES[:EQUALS], '=', @position - 1)
        end
      when '!'
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:NOT_EQUAL], '!=', @position - 2)
        else
          error
        end
      when '<'
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:LESS_EQUAL], '<=', @position - 2)
        else
          advance
          return Token.new(Token::TOKEN_TYPES[:LESS_THAN], '<', @position - 1)
        end
      when '>'
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:GREATER_EQUAL], '>=', @position - 2)
        else
          advance
          return Token.new(Token::TOKEN_TYPES[:GREATER_THAN], '>', @position - 1)
        end
      when '"'
        return tokenize_string
      when '.'
        advance
        return Token.new(Token::TOKEN_TYPES[:DOT], '.', @position - 1)
      when '['
        advance
        return Token.new(Token::TOKEN_TYPES[:LBRACKET], '[', @position - 1)
      when ']'
        advance
        return Token.new(Token::TOKEN_TYPES[:RBRACKET], ']', @position - 1)
      when ','
        advance
        return Token.new(Token::TOKEN_TYPES[:COMMA], ',', @position - 1)
      else
        if alpha?(@current_char)
          return read_identifier
        else
          error
        end
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

  private

  def peek_char
    next_position = @position + 1
    next_position < @text.length ? @text[next_position] : nil
  end

  def alpha?(char)
    (char >= 'a' && char <= 'z') ||
    (char >= 'A' && char <= 'Z') ||
    char == '_'
  end

  def alphanumeric?(char)
    alpha?(char) || char.match(/\d/)
  end

  def read_identifier
    start_position = @position
    result = ''
    
    while @current_char && alphanumeric?(@current_char)
      result += @current_char
      advance
    end
    
    # Check if the identifier is a keyword
    token_type = case result
                 when 'true'
                   Token::TOKEN_TYPES[:TRUE]
                 when 'false'
                   Token::TOKEN_TYPES[:FALSE]
                 when 'if'
                   Token::TOKEN_TYPES[:IF]
                 when 'then'
                   Token::TOKEN_TYPES[:THEN]
                 when 'else'
                   Token::TOKEN_TYPES[:ELSE]
                 when 'end'
                   Token::TOKEN_TYPES[:END]
                 when 'while'
                   Token::TOKEN_TYPES[:WHILE]
                 when 'do'
                   Token::TOKEN_TYPES[:DO]
                 else
                   Token::TOKEN_TYPES[:IDENTIFIER]
                 end
    
    Token.new(token_type, result, start_position)
  end

  def tokenize_string
    start_position = @position
    advance  # Skip opening quote
    value = ""
    
    while @current_char && @current_char != '"'
      if @current_char == '\\'
        # Handle escape sequences
        advance
        if @current_char
          case @current_char
          when 'n'
            value += "\n"
          when 't'
            value += "\t"
          when 'r'
            value += "\r"
          when '\\'
            value += "\\"
          when '"'
            value += '"'
          else
            value += @current_char
          end
          advance
        else
          raise "Incomplete escape sequence at end of string"
        end
      else
        value += @current_char
        advance
      end
    end
    
    if @current_char != '"'
      raise "Unterminated string literal starting at position #{start_position}"
    end
    
    advance  # Skip closing quote
    Token.new(Token::TOKEN_TYPES[:STRING], value, start_position)
  end
end