<write_file>
<path>src/parser.rb</path>
<content>require_relative 'token'
require_relative 'ast_nodes'
require_relative 'ambiguous_token'

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
  def resolve_ambiguous_token(token, context_index = nil)
    return token unless token.is_a?(AmbiguousToken)
    
    # Check if this is an assignment context: identifier followed by =
    if context_index && context_index + 1 < @tokens.length && 
       @tokens[context_index + 1]&.type == :ASSIGN
      # This is a variable assignment, resolve to identifier
      identifier_possibility = token.resolve_to(:IDENTIFIER)
      return identifier_possibility if identifier_possibility
    end
    
    # Check if this is part of a function definition phrase
    if token.possible_types.include?(:MAKE)
      # Look ahead to see if this is "make a function called"
      if context_index && context_index + 3 < @tokens.length &&
         @tokens[context_index + 1]&.type == :IDENTIFIER && @tokens[context_index + 1]&.value == "a" &&
         @tokens[context_index + 2]&.type == :IDENTIFIER && @tokens[context_index + 2]&.value == "function" &&
         @tokens[context_index + 3]&.type == :IDENTIFIER && @tokens[context_index + 3]&.value == "called"
        # This is a function definition, resolve to MAKE
        make_possibility = token.resolve_to(:MAKE)
        return make_possibility if make_possibility
      end
    end
    
    # DEFAULT CASE: For variables and simple identifiers, resolve to IDENTIFIER
    # This handles cases like 'a = 5' where 'a' is ambiguous between type A and IDENTIFIER
    identifier_possibility = token.resolve_to(:IDENTIFIER)
    if identifier_possibility
      return identifier_possibility
    end
    
    # Fallback: use the first possibility
    return Token.new(token.possibilities.first[:type], token.possibilities.first[:value], token.position, token.line, token.column)
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
      
      if token.is_a?(AmbiguousToken)
        # Use the current context to resolve the ambiguous token
        resolved_token = resolve_ambiguous_token(token, i)
        resolved_tokens << resolved_token
        i += 1
      elsif token.type == :IDENTIFIER && token.value == "make"
        # Handle function definition phrases for regular identifiers
        if i + 3 < @tokens.length &&
           @tokens[i + 1].type == :IDENTIFIER && @tokens[i + 1].value == "a" &&
           @tokens[i + 2].type == :IDENTIFIER && @tokens[i + 2].value == "function" &&
           @tokens[i + 3].type == :IDENTIFIER && @tokens[i + 3].value == "called"
          
          # Replace the phrase with proper function tokens
          resolved_tokens << Token.new(:MAKE, "make")
          resolved_tokens << Token.new(:IDENTIFIER, "a")  # Skip this one actually
          resolved_tokens << Token.new(:FUNCTION, "function")
          resolved_tokens << Token.new(:CALLED, "called")
          i += 4
        else
          resolved_tokens << token
          i += 1
        end
      else
        resolved_tokens << token
        i += 1
      end
    end
    
    @tokens = resolved_tokens
    @current_token_index = 0
    @current_token = @tokens[0] if @tokens.length > 0
  end

  # Grammar: program → statement*
  def program
    statements = []
    while @current_token && @current_token.type != :EOF
      stmt = statement
      statements << stmt if stmt
    end
    return statements.length == 1 ? statements[0] : BlockNode.new(statements)
  end

  # Grammar: statement → assignment | expression | function_definition | function_call | control_flow
  def statement
    return nil unless @current_token

    case @current_token.type
    when :MAKE
      # CRITICAL FIX: Check for assignment BEFORE falling through to function definition
      if peek(1)&.type == :ASSIGN
        return parse_assignment
      elsif (peek(1)&.type == :IDENTIFIER && peek(1)&.value == "a" &&
            peek(2)&.type == :FUNCTION) ||
            (peek(1)&.type == :FUNCTION)
        # This is a function definition: "make [a] function [called]..."
        return parse_function_definition
      else
        # This is a standalone make variable reference
        return expression
      end
    when :CALL
      return parse_function_call
    when :IF
      return parse_if_statement
    when :WHILE
      return parse_while_statement
    when :RETURN
      return parse_return_statement
    when :PRINT
      return parse_print_statement
    when :IDENTIFIER
      # CRITICAL FIX: Check for assignment BEFORE falling through to expression
      if peek(1)&.type == :ASSIGN
        return parse_assignment
      else
        return expression
      end
    else
      return expression
    end
  end

  # Grammar: assignment → (IDENTIFIER | MAKE) '=' expression
  def parse_assignment
    var_name = @current_token.value
    # Accept both IDENTIFIER and MAKE tokens as variable names
    if @current_token.type == :IDENTIFIER
      eat(:IDENTIFIER)
    elsif @current_token.type == :MAKE
      eat(:MAKE)
    else
      error("Expected IDENTIFIER or MAKE for variable assignment")
    end
    eat(:ASSIGN)
    value = expression
    return AssignmentNode.new(var_name, value)
  end

  # Grammar: function_definition → 'make' ['a'] 'function' ['called'] IDENTIFIER parameter_list? '{' statement* '}'
  def parse_function_definition
    eat(:MAKE)
    
    # Skip 'a' if present (optional)
    if @current_token&.type == :IDENTIFIER && @current_token.value == "a"
      advance
    end
    
    eat(:FUNCTION)
    
    # Skip 'called' if present (optional)
    if @current_token&.type == :CALLED
      advance
    end
    
    function_name = @current_token.value
    eat(:IDENTIFIER)
    
    # Parse parameters if present
    parameters = []
    return_type = nil
    
    if @current_token&.type == :TAKES
      eat(:TAKES)
      eat(:COLON) if @current_token&.type == :COLON
      
      # Parse parameter list
      loop do
        break unless @current_token&.type == :IDENTIFIER
        
        param_name = @current_token.value
        eat(:IDENTIFIER)
        
        parameters << ParameterNode.new(param_name)
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        else
          break
        end
      end
    end
    
    # Parse return type if present
    if @current_token&.type == :RETURNS
      eat(:RETURNS)
      eat(:COLON) if @current_token&.type == :COLON
      return_type = @current_token.value
      eat(:IDENTIFIER)
    end
    
    # Parse function body
    eat(:LBRACE)
    
    body_statements = []
    while @current_token && @current_token.type != :RBRACE
      stmt = statement
      body_statements << stmt if stmt
    end
    
    eat(:RBRACE)
    
    body = body_statements.length == 1 ? body_statements[0] : BlockNode.new(body_statements)
    
    return FunctionDefinitionNode.new(function_name, parameters, body, return_type)
  end

  # Grammar: function_call → 'call' IDENTIFIER ('with' argument_list)?
  def parse_function_call
    eat(:CALL)
    
    function_name = @current_token.value
    eat(:IDENTIFIER)
    
    arguments = []
    
    # Handle different function call syntaxes
    if @current_token&.type == :LPAREN
      # Parentheses syntax: call func(arg1, arg2)
      eat(:LPAREN)
      
      unless @current_token&.type == :RPAREN
        loop do
          arguments << expression
          
          if @current_token&.type == :COMMA
            eat(:COMMA)
          else
            break
          end
        end
      end
      
      eat(:RPAREN)
    elsif @current_token&.type == :WITH
      # With syntax: call func with arg1, arg2
      eat(:WITH)
      
      loop do
        arguments << expression
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        else
          break
        end
      end
    elsif @current_token&.type == :IDENTIFIER && @current_token.value == "which"
      # Goal-oriented syntax: call func which requires: arg1, arg2
      advance # skip 'which'
      if @current_token&.type == :IDENTIFIER && @current_token.value == "requires"
        advance # skip 'requires'
        eat(:COLON) if @current_token&.type == :COLON
        
        loop do
          arguments << expression
          
          if @current_token&.type == :COMMA
            eat(:COMMA)
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
    eat(:RETURN)
    
    if @current_token && 
       @current_token.type != :RBRACE &&
       @current_token.type != :END &&
       @current_token.type != :ELSE &&
       @current_token.type != :ELSIF &&
       @current_token.type != :EOF
      
      expr = expression
      return ReturnNode.new(expr)
    else
      return ReturnNode.new(nil)
    end
  end

  # Grammar: print_statement → 'print' expression
  def parse_print_statement
    eat(:PRINT)
    expr = expression
    return PrintNode.new(expr)
  end

  # Grammar: if_statement → 'if' expression 'then' statement ('else' statement)? 'end'
  def parse_if_statement
    eat(:IF)
    condition = expression
    eat(:THEN)
    
    then_statements = []
    while @current_token && 
          @current_token.type != :ELSE && 
          @current_token.type != :END
      stmt = statement
      then_statements << stmt if stmt
    end
    
    then_branch = then_statements.length == 1 ? then_statements[0] : BlockNode.new(then_statements)
    
    else_branch = nil
    if @current_token&.type == :ELSE
      eat(:ELSE)
      
      else_statements = []
      while @current_token && @current_token.type != :END
        stmt = statement
        else_statements << stmt if stmt
      end
      
      else_branch = else_statements.length == 1 ? else_statements[0] : BlockNode.new(else_statements)
    end
    
    eat(:END)
    
    return IfNode.new(condition, then_branch, else_branch)
  end

  # Grammar: while_statement → 'while' expression 'do' statement* 'end'
  def parse_while_statement
    eat(:WHILE)
    condition = expression
    eat(:DO)
    
    body_statements = []
    while @current_token && @current_token.type != :END
      stmt = statement
      body_statements << stmt if stmt
    end
    
    body = body_statements.length == 1 ? body_statements[0] : BlockNode.new(body_statements)
    
    eat(:END)
    
    return WhileNode.new(condition, body)
  end

  # Rest of expression parsing methods remain the same...
  def expression
    logical_or
  end

  def logical_or
    left = logical_and
    
    while @current_token&.type == :OR
      op = @current_token.type
      advance
      right = logical_and
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def logical_and
    left = equality
    
    while @current_token&.type == :AND
      op = @current_token.type
      advance
      right = equality
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def equality
    left = comparison
    
    while @current_token&.type == :EQUAL ||
          @current_token&.type == :NOT_EQUAL
      op = @current_token.type
      advance
      right = comparison
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def comparison
    left = arithmetic
    
    while @current_token&.type == :LESS ||
          @current_token&.type == :LESS_EQUAL ||
          @current_token&.type == :GREATER ||
          @current_token&.type == :GREATER_EQUAL
      op = @current_token.type
      advance
      right = arithmetic
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def arithmetic
    left = term
    
    while @current_token&.type == :PLUS ||
          @current_token&.type == :MINUS
      op = @current_token.type
      advance
      right = term
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def term
    left = postfix
    
    while @current_token&.type == :STAR ||
          @current_token&.type == :SLASH ||
          @current_token&.type == :PERCENT ||
          @current_token&.type == :MODULO
      op = @current_token.type
      advance
      right = postfix
      left = BinaryOpNode.new(left, op, right)
    end
    
    left
  end

  def postfix
    left = primary
    
    # CRITICAL FIX: Handle both method calls AND string indexing
    while @current_token&.type == :DOT || @current_token&.type == :LBRACKET
      if @current_token.type == :DOT
        # Method call
        advance # consume '.'
        
        if @current_token&.type == :IDENTIFIER
          method_name = @current_token.value
          advance
          
          if @current_token&.type == :LPAREN
            # Method call with arguments
            advance # consume '('
            
            arguments = []
            unless @current_token&.type == :RPAREN
              loop do
                arguments << expression
                
                if @current_token&.type == :COMMA
                  advance
                else
                  break
                end
              end
            end
            
            eat(:RPAREN)
            left = MethodCallNode.new(left, method_name, arguments)
          else
            # Method call without arguments
            left = MethodCallNode.new(left, method_name, [])
          end
        else
          error("Expected method name after '.'")
        end
      elsif @current_token.type == :LBRACKET
        # String indexing: string[index]
        advance # consume '['
        index = expression
        eat(:RBRACKET)
        left = IndexAccessNode.new(left, index)
      end
    end
    
    left
  end

  def primary
    token = @current_token
    
    if token.type == :NUMBER
      advance
      return NumberNode.new(token.value.to_f)
    elsif token.type == :STRING
      advance
      return StringNode.new(token.value)
    elsif token.type == :TRUE || token.type == :FALSE
      return parse_boolean
    elsif token.type == :IDENTIFIER
      # This could be a variable reference or function call
      if peek(1)&.type == :LPAREN
        # This looks like a function call
        function_name = token.value
        advance
        eat(:LPAREN)
        
        arguments = []
        unless @current_token&.type == :RPAREN
          loop do
            arguments << expression
            
            if @current_token&.type == :COMMA
              advance
            else
              break
            end
          end
        end
        
        eat(:RPAREN)
        return FunctionCallNode.new(function_name, arguments)
      else
        # Variable reference
        advance
        return VariableNode.new(token.value)
      end
    elsif token.type == :MAKE
      # MAKE token used as variable reference (not function definition)
      advance
      return VariableNode.new(token.value)
    elsif token.type == :CALL
      return parse_function_call
    elsif token.type == :FUNCTION
      # FUNCTION token used as variable reference (not function definition)
      advance
      return VariableNode.new(token.value)
    elsif token.type == :CALLED
      # CALLED token used as variable reference (not function definition)
      advance
      return VariableNode.new(token.value)
    elsif token.type == :TAKES
      # TAKES token used as variable reference (not function definition)
      advance
      return VariableNode.new(token.value)
    elsif token.type == :RETURNS
      # RETURNS token used as variable reference (not function definition)
      advance
      return VariableNode.new(token.value)
    elsif token.type == :LPAREN
      eat(:LPAREN)
      node = expression
      eat(:RPAREN)
      return node
    elsif token.type == :MINUS
      # CRITICAL FIX: Handle unary minus (negative numbers)
      advance
      operand = primary
      return UnaryOpNode.new(:MINUS, operand)
    else
      error("Unexpected token in factor")
    end
  end

  # Grammar: boolean → 'true' | 'false'
  def parse_boolean
    token = @current_token
    
    if token.type == :TRUE
      eat(:TRUE)
      return BooleanNode.new(true)
    elsif token.type == :FALSE
      eat(:FALSE)
      return BooleanNode.new(false)
    else
      error("Expected boolean")
    end
  end
end
</content>
</write_file>