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

  # Grammar: postfix → primary ('[' expression ']' | '.' IDENTIFIER | '(' argument_list? ')')*
  def postfix
    node = primary

    while @current_token && (@current_token.type == Token::TOKEN_TYPES[:LBRACKET] ||
                            @current_token.type == Token::TOKEN_TYPES[:DOT] ||
                            (@current_token.type == Token::TOKEN_TYPES[:LPAREN] && node.is_a?(VariableNode)))
      if @current_token.type == Token::TOKEN_TYPES[:LBRACKET]
        eat(Token::TOKEN_TYPES[:LBRACKET])
        index = expression
        eat(Token::TOKEN_TYPES[:RBRACKET])
        node = IndexAccessNode.new(node, index)
      elsif @current_token.type == Token::TOKEN_TYPES[:LPAREN] && node.is_a?(VariableNode)
        # Handle function call syntax: identifier(args)
        eat(Token::TOKEN_TYPES[:LPAREN])
        arguments = []
        
        # Parse arguments if present
        if @current_token.type != Token::TOKEN_TYPES[:RPAREN]
          arguments = parse_argument_list
        end
        
        eat(Token::TOKEN_TYPES[:RPAREN])
        node = FunctionCallNode.new(node.name, arguments)
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
      statements << parse_statement
      
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

  # Grammar: statement → function_definition | if_statement | while_statement | return_statement | assignment | expression
  def parse_statement
    if @current_token.type == Token::TOKEN_TYPES[:MAKE]
      parse_function_definition
    elsif @current_token.type == Token::TOKEN_TYPES[:IF]
      parse_if_statement
    elsif @current_token.type == Token::TOKEN_TYPES[:WHILE]
      parse_while_statement
    elsif @current_token.type == Token::TOKEN_TYPES[:RETURN]
      parse_return_statement
    elsif @current_token.type == Token::TOKEN_TYPES[:CALL]
      parse_function_call
    elsif is_assignment?
      assignment
    else
      expression
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
          ![Token::TOKEN_TYPES[:END], Token::TOKEN_TYPES[:ELSE], Token::TOKEN_TYPES[:EOF], Token::TOKEN_TYPES[:RBRACE]].include?(@current_token.type)
      
      statements << parse_statement
      
      # Skip optional semicolons or newlines (not implemented in lexer yet, just continue)
      break if @current_token.nil? ||
               [Token::TOKEN_TYPES[:END], Token::TOKEN_TYPES[:ELSE], Token::TOKEN_TYPES[:EOF], Token::TOKEN_TYPES[:RBRACE]].include?(@current_token.type)
    end
    
    BlockNode.new(statements)
  end
  # Grammar: primary → NUMBER | IDENTIFIER | STRING | boolean | function_call | '(' expression ')' | '-' factor
  def primary
    token = @current_token

    if token.type == Token::TOKEN_TYPES[:NUMBER]
      eat(Token::TOKEN_TYPES[:NUMBER])
      return NumberNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:CALL]
      return parse_function_call
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

  # Grammar: function_definition → 'make' 'a'? 'function' 'called' IDENTIFIER ('takes:' parameter_list)? ('returns:' type)? '{' block '}'
  def parse_function_definition
    eat(Token::TOKEN_TYPES[:MAKE])
    # Skip optional 'a' if present
    if @current_token && @current_token.type == Token::TOKEN_TYPES[:IDENTIFIER] && @current_token.value == "a"
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
    end
    eat(Token::TOKEN_TYPES[:FUNCTION])
    eat(Token::TOKEN_TYPES[:CALLED])
    
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected function name after 'called'")
    end
    function_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    parameters = []
    return_type = nil
    
    # Parse optional 'takes:' parameter list
    if @current_token && @current_token.type == Token::TOKEN_TYPES[:TAKES]
      eat(Token::TOKEN_TYPES[:TAKES])
      eat(Token::TOKEN_TYPES[:COLON])
      parameters = parse_parameter_list
    end
    
    # Parse optional 'returns:' type
    if @current_token && @current_token.type == Token::TOKEN_TYPES[:RETURNS]
      eat(Token::TOKEN_TYPES[:RETURNS])
      eat(Token::TOKEN_TYPES[:COLON])
      if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
        error("Expected return type after 'returns:'")
      end
      return_type = @current_token.value
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
    end
    
    # Parse function body
    eat(Token::TOKEN_TYPES[:LBRACE])
    body = parse_block
    eat(Token::TOKEN_TYPES[:RBRACE])
    
    FunctionDefinitionNode.new(function_name, parameters, body, return_type)
  end
  
  # Grammar: parameter_list → parameter (',' parameter)*
  def parse_parameter_list
    parameters = []
    
    parameters << parse_parameter
    
    while @current_token && @current_token.type == Token::TOKEN_TYPES[:COMMA]
      eat(Token::TOKEN_TYPES[:COMMA])
      parameters << parse_parameter
    end
    
    parameters
  end
  
  # Grammar: parameter → IDENTIFIER ('-' IDENTIFIER)?
  def parse_parameter
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected parameter name")
    end
    param_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    param_type = nil
    # Parse optional type annotation with '-' separator
    if @current_token && @current_token.type == Token::TOKEN_TYPES[:MINUS]
      eat(Token::TOKEN_TYPES[:MINUS])
      if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
        error("Expected type after '-'")
      end
      param_type = @current_token.value
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
    end
    
    ParameterNode.new(param_name, param_type)
  end
  
  # Grammar: function_call → 'call' IDENTIFIER ('(' argument_list? ')' | 'with' argument_list | 'which requires:' argument_list)?
  def parse_function_call
    eat(Token::TOKEN_TYPES[:CALL])
    
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected function name after 'call'")
    end
    function_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    arguments = []
    
    # Check which syntax is being used
    if @current_token && @current_token.type == Token::TOKEN_TYPES[:LPAREN]
      # Parentheses syntax: call function_name(arg1, arg2)
      eat(Token::TOKEN_TYPES[:LPAREN])
      if @current_token.type != Token::TOKEN_TYPES[:RPAREN]
        arguments = parse_argument_list
      end
      eat(Token::TOKEN_TYPES[:RPAREN])
    elsif @current_token && @current_token.value == "with"
      # With syntax: call function_name with arg1, arg2
      eat(Token::TOKEN_TYPES[:IDENTIFIER]) # 'with' is tokenized as IDENTIFIER
      arguments = parse_argument_list
    elsif @current_token && @current_token.value == "which"
      # Goal-oriented syntax: call function_name which requires: arg1, arg2
      eat(Token::TOKEN_TYPES[:IDENTIFIER]) # 'which' is tokenized as IDENTIFIER
      if @current_token && @current_token.value == "requires"
        eat(Token::TOKEN_TYPES[:IDENTIFIER]) # 'requires' is tokenized as IDENTIFIER
        if @current_token && @current_token.type == Token::TOKEN_TYPES[:COLON]
          eat(Token::TOKEN_TYPES[:COLON])
          arguments = parse_argument_list
        else
          error("Expected ':' after 'requires'")
        end
      else
        error("Expected 'requires' after 'which'")
      end
    end
    # If no syntax indicators found, it's a function call with no arguments
    
    FunctionCallNode.new(function_name, arguments)
  end
  
  # Grammar: argument_list → expression (',' expression)*
  def parse_argument_list
    arguments = []
    
    arguments << expression
    
    while @current_token && @current_token.type == Token::TOKEN_TYPES[:COMMA]
      eat(Token::TOKEN_TYPES[:COMMA])
      arguments << expression
    end
    
    arguments
  end
  
  # Grammar: return_statement → 'return' expression?
  def parse_return_statement
    eat(Token::TOKEN_TYPES[:RETURN])
    
    return_expression = nil
    # Parse optional return expression
    if @current_token && 
       @current_token.type != Token::TOKEN_TYPES[:EOF] &&
       @current_token.type != Token::TOKEN_TYPES[:END] &&
       @current_token.type != Token::TOKEN_TYPES[:RBRACE]
      return_expression = expression
    end
    
    ReturnNode.new(return_expression)
end
  end