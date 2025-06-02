require_relative 'token'
require_relative 'ast_nodes'

# Parser class for parsing Patlang source code with ambiguous token resolution
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
      @current_token = nil
    end
  end

  def eat(expected_type)
    if @current_token && @current_token.type == expected_type
      advance
    else
      error("Expected #{expected_type}, got #{@current_token&.type}")
    end
  end

  def peek(offset = 1)
    peek_index = @current_token_index + offset
    if peek_index < @tokens.length
      @tokens[peek_index]
    else
      nil
    end
  end

  # AMBIGUOUS TOKEN RESOLUTION - Core logic for resolving context-dependent tokens
  def resolve_ambiguous_identifier(token)
    return token unless token.type == Token::TOKEN_TYPES[:IDENTIFIER]
    
    # Check if this identifier is part of a function definition phrase
    if token.value == "make"
      # Look ahead to see if this is "make a function called"
      if peek(1)&.type == Token::TOKEN_TYPES[:IDENTIFIER] && peek(1)&.value == "a" &&
         peek(2)&.type == Token::TOKEN_TYPES[:IDENTIFIER] && peek(2)&.value == "function" &&
         peek(3)&.type == Token::TOKEN_TYPES[:IDENTIFIER] && peek(3)&.value == "called"
        # This is a function definition, transform token
        return Token.new(Token::TOKEN_TYPES[:MAKE], "make")
      end
    end
    
    # Check for assignment context: identifier followed by =
    if peek(1)&.type == Token::TOKEN_TYPES[:ASSIGN]
      # This is a variable assignment, keep as identifier
      return token
    end
    
    # Default: keep as identifier
    return token
  end

  # Enhanced parse method with ambiguous token resolution
  def parse
    resolve_all_ambiguous_tokens
    program
  end

  def resolve_all_ambiguous_tokens
    # Pre-process all tokens to resolve ambiguous contexts
    resolved_tokens = []
    i = 0
    
    while i < @tokens.length
      token = @tokens[i]
      
      if token.type == Token::TOKEN_TYPES[:IDENTIFIER]
        # Handle function definition phrases
        if token.value == "make" && 
           i + 3 < @tokens.length &&
           @tokens[i + 1].type == Token::TOKEN_TYPES[:IDENTIFIER] && @tokens[i + 1].value == "a" &&
           @tokens[i + 2].type == Token::TOKEN_TYPES[:IDENTIFIER] && @tokens[i + 2].value == "function" &&
           @tokens[i + 3].type == Token::TOKEN_TYPES[:IDENTIFIER] && @tokens[i + 3].value == "called"
          
          # Replace the phrase with proper function tokens
          resolved_tokens << Token.new(Token::TOKEN_TYPES[:MAKE], "make")
          resolved_tokens << Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "a")  # Skip this one actually
          resolved_tokens << Token.new(Token::TOKEN_TYPES[:FUNCTION], "function")
          resolved_tokens << Token.new(Token::TOKEN_TYPES[:CALLED], "called")
          i += 4
          next
        end
      end
      
      resolved_tokens << token
      i += 1
    end
    
    @tokens = resolved_tokens
    @current_token_index = 0
    @current_token = @tokens[0] if @tokens.length > 0
  end

  # Grammar: program → statement*
  def program
    statements = []
    while @current_token
      stmt = statement
      statements << stmt if stmt
    end
    return statements.length == 1 ? statements[0] : BlockNode.new(statements)
  end

  # Grammar: statement → assignment | expression | function_definition | function_call | control_flow
  def statement
    return nil unless @current_token

    case @current_token.type
    when Token::TOKEN_TYPES[:MAKE]
      return parse_function_definition
    when Token::TOKEN_TYPES[:CALL]
      return parse_function_call
    when Token::TOKEN_TYPES[:IF]
      return parse_if_statement
    when Token::TOKEN_TYPES[:WHILE]
      return parse_while_statement
    when Token::TOKEN_TYPES[:RETURN]
      return parse_return_statement
    when Token::TOKEN_TYPES[:PRINT]
      return parse_print_statement
    when Token::TOKEN_TYPES[:IDENTIFIER]
      # Check for assignment
      if peek(1)&.type == Token::TOKEN_TYPES[:ASSIGN]
        return parse_assignment
      else
        return expression
      end
    else
      return expression
    end
  end

  # Grammar: assignment → IDENTIFIER '=' expression
  def parse_assignment
    var_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    eat(Token::TOKEN_TYPES[:ASSIGN])
    value = expression
    return AssignmentNode.new(var_name, value)
  end

  # Grammar: function_definition → 'make' 'a' 'function' 'called' IDENTIFIER parameter_list? '{' statement* '}'
  def parse_function_definition
    eat(Token::TOKEN_TYPES[:MAKE])
    
    # Skip 'a' if present
    if @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER] && @current_token.value == "a"
      advance
    end
    
    eat(Token::TOKEN_TYPES[:FUNCTION])
    eat(Token::TOKEN_TYPES[:CALLED])
    
    function_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    # Parse parameters if present
    parameters = []
    return_type = nil
    
    if @current_token&.type == Token::TOKEN_TYPES[:TAKES]
      eat(Token::TOKEN_TYPES[:TAKES])
      eat(Token::TOKEN_TYPES[:COLON]) if @current_token&.type == Token::TOKEN_TYPES[:COLON]
      
      # Parse parameter list
      loop do
        break unless @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER]
        
        param_name = @current_token.value
        eat(Token::TOKEN_TYPES[:IDENTIFIER])
        
        parameters << ParameterNode.new(param_name)
        
        if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
          eat(Token::TOKEN_TYPES[:COMMA])
        else
          break
        end
      end
    end
    
    # Parse return type if present
    if @current_token&.type == Token::TOKEN_TYPES[:RETURNS]
      eat(Token::TOKEN_TYPES[:RETURNS])
      eat(Token::TOKEN_TYPES[:COLON]) if @current_token&.type == Token::TOKEN_TYPES[:COLON]
      return_type = @current_token.value
      eat(Token::TOKEN_TYPES[:IDENTIFIER])
    end
    
    # Parse function body
    eat(Token::TOKEN_TYPES[:LBRACE])
    
    body_statements = []
    while @current_token && @current_token.type != Token::TOKEN_TYPES[:RBRACE]
      stmt = statement
      body_statements << stmt if stmt
    end
    
    eat(Token::TOKEN_TYPES[:RBRACE])
    
    body = body_statements.length == 1 ? body_statements[0] : BlockNode.new(body_statements)
    
    return FunctionDefinitionNode.new(function_name, parameters, body, return_type)
  end

  # Grammar: function_call → 'call' IDENTIFIER ('with' argument_list)?
  def parse_function_call
    eat(Token::TOKEN_TYPES[:CALL])
    
    function_name = @current_token.value
    eat(Token::TOKEN_TYPES[:IDENTIFIER])
    
    arguments = []
    
    # Handle different function call syntaxes
    if @current_token&.type == Token::TOKEN_TYPES[:LPAREN]
      # Parentheses syntax: call func(arg1, arg2)
      eat(Token::TOKEN_TYPES[:LPAREN])
      
      unless @current_token&.type == Token::TOKEN_TYPES[:RPAREN]
        loop do
          arguments << expression
          
          if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
            eat(Token::TOKEN_TYPES[:COMMA])
          else
            break
          end
        end
      end
      
      eat(Token::TOKEN_TYPES[:RPAREN])
    elsif @current_token&.type == Token::TOKEN_TYPES[:WITH]
      # With syntax: call func with arg1, arg2
      eat(Token::TOKEN_TYPES[:WITH])
      
      loop do
        arguments << expression
        
        if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
          eat(Token::TOKEN_TYPES[:COMMA])
        else
          break
        end
      end
    elsif @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER] && @current_token.value == "which"
      # Goal-oriented syntax: call func which requires: arg1, arg2
      advance # skip 'which'
      if @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER] && @current_token.value == "requires"
        advance # skip 'requires'
        eat(Token::TOKEN_TYPES[:COLON]) if @current_token&.type == Token::TOKEN_TYPES[:COLON]
        
        loop do
          arguments << expression
          
          if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
            eat(Token::TOKEN_TYPES[:COMMA])
          else
            break
          end
        end
      end
    end
    
    return FunctionCallNode.new(function_name, arguments)
  end

  # Grammar: return_statement → 'return' expression?
  def parse_return_statement
    eat(Token::TOKEN_TYPES[:RETURN])
    
    if @current_token && 
       @current_token.type != Token::TOKEN_TYPES[:RBRACE] &&
       @current_token.type != Token::TOKEN_TYPES[:END] &&
       @current_token.type != Token::TOKEN_TYPES[:ELSE] &&
       @current_token.type != Token::TOKEN_TYPES[:ELSIF]
      
      expr = expression
      return ReturnNode.new(expr)
    else
      return ReturnNode.new(nil)
    end
  end

  # Grammar: print_statement → 'print' expression
  def parse_print_statement
    eat(Token::TOKEN_TYPES[:PRINT])
    expr = expression
    return PrintNode.new(expr)
  end

  # Grammar: if_statement → 'if' expression 'then' statement ('else' statement)? 'end'
  def parse_if_statement
    eat(Token::TOKEN_TYPES[:IF])
    condition = expression
    eat(Token::TOKEN_TYPES[:THEN])
    
    then_statements = []
    while @current_token && 
          @current_token.type != Token::TOKEN_TYPES[:ELSE] && 
          @current_token.type != Token::TOKEN_TYPES[:END]
      stmt = statement
      then_statements << stmt if stmt
    end
    
    then_branch = then_statements.length == 1 ? then_statements[0] : BlockNode.new(then_statements)
    
    else_branch = nil
    if @current_token&.type == Token::TOKEN_TYPES[:ELSE]
      eat(Token::TOKEN_TYPES[:ELSE])
      
      else_statements = []
      while @current_token && @current_token.type != Token::TOKEN_TYPES[:END]
        stmt = statement
        else_statements << stmt if stmt
      end
      
      else_branch = else_statements.length == 1 ? else_statements[0] : BlockNode.new(else_statements)
    end
    
    eat(Token::TOKEN_TYPES[:END])
    
    return IfNode.new(condition, then_branch, else_branch)
  end

  # Grammar: while_statement → 'while' expression 'do' statement* 'end'
  def parse_while_statement
    eat(Token::TOKEN_TYPES[:WHILE])
    condition = expression
    eat(Token::TOKEN_TYPES[:DO])
    
    body_statements = []
    while @current_token && @current_token.type != Token::TOKEN_TYPES[:END]
      stmt = statement
      body_statements << stmt if stmt
    end
    
    body = body_statements.length == 1 ? body_statements[0] : BlockNode.new(body_statements)
    
    eat(Token::TOKEN_TYPES[:END])
    
    return WhileNode.new(condition, body)
  end

  # Rest of expression parsing methods remain the same...
  def expression
    logical_or
  end

  def logical_or
    left = logical_and
    
    while @current_token&.type == Token::TOKEN_TYPES[:OR]
      op = @current_token.type
      advance
      right = logical_and
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def logical_and
    left = equality
    
    while @current_token&.type == Token::TOKEN_TYPES[:AND]
      op = @current_token.type
      advance
      right = equality
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def equality
    left = comparison
    
    while @current_token&.type == Token::TOKEN_TYPES[:EQUAL] ||
          @current_token&.type == Token::TOKEN_TYPES[:NOT_EQUAL]
      op = @current_token.type
      advance
      right = comparison
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def comparison
    left = arithmetic
    
    while @current_token&.type == Token::TOKEN_TYPES[:LESS] ||
          @current_token&.type == Token::TOKEN_TYPES[:LESS_EQUAL] ||
          @current_token&.type == Token::TOKEN_TYPES[:GREATER] ||
          @current_token&.type == Token::TOKEN_TYPES[:GREATER_EQUAL]
      op = @current_token.type
      advance
      right = arithmetic
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def arithmetic
    left = term
    
    while @current_token&.type == Token::TOKEN_TYPES[:PLUS] ||
          @current_token&.type == Token::TOKEN_TYPES[:MINUS]
      op = @current_token.type
      advance
      right = term
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def term
    left = postfix
    
    while @current_token&.type == Token::TOKEN_TYPES[:STAR] ||
          @current_token&.type == Token::TOKEN_TYPES[:SLASH] ||
          @current_token&.type == Token::TOKEN_TYPES[:PERCENT]
      op = @current_token.type
      advance
      right = postfix
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def postfix
    left = primary
    
    # Handle string methods
    while @current_token&.type == Token::TOKEN_TYPES[:DOT]
      advance # consume '.'
      
      if @current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER]
        method_name = @current_token.value
        advance
        
        if @current_token&.type == Token::TOKEN_TYPES[:LPAREN]
          # Method call with arguments
          advance # consume '('
          
          arguments = []
          unless @current_token&.type == Token::TOKEN_TYPES[:RPAREN]
            loop do
              arguments << expression
              
              if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
                advance
              else
                break
              end
            end
          end
          
          eat(Token::TOKEN_TYPES[:RPAREN])
          left = MethodCallNode.new(left, method_name, arguments)
        else
          # Method call without arguments
          left = MethodCallNode.new(left, method_name, [])
        end
      else
        error("Expected method name after '.'")
      end
    end
    
    left
  end

  def primary
    token = @current_token
    
    if token.type == Token::TOKEN_TYPES[:NUMBER]
      advance
      return NumberNode.new(token.value.to_f)
    elsif token.type == Token::TOKEN_TYPES[:STRING]
      advance
      return StringNode.new(token.value)
    elsif token.type == Token::TOKEN_TYPES[:TRUE] || token.type == Token::TOKEN_TYPES[:FALSE]
      return parse_boolean
    elsif token.type == Token::TOKEN_TYPES[:IDENTIFIER]
      # This could be a variable reference or function call
      if peek(1)&.type == Token::TOKEN_TYPES[:LPAREN]
        # This looks like a function call
        function_name = token.value
        advance
        eat(Token::TOKEN_TYPES[:LPAREN])
        
        arguments = []
        unless @current_token&.type == Token::TOKEN_TYPES[:RPAREN]
          loop do
            arguments << expression
            
            if @current_token&.type == Token::TOKEN_TYPES[:COMMA]
              advance
            else
              break
            end
          end
        end
        
        eat(Token::TOKEN_TYPES[:RPAREN])
        return FunctionCallNode.new(function_name, arguments)
      else
        # Variable reference
        advance
        return VariableNode.new(token.value)
      end
    elsif token.type == Token::TOKEN_TYPES[:CALL]
      return parse_function_call
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
      error("Expected boolean")
    end
  end
end