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

  # Grammar: expression → comparison
  def expression
    comparison
  end

  # Grammar: comparison → term (('==' | '!=' | '<' | '>' | '<=' | '>=') term)*
  def comparison
    node = term_addition

    while @current_token && [Token::TOKEN_TYPES[:EQUAL], Token::TOKEN_TYPES[:NOT_EQUAL],
                            Token::TOKEN_TYPES[:LESS_THAN], Token::TOKEN_TYPES[:GREATER_THAN],
                            Token::TOKEN_TYPES[:LESS_EQUAL], Token::TOKEN_TYPES[:GREATER_EQUAL]].include?(@current_token.type)
      token = @current_token
      case token.type
      when Token::TOKEN_TYPES[:EQUAL]
        eat(Token::TOKEN_TYPES[:EQUAL])
      when Token::TOKEN_TYPES[:NOT_EQUAL]
        eat(Token::TOKEN_TYPES[:NOT_EQUAL])
      when Token::TOKEN_TYPES[:LESS_THAN]
        eat(Token::TOKEN_TYPES[:LESS_THAN])
      when Token::TOKEN_TYPES[:GREATER_THAN]
        eat(Token::TOKEN_TYPES[:GREATER_THAN])
      when Token::TOKEN_TYPES[:LESS_EQUAL]
        eat(Token::TOKEN_TYPES[:LESS_EQUAL])
      when Token::TOKEN_TYPES[:GREATER_EQUAL]
        eat(Token::TOKEN_TYPES[:GREATER_EQUAL])
      end

      node = ComparisonNode.new(node, token.value, term_addition)
    end

    node
  end

  # Grammar: term_addition → term_multiplication (('+' | '-') term_multiplication)*
  def term_addition
    node = term_multiplication

    while @current_token && [Token::TOKEN_TYPES[:PLUS], Token::TOKEN_TYPES[:MINUS]].include?(@current_token.type)
      token = @current_token
      if token.type == Token::TOKEN_TYPES[:PLUS]
        eat(Token::TOKEN_TYPES[:PLUS])
      elsif token.type == Token::TOKEN_TYPES[:MINUS]
        eat(Token::TOKEN_TYPES[:MINUS])
      end

      node = BinaryOpNode.new(node, token.value, term_multiplication)
    end

    node
  end

  # Grammar: term_multiplication → factor (('*' | '/') factor)*
  def term_multiplication
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

  # Grammar: factor → postfix
  def factor
    postfix
  end

  # Grammar: postfix → primary ('[' expression ']' | '.' IDENTIFIER)*
  def postfix
    node = primary

    while @current_token && (@current_token.type == Token::TOKEN_TYPES[:LBRACKET] || @current_token.type == Token::TOKEN_TYPES[:DOT])
      if @current_token.type == Token::TOKEN_TYPES[:LBRACKET]
        eat(Token::TOKEN_TYPES[:LBRACKET])
        index = expression
        eat(Token::TOKEN_TYPES[:RBRACKET])
        node = IndexAccessNode.new(node, index)
      elsif @current_token.type == Token::TOKEN_TYPES[:DOT]
        eat(Token::TOKEN_TYPES[:DOT])
        if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
          error("Expected method name after '.'")
        end
        method_name = @current_token.value
        eat(Token::TOKEN_TYPES[:IDENTIFIER])
        
        # Parse method arguments if parentheses are present
        arguments = []
        if @current_token && @current_token.type == Token::TOKEN_TYPES[:LPAREN]
          eat(Token::TOKEN_TYPES[:LPAREN])
          
          # Parse argument list
          unless @current_token && @current_token.type == Token::TOKEN_TYPES[:RPAREN]
            arguments << expression
            while @current_token && @current_token.type == Token::TOKEN_TYPES[:COMMA]
              eat(Token::TOKEN_TYPES[:COMMA])
              arguments << expression
            end
          end
          
          eat(Token::TOKEN_TYPES[:RPAREN])
        end
        
        node = MethodCallNode.new(node, method_name, arguments)
      end
    end

    node
  end

  # Grammar: primary → NUMBER | IDENTIFIER | STRING | boolean | '(' expression ')' | '-' factor
  def primary
    token = @current_token

    if token.type == Token::TOKEN_TYPES[:NUMBER]
      eat(Token::TOKEN_TYPES[:NUMBER])
      return NumberNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:IDENTIFIER]
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
      return VariableNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:STRING]
      eat(Token::TOKEN_TYPES[:STRING])
      return StringNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:TRUE] || token.type == Token::TOKEN_TYPES[:FALSE]
      return parse_boolean
    elsif token.type == Token::TOKEN_TYPES[:MINUS]
      eat(Token::TOKEN_TYPES[:MINUS])
      # Handle unary minus by creating a binary operation with 0 - factor
      return BinaryOpNode.new(NumberNode.new(0), '-', factor)
    elsif token.type == Token::TOKEN_TYPES[:LPAREN]
      eat(Token::TOKEN_TYPES[:LPAREN])
      node = expression
      eat(Token::TOKEN_TYPES[:RPAREN])
      return node
    else
      error("Unexpected token in factor")
    end
  end

  # Grammar: boolean → 'true' | 'false'
  def parse_boolean
    token = @current_token
    
    if token.type == Token::TOKEN_TYPES[:TRUE]
      eat(Token::TOKEN_TYPES[:TRUE])
      return BooleanNode.new(true)
    elsif token.type == Token::TOKEN_TYPES[:FALSE]
      eat(Token::TOKEN_TYPES[:FALSE])
      return BooleanNode.new(false)
    else
      error("Expected boolean literal")
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

    # Parse program as sequence of statements
    node = parse_program
    
    # Ensure we've consumed all tokens except EOF
    if @current_token && @current_token.type != Token::TOKEN_TYPES[:EOF]
      error("Unexpected token after program")
    end

    node
  end

  # Grammar: program → statement*
  def parse_program
    statements = []
    
    # Parse statements until we hit EOF
    while @current_token && @current_token.type != Token::TOKEN_TYPES[:EOF]
      if @current_token.type == Token::TOKEN_TYPES[:IF]
        statements << parse_if_statement
      elsif @current_token.type == Token::TOKEN_TYPES[:WHILE]
        statements << parse_while_statement
      elsif is_assignment?
        statements << assignment
      else
        statements << expression
      end
      
      # Break if we're at EOF or if we can't parse any more statements
      break if @current_token.nil? || @current_token.type == Token::TOKEN_TYPES[:EOF]
    end
    
    # If only one statement, return it directly; otherwise return a block
    if statements.length == 1
      statements[0]
    else
      BlockNode.new(statements)
    end
  end

  # Grammar: if_statement → 'if' expression 'then' block ('else' block)? 'end'
  def parse_if_statement
    eat(Token::TOKEN_TYPES[:IF])
    condition = expression
    eat(Token::TOKEN_TYPES[:THEN])
    then_body = parse_block
    
    else_body = nil
    if @current_token&.type == Token::TOKEN_TYPES[:ELSE]
      eat(Token::TOKEN_TYPES[:ELSE])
      else_body = parse_block
    end
    
    eat(Token::TOKEN_TYPES[:END])
    IfNode.new(condition, then_body, else_body)
  end

  # Grammar: while_statement → 'while' expression 'do' block 'end'
  def parse_while_statement
    eat(Token::TOKEN_TYPES[:WHILE])
    condition = expression
    eat(Token::TOKEN_TYPES[:DO])
    body = parse_block
    eat(Token::TOKEN_TYPES[:END])
    
    WhileNode.new(condition, body)
  end

  # Grammar: block → statement*
  def parse_block
    statements = []
    
    # Parse statements until we hit a block terminator
    while @current_token &&
          ![Token::TOKEN_TYPES[:END], Token::TOKEN_TYPES[:ELSE], Token::TOKEN_TYPES[:EOF]].include?(@current_token.type)
      
      if @current_token.type == Token::TOKEN_TYPES[:IF]
        statements << parse_if_statement
      elsif @current_token.type == Token::TOKEN_TYPES[:WHILE]
        statements << parse_while_statement
      elsif is_assignment?
        statements << assignment
      else
        statements << expression
      end
      
      # Skip optional semicolons or newlines (not implemented in lexer yet, just continue)
      break if @current_token.nil? ||
               [Token::TOKEN_TYPES[:END], Token::TOKEN_TYPES[:ELSE], Token::TOKEN_TYPES[:EOF]].include?(@current_token.type)
    end
    
    BlockNode.new(statements)
  end
end