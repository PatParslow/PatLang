require_relative 'token'
require_relative 'ast_nodes'
require_relative 'ambiguous_token'

# Parser class for parsing Patlang source code
class Parser
  def initialize(tokens)
    @tokens = tokens
    @current_token_index = 0
    @current_token = @tokens[@current_token_index]
  end

  def error(message = "Parse error")
    raise "#{message} at token #{@current_token}"
  end

  def advance
    @current_token_index += 1
    if @current_token_index < @tokens.length
      @current_token = @tokens[@current_token_index]
    else
      @current_token = Token.new(Token::TOKEN_TYPES[:EOF], nil)
    end
  end

  def eat(token_type)
    if @current_token.type == token_type
      advance
    else
      expected_name = Token::TOKEN_TYPES.key(token_type)
      actual_name = Token::TOKEN_TYPES.key(@current_token.type) || @current_token.type
      error("Expected #{expected_name}, got #{actual_name}")
    end
  end

  def parse
    result = parse_program
    if @current_token.type != Token::TOKEN_TYPES[:EOF]
      error("Expected end of input")
    end
    result
  end

  # Handle ambiguous token resolution in context
  def resolve_ambiguous_token_as_identifier(token)
    if token.ambiguous?
      resolved = token.resolve_to(Token::TOKEN_TYPES[:IDENTIFIER])
      if resolved
        @tokens[@current_token_index] = resolved
        @current_token = resolved
        return resolved
      else
        error("Cannot resolve ambiguous token as identifier in this context")
      end
    end
    token
  end

  def resolve_ambiguous_token_as_article(token)
    if token.ambiguous?
      resolved = token.resolve_to(Token::TOKEN_TYPES[:A])
      if resolved
        @tokens[@current_token_index] = resolved
        @current_token = resolved
        return resolved
      else
        error("Cannot resolve ambiguous token as article in this context")
      end
    end
    token
  end

  # Grammar: expression → comparison
  def expression
    comparison
  end

  # Grammar: comparison → term_addition (('>' | '<' | '>=' | '<=' | '==' | '!=') term_addition)*
  def comparison
    node = term_addition

    while @current_token.type == Token::TOKEN_TYPES[:GREATER] ||
          @current_token.type == Token::TOKEN_TYPES[:LESS] ||
          @current_token.type == Token::TOKEN_TYPES[:GREATER_EQUAL] ||
          @current_token.type == Token::TOKEN_TYPES[:LESS_EQUAL] ||
          @current_token.type == Token::TOKEN_TYPES[:EQUAL] ||
          @current_token.type == Token::TOKEN_TYPES[:NOT_EQUAL]
      op = @current_token.value
      advance
      right = term_addition
      node = BinaryOpNode.new(node, op, right)
    end

    node
  end

  # Grammar: term_addition → term_multiplication (('+' | '-') term_multiplication)*
  def term_addition
    node = term_multiplication

    while @current_token.type == Token::TOKEN_TYPES[:PLUS] || 
          @current_token.type == Token::TOKEN_TYPES[:MINUS]
      op = @current_token.value
      advance
      right = term_multiplication
      node = BinaryOpNode.new(node, op, right)
    end

    node
  end

  # Grammar: term_multiplication → factor (('*' | '/') factor)*
  def term_multiplication
    node = factor

    while @current_token.type == Token::TOKEN_TYPES[:STAR] || 
          @current_token.type == Token::TOKEN_TYPES[:SLASH]
      op = @current_token.value
      advance
      right = factor
      node = BinaryOpNode.new(node, op, right)
    end

    node
  end

  # Grammar: factor → postfix
  def factor
    postfix
  end

  # Grammar: postfix → primary ('.' IDENTIFIER)*
  def postfix
    node = primary

    while @current_token.type == Token::TOKEN_TYPES[:DOT]
      advance # consume '.'
      
      # Handle method call
      if @current_token.type == Token::TOKEN_TYPES[:IDENTIFIER]
        method_name = @current_token.value
        advance
        node = MethodCallNode.new(node, method_name)
      elsif @current_token.ambiguous?
        # Try to resolve as identifier for method name
        resolved = resolve_ambiguous_token_as_identifier(@current_token)
        method_name = resolved.value
        advance
        node = MethodCallNode.new(node, method_name)
      else
        error("Expected method name after '.'")
      end
    end

    node
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
    elsif token.ambiguous?
      # Try to resolve as IDENTIFIER for variable access
      resolved = token.resolve_to(Token::TOKEN_TYPES[:IDENTIFIER])
      if resolved
        @tokens[@current_token_index] = resolved
        @current_token = resolved
        advance
        return VariableNode.new(resolved.value)
      else
        error("Ambiguous token cannot be resolved as identifier in this context")
      end
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
      error("Expected boolean value")
    end
  end

  # Grammar: program → statement*
  def parse_program
    statements = []

    while @current_token.type != Token::TOKEN_TYPES[:EOF]
      stmt = parse_statement
      statements << stmt if stmt
    end

    if statements.length == 1
      statements.first
    else
      BlockNode.new(statements)
    end
  end

  # Grammar: statement → assignment | expression | if_statement | while_statement | print_statement | function_definition | return_statement | function_call_statement
  def parse_statement
    case @current_token.type
    when Token::TOKEN_TYPES[:IF]
      parse_if_statement
    when Token::TOKEN_TYPES[:WHILE]
      parse_while_statement
    when Token::TOKEN_TYPES[:PRINT]
      parse_print_statement
    when Token::TOKEN_TYPES[:MAKE]
      # Check if this is a function definition or variable assignment
      if peek_function_definition?
        parse_function_definition
      else
        parse_assignment_or_expression
      end
    when Token::TOKEN_TYPES[:RETURN]
      parse_return_statement
    when Token::TOKEN_TYPES[:CALL]
      parse_function_call_statement
    else
      parse_assignment_or_expression
    end
  end

  def peek_function_definition?
    # Look ahead to see if this is "make a function called"
    saved_index = @current_token_index
    
    # Skip MAKE
    temp_index = saved_index + 1
    return false if temp_index >= @tokens.length
    
    # Check for A or ambiguous token that could be A
    next_token = @tokens[temp_index]
    if next_token.type == Token::TOKEN_TYPES[:A] || 
       (next_token.ambiguous? && next_token.can_be?(Token::TOKEN_TYPES[:A]))
      temp_index += 1
      return false if temp_index >= @tokens.length
      
      # Check for FUNCTION
      if @tokens[temp_index].type == Token::TOKEN_TYPES[:FUNCTION]
        temp_index += 1
        return false if temp_index >= @tokens.length
        
        # Check for CALLED
        return @tokens[temp_index].type == Token::TOKEN_TYPES[:CALLED]
      end
    end
    
    false
  end

  def parse_assignment_or_expression
    # Handle ambiguous tokens in assignment context
    if @current_token.ambiguous?
      # For assignment, we need to resolve as IDENTIFIER
      resolved = resolve_ambiguous_token_as_identifier(@current_token)
      var_name = resolved.value
      advance
      
      if @current_token.type == Token::TOKEN_TYPES[:ASSIGN]
        advance # consume =
        value = expression
        return AssignmentNode.new(var_name, value)
      else
        # It's just a variable reference, backtrack and parse as expression
        @current_token_index -= 1
        @current_token = @tokens[@current_token_index]
        return expression
      end
    elsif @current_token.type == Token::TOKEN_TYPES[:IDENTIFIER]
      var_name = @current_token.value
      advance
      
      if @current_token.type == Token::TOKEN_TYPES[:ASSIGN]
        advance # consume =
        value = expression
        return AssignmentNode.new(var_name, value)
      else
        # It's just a variable reference, backtrack and parse as expression
        @current_token_index -= 1
        @current_token = @tokens[@current_token_index]
        return expression
      end
    else
      expression
    end
  end

  # Grammar: if_statement → 'if' expression 'then' statement ('else' statement)? 'end'
  def parse_if_statement
    eat(Token::TOKEN_TYPES[:IF])
    condition = expression
    eat(Token::TOKEN_TYPES[:THEN])
    then_statement = parse_block
    
    else_statement = nil
    if @current_token.type == Token::TOKEN_TYPES[:ELSE]
      eat(Token::TOKEN_TYPES[:ELSE])
      else_statement = parse_block
    end
    
    eat(Token::TOKEN_TYPES[:END])
    IfNode.new(condition, then_statement, else_statement)
  end

  # Grammar: while_statement → 'while' expression 'do' statement 'end'
  def parse_while_statement
    eat(Token::TOKEN_TYPES[:WHILE])
    condition = expression
    eat(Token::TOKEN_TYPES[:DO])
    body = parse_block
    eat(Token::TOKEN_TYPES[:END])
    WhileNode.new(condition, body)
  end

  def parse_block
    statements = []
    
    while @current_token.type != Token::TOKEN_TYPES[:END] && 
          @current_token.type != Token::TOKEN_TYPES[:ELSE] &&
          @current_token.type != Token::TOKEN_TYPES[:RBRACE] &&
          @current_token.type != Token::TOKEN_TYPES[:EOF]
      stmt = parse_statement
      statements << stmt if stmt
    end
    
    BlockNode.new(statements)
  end

  # Grammar: print_statement → 'print' expression
  def parse_print_statement
    eat(Token::TOKEN_TYPES[:PRINT])
    value = expression
    PrintNode.new(value)
  end

  # Grammar: function_definition → 'make' 'a' 'function' 'called' IDENTIFIER ('takes:' parameter_list)? ('returns:' type)? '{' statement* '}'
  def parse_function_definition
    eat(Token::TOKEN_TYPES[:MAKE])
    
    # Handle A token (could be ambiguous)
    if @current_token.ambiguous?
      resolve_ambiguous_token_as_article(@current_token)
    end
    eat(Token::TOKEN_TYPES[:A])
    
    eat(Token::TOKEN_TYPES[:FUNCTION])
    eat(Token::TOKEN_TYPES[:CALLED])
    
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected function name")
    end
    function_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    # Parse parameters if present
    parameters = []
    if @current_token.type == Token::TOKEN_TYPES[:TAKES]
      eat(Token::TOKEN_TYPES[:TAKES])
      eat(Token::TOKEN_TYPES[:COLON])
      parameters = parse_parameter_list
    end
    
    # Parse return type if present
    return_type = nil
    if @current_token.type == Token::TOKEN_TYPES[:RETURNS]
      eat(Token::TOKEN_TYPES[:RETURNS])
      eat(Token::TOKEN_TYPES[:COLON])
      return_type = parse_type
    end
    
    eat(Token::TOKEN_TYPES[:LBRACE])
    body = parse_block
    eat(Token::TOKEN_TYPES[:RBRACE])
    
    FunctionDefinitionNode.new(function_name, parameters, body, return_type)
  end

  def parse_parameter_list
    parameters = []
    
    loop do
      # Handle ambiguous tokens in parameter names
      if @current_token.ambiguous?
        resolved = resolve_ambiguous_token_as_identifier(@current_token)
        param_name = resolved.value
        advance
      elsif @current_token.type == Token::TOKEN_TYPES[:IDENTIFIER]
        param_name = @current_token.value
        advance
      else
        error("Expected parameter name")
      end
      
      param_type = nil
      default_value = nil
      
      # Check for type annotation
      if @current_token.type == Token::TOKEN_TYPES[:MINUS]
        advance # consume '-'
        param_type = parse_type
      end
      
      parameters << ParameterNode.new(param_name, param_type, default_value)
      
      if @current_token.type == Token::TOKEN_TYPES[:COMMA]
        advance # consume ','
      else
        break
      end
    end
    
    parameters
  end

  def parse_type
    if @current_token.type == Token::TOKEN_TYPES[:IDENTIFIER]
      type_name = @current_token.value
      advance
      type_name
    else
      error("Expected type name")
    end
  end

  # Grammar: function_call_statement → 'call' function_call
  def parse_function_call_statement
    parse_function_call
  end

  # Grammar: function_call → 'call' IDENTIFIER ('with' argument_list)? | 'call' IDENTIFIER '(' argument_list? ')'
  def parse_function_call
    eat(Token::TOKEN_TYPES[:CALL])
    
    if @current_token.type != Token::TOKEN_TYPES[:IDENTIFIER]
      error("Expected function name")
    end
    function_name = @current_token.value
    advance
    
    arguments = []
    
    # Handle different call syntaxes
    if @current_token.type == Token::TOKEN_TYPES[:WITH]
      advance # consume 'with'
      arguments = parse_argument_list
    elsif @current_token.type == Token::TOKEN_TYPES[:LPAREN]
      advance # consume '('
      if @current_token.type != Token::TOKEN_TYPES[:RPAREN]
        arguments = parse_argument_list
      end
      eat(Token::TOKEN_TYPES[:RPAREN])
    elsif @current_token.type == Token::TOKEN_TYPES[:WHICH]
      advance # consume 'which'
      eat(Token::TOKEN_TYPES[:REQUIRES])
      eat(Token::TOKEN_TYPES[:COLON])
      arguments = parse_argument_list
    end
    
    FunctionCallNode.new(function_name, arguments)
  end

  def parse_argument_list
    arguments = []
    
    loop do
      arguments << expression
      
      if @current_token.type == Token::TOKEN_TYPES[:COMMA]
        advance # consume ','
      else
        break
      end
    end
    
    arguments
  end

  # Grammar: return_statement → 'return' expression?
  def parse_return_statement
    eat(Token::TOKEN_TYPES[:RETURN])
    
    # Check if there's an expression to return
    if @current_token.type != Token::TOKEN_TYPES[:RBRACE] &&
       @current_token.type != Token::TOKEN_TYPES[:END] &&
       @current_token.type != Token::TOKEN_TYPES[:EOF]
      expression_value = expression
      ReturnNode.new(expression_value)
    else
      ReturnNode.new(nil)
    end
  end
end