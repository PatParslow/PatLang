require_relative 'token'
require_relative 'ast_nodes'

# Parser class for building Abstract Syntax Trees from tokens
class Parser
  def initialize(tokens)
    @tokens = tokens
    @current_token_index = 0
    @current_token = @tokens[@current_token_index]
  end

  def error(message = "Syntax error")
    raise "#{message} at token #{@current_token}"
  end

  def advance
    @current_token_index += 1
    if @current_token_index < @tokens.length
      @current_token = @tokens[@current_token_index]
    else
      @current_token = nil
    end
  end

  def eat(token_type)
    if @current_token && @current_token.type == token_type
      advance
    else
      error("Expected #{token_type}, got #{@current_token&.type}")
    end
  end

  # Grammar: expression → term (('+' | '-') term)*
  def expression
    node = term

    while @current_token && [@tokens.first.class::TOKEN_TYPES[:PLUS], @tokens.first.class::TOKEN_TYPES[:MINUS]].include?(@current_token.type)
      token = @current_token
      if token.type == Token::TOKEN_TYPES[:PLUS]
        eat(Token::TOKEN_TYPES[:PLUS])
      elsif token.type == Token::TOKEN_TYPES[:MINUS]
        eat(Token::TOKEN_TYPES[:MINUS])
      end

      node = BinaryOpNode.new(node, token.value, term)
    end

    node
  end

  # Grammar: term → factor (('*' | '/') factor)*
  def term
    node = factor

    while @current_token && [Token::TOKEN_TYPES[:MULTIPLY], Token::TOKEN_TYPES[:DIVIDE]].include?(@current_token.type)
      token = @current_token
      if token.type == Token::TOKEN_TYPES[:MULTIPLY]
        eat(Token::TOKEN_TYPES[:MULTIPLY])
      elsif token.type == Token::TOKEN_TYPES[:DIVIDE]
        eat(Token::TOKEN_TYPES[:DIVIDE])
      end

      node = BinaryOpNode.new(node, token.value, factor)
    end

    node
  end

  # Grammar: factor → NUMBER | IDENTIFIER | '(' expression ')'
  def factor
    token = @current_token

    if token.type == Token::TOKEN_TYPES[:NUMBER]
      eat(Token::TOKEN_TYPES[:NUMBER])
      return NumberNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:IDENTIFIER]
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
      return VariableNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:LPAREN]
      eat(Token::TOKEN_TYPES[:LPAREN])
      node = expression
      eat(Token::TOKEN_TYPES[:RPAREN])
      return node
    else
      error("Unexpected token in factor")
    end
  end

  # Grammar: assignment → IDENTIFIER '=' expression
  def assignment
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected identifier in assignment")
    end
    
    var_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    eat(Token::TOKEN_TYPES[:EQUALS])
    expr = expression
    
    AssignmentNode.new(var_name, expr)
  end

  # Check if current input is an assignment (IDENTIFIER followed by EQUALS)
  def is_assignment?
    return false unless @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER]
    return false unless @current_token_index + 1 < @tokens.length
    
    next_token = @tokens[@current_token_index + 1]
    next_token.type == Token::TOKEN_TYPES[:EQUALS]
  end

  def parse
    if @tokens.length == 1 && @tokens[0].type == Token::TOKEN_TYPES[:EOF]
      error("Empty expression")
    end

    # Check if this is an assignment or an expression
    if is_assignment?
      node = assignment
    else
      node = expression
    end
    
    # Ensure we've consumed all tokens except EOF
    if @current_token && @current_token.type != Token::TOKEN_TYPES[:EOF]
      error("Unexpected token after expression")
    end

    node
  end
end