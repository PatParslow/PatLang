require_relative 'token'
require_relative 'ambiguous_token'

# Lexer class for tokenizing Patlang source code
class Lexer
  def initialize(text)
    @text = text
    @position = 0
    @current_char = @text[@position]
    @line = 1
    @column = 1
  end

  def error
    raise "Invalid character '#{@current_char}' at position #{@position}"
  end

  def advance
    if @current_char == "\n"
      @line += 1
      @column = 1
    else
      @column += 1
    end
    
    @position += 1
    @current_char = @position < @text.length ? @text[@position] : nil
  end

  def skip_whitespace
    while @current_char && @current_char.match(/\s/)
      advance
    end
  end

  def skip_comment
    # Skip comment until end of line
    while @current_char && @current_char != "\n"
      advance
    end
    # Skip the newline if present
    if @current_char == "\n"
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
      # Skip whitespace
      if @current_char.match(/\s/)
        skip_whitespace
        next
      end

      # Skip comments
      if @current_char == '#'
        skip_comment
        next
      end

      if @current_char.match(/\d/)
        start_line, start_column = @line, @column
        return Token.new(Token::TOKEN_TYPES[:NUMBER], read_number, @position, start_line, start_column)
      end

      case @current_char
      when '+'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:PLUS], '+', @position - 1, start_line, start_column)
      when '-'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:MINUS], '-', @position - 1, start_line, start_column)
      when '*'
        start_line, start_column = @line, @column
        advance
        return Token.new(:STAR, '*', @position - 1, start_line, start_column)
      when '/'
        start_line, start_column = @line, @column
        advance
        return Token.new(:SLASH, '/', @position - 1, start_line, start_column)
      when '%'
        start_line, start_column = @line, @column
        advance
        return Token.new(:PERCENT, '%', @position - 1, start_line, start_column)
      when '('
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:LPAREN], '(', @position - 1, start_line, start_column)
      when ')'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:RPAREN], ')', @position - 1, start_line, start_column)
      when '='
        start_line, start_column = @line, @column
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:EQUAL], '==', @position - 2, start_line, start_column)
        else
          advance
          return Token.new(:ASSIGN, nil, @position - 1, start_line, start_column)
        end
      when '!'
        start_line, start_column = @line, @column
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:NOT_EQUAL], '!=', @position - 2, start_line, start_column)
        else
          advance
          return Token.new(Token::TOKEN_TYPES[:NOT], '!', @position - 1, start_line, start_column)
        end
      when '<'
        start_line, start_column = @line, @column
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:LESS_EQUAL], '<=', @position - 2, start_line, start_column)
        else
          advance
          return Token.new(:LESS, '<', @position - 1, start_line, start_column)
        end
      when '>'
        start_line, start_column = @line, @column
        if peek_char == '='
          advance
          advance
          return Token.new(Token::TOKEN_TYPES[:GREATER_EQUAL], '>=', @position - 2, start_line, start_column)
        else
          advance
          return Token.new(:GREATER, '>', @position - 1, start_line, start_column)
        end
      when '"'
        return tokenize_string
      when '.'
        # Check if this starts a decimal number
        if peek_char&.match(/\d/)
          start_line, start_column = @line, @column
          return Token.new(Token::TOKEN_TYPES[:NUMBER], read_number, @position, start_line, start_column)
        else
          start_line, start_column = @line, @column
          advance
          return Token.new(Token::TOKEN_TYPES[:DOT], '.', @position - 1, start_line, start_column)
        end
      when '['
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:LBRACKET], '[', @position - 1, start_line, start_column)
      when ']'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:RBRACKET], ']', @position - 1, start_line, start_column)
      when ','
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:COMMA], ',', @position - 1, start_line, start_column)
      when '{'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:LBRACE], '{', @position - 1, start_line, start_column)
      when '}'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:RBRACE], '}', @position - 1, start_line, start_column)
      when ':'
        start_line, start_column = @line, @column
        advance
        return Token.new(Token::TOKEN_TYPES[:COLON], ':', @position - 1, start_line, start_column)
      else
        if alpha?(@current_char)
          return read_identifier
        else
          error
        end
      end
    end

    Token.new(Token::TOKEN_TYPES[:EOF], nil, @position, @line, @column)
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
    start_line, start_column = @line, @column
    result = ''
    
    while @current_char && alphanumeric?(@current_char)
      result += @current_char
      advance
    end
    
    # Check for function phrase keywords - return AmbiguousTokens to let parser resolve context
    if result == 'make'
      # Return ambiguous token - let parser resolve context
      possibilities = [
        { type: Token::TOKEN_TYPES[:MAKE], value: result },
        { type: Token::TOKEN_TYPES[:IDENTIFIER], value: result }
      ]
      return AmbiguousToken.new(possibilities, start_position, start_line, start_column)
    elsif result == 'a'
      # Return ambiguous token - let parser resolve context
      possibilities = [
        { type: Token::TOKEN_TYPES[:A], value: result },
        { type: Token::TOKEN_TYPES[:IDENTIFIER], value: result }
      ]
      return AmbiguousToken.new(possibilities, start_position, start_line, start_column)
    elsif result == 'function'
      possibilities = [
        { type: Token::TOKEN_TYPES[:FUNCTION], value: result },
        { type: Token::TOKEN_TYPES[:IDENTIFIER], value: result }
      ]
      return AmbiguousToken.new(possibilities, start_position, start_line, start_column)
    elsif result == 'called'
      possibilities = [
        { type: Token::TOKEN_TYPES[:CALLED], value: result },
        { type: Token::TOKEN_TYPES[:IDENTIFIER], value: result }
      ]
      return AmbiguousToken.new(possibilities, start_position, start_line, start_column)
    end
    
    # Check if the identifier is a keyword (non-function keywords)
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
                 when 'print'
                   Token::TOKEN_TYPES[:PRINT]
                 when 'takes'
                   Token::TOKEN_TYPES[:TAKES]
                 when 'returns'
                   Token::TOKEN_TYPES[:RETURNS]
                 when 'return'
                   Token::TOKEN_TYPES[:RETURN]
                 when 'call'
                   Token::TOKEN_TYPES[:CALL]
                 when 'with'
                   Token::TOKEN_TYPES[:WITH]
                 else
                   Token::TOKEN_TYPES[:IDENTIFIER]
                 end
    
    Token.new(token_type, result, start_position, start_line, start_column)
  end

  def tokenize_string
    start_position = @position
    start_line, start_column = @line, @column
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
    Token.new(Token::TOKEN_TYPES[:STRING], value, start_position, start_line, start_column)
  end

  def in_function_definition_context?
    # Look backwards to see if we recently saw "make"
    # This is a simple heuristic - check the last few characters
    look_back_start = [@position - 20, 0].max
    recent_text = @text[look_back_start...@position]
    
    # If we see "make" recently, we're likely in a function definition context
    recent_text =~ /\bmake\s*$/
  end

  def in_arithmetic_context?
    # Look backwards in the text to see if we're in an arithmetic context
    # Simple heuristic: if we see operators like =, +, -, *, / recently, treat "a" as identifier
    # This is basic context detection - more sophisticated parsing would require full context
    
    # Look at recent characters (simplified approach)
    look_back_start = [@position - 10, 0].max
    recent_text = @text[look_back_start...@position]
    
    # If we see assignment or arithmetic operators recently, treat "a" as an identifier
    !!(recent_text =~ /[=+\-*\/]\s*$/)
  end
  
  
  
  
  def peek_word
    # Look ahead to see what the next word is without consuming it
    saved_position = @position
    saved_char = @current_char
    
    result = ''
    while @current_char && alphanumeric?(@current_char)
      result += @current_char
      advance
    end
    
    # Restore position
    @position = saved_position
    @current_char = saved_char
    
    result
  end
  
  def skip_word
    # Skip the current word
    while @current_char && alphanumeric?(@current_char)
      advance
    end
  end
  
  def read_word
    # Helper method to read a word without consuming it permanently
    result = ''
    while @current_char && alphanumeric?(@current_char)
      result += @current_char
      advance
    end
    result
  end
end
