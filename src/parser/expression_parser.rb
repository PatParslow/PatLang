require_relative '../ast_nodes'
require_relative 'parser_timeout_protection'

# Expression parsing module for handling arithmetic, logical, and comparison parsing
module ParserModules
  class ExpressionParser
    include TimeoutProtection
    
    def initialize(parser)
      @parser = parser
    end

    def expression
      # Add error recovery for expression parsing with timeout protection
      return create_error_placeholder("Empty expression") if @parser.current_token.nil?
      
      with_expression_timeout("expression parsing") do
        begin
          logical_or
        rescue ParseError => e
          # Error recovery: return a placeholder node with error info
          create_error_placeholder("Expression parse error: #{e.message}")
        rescue EmergencyTimeout::TimeoutError => e
          create_error_placeholder("Expression timeout: #{e.message}")
        end
      end
    end

    def logical_or
      left = logical_and
      return left unless left
      
      circuit_breaker = create_circuit_breaker(50)
      
      while @parser.current_token&.type == :OR
        circuit_breaker.check_iteration(@parser.current_token_index)
        
        op = @parser.current_token.value
        @parser.advance
        
        # Error recovery for incomplete logical expressions
        if @parser.current_token.nil?
          return create_error_placeholder("Incomplete logical OR expression")
        end
        
        right = logical_and
        return left unless right # If right side fails, return left side
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    rescue EmergencyTimeout::TimeoutError => e
      create_error_placeholder("Logical OR timeout: #{e.message}")
    end

    def logical_and
      left = equality
      return left unless left
      
      circuit_breaker = create_circuit_breaker(50)
      
      while @parser.current_token&.type == :AND
        circuit_breaker.check_iteration(@parser.current_token_index)
        
        op = @parser.current_token.value
        @parser.advance
        
        # Error recovery for incomplete logical expressions
        if @parser.current_token.nil?
          return create_error_placeholder("Incomplete logical AND expression")
        end
        
        right = equality
        return left unless right # If right side fails, return left side
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    rescue EmergencyTimeout::TimeoutError => e
      create_error_placeholder("Logical AND timeout: #{e.message}")
    end

    def equality
      left = type_annotation
      
      while @parser.current_token&.type == :EQUAL ||
            @parser.current_token&.type == :NOT_EQUAL
        op = @parser.current_token.value
        @parser.advance
        right = type_annotation
        left = ComparisonNode.new(left, op, right)
      end
      
      left
    end

    # Handle type annotations like "data :: Object"
    def type_annotation
      left = comparison
      
      if @parser.current_token&.type == :DOUBLE_COLON
        op = @parser.current_token.value
        @parser.advance
        right = comparison
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def comparison
      left = arithmetic
      
      while @parser.current_token&.type == :LESS ||
            @parser.current_token&.type == :LESS_EQUAL ||
            @parser.current_token&.type == :GREATER ||
            @parser.current_token&.type == :GREATER_EQUAL
        op = @parser.current_token.value
        @parser.advance
        right = arithmetic
        left = ComparisonNode.new(left, op, right)
      end
      
      left
    end

    def arithmetic
      left = term
      return left unless left
      
      circuit_breaker = create_circuit_breaker(50)
      
      while @parser.current_token&.type == :PLUS ||
            @parser.current_token&.type == :MINUS
        circuit_breaker.check_iteration(@parser.current_token_index)
        
        op = @parser.current_token.value
        @parser.advance
        
        # Error recovery for incomplete arithmetic expressions
        if @parser.current_token.nil?
          return create_error_placeholder("Incomplete arithmetic expression")
        end
        
        right = term
        return left unless right # If right side fails, return left side
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    rescue EmergencyTimeout::TimeoutError => e
      create_error_placeholder("Arithmetic timeout: #{e.message}")
    end

    def term
      left = unary
      return left unless left
      
      circuit_breaker = create_circuit_breaker(50)
      
      while @parser.current_token&.type == :STAR ||
            @parser.current_token&.type == :SLASH ||
            @parser.current_token&.type == :PERCENT
        circuit_breaker.check_iteration(@parser.current_token_index)
        
        op = @parser.current_token.value
        @parser.advance
        
        # Error recovery for incomplete term expressions
        if @parser.current_token.nil?
          return create_error_placeholder("Incomplete term expression")
        end
        
        right = unary
        return left unless right # If right side fails, return left side
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    rescue EmergencyTimeout::TimeoutError => e
      create_error_placeholder("Term timeout: #{e.message}")
    end

    def unary
      if @parser.current_token&.type == :MINUS
        op = @parser.current_token.value
        @parser.advance
        operand = unary
        return UnaryOpNode.new(op, operand)
      end
      
      exponentiation
    end

    def exponentiation
      left = postfix
      
      # Right-associative exponentiation (2^3^2 = 2^(3^2) = 2^9 = 512)
      if @parser.current_token&.type == :CARET
        op = @parser.current_token.value
        @parser.advance
        right = exponentiation  # Right-associative
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def postfix
      left = primary
      return left unless left
      
      begin
        # CRITICAL FIX: Handle bracket indexing and string methods with comprehensive protection
        circuit_breaker = create_circuit_breaker(20) # Even more aggressive limit
        
        loop do
          break unless @parser.current_token
          circuit_breaker.check_iteration(@parser.current_token_index)
          
          current_token_type = @parser.current_token.type
          
          if current_token_type == :LPAREN
            # Direct function call like fact(args) with error recovery
            @parser.advance # consume '('
            
            arguments = []
            until @parser.current_token&.type == :RPAREN
              if @parser.current_token.nil?
                # Error recovery: incomplete function call
                return create_error_placeholder("Incomplete function call - missing closing parenthesis")
              end
              
              arg = expression
              arguments << arg if arg
              
              if @parser.current_token&.type == :COMMA
                @parser.advance
              elsif @parser.current_token&.type != :RPAREN
                if @parser.current_token.nil?
                  return create_error_placeholder("Incomplete function call arguments")
                end
                # Instead of raising error, return error placeholder
                return create_error_placeholder("Expected ',' or ')' in argument list")
              end
            end
            
            if @parser.current_token&.type == :RPAREN
              @parser.advance
            else
              return create_error_placeholder("Missing closing parenthesis in function call")
            end
            
            # Handle different node types that could be function names
            function_name = case left
                           when VariableNode
                             left.value
                           when StringNode
                             left.value
                           else
                             left.respond_to?(:value) ? left.value : left.to_s
                           end
            left = FunctionCallNode.new(function_name, arguments)
          elsif current_token_type == :LBRACKET
            @parser.advance # consume '['
            
            if @parser.current_token.nil?
              return create_error_placeholder("Incomplete array index - missing expression")
            end
            
            index = expression
            if @parser.current_token&.type == :RBRACKET
              @parser.advance
            else
              return create_error_placeholder("Missing closing bracket in array access")
            end
            left = IndexAccessNode.new(left, index)
          elsif current_token_type == :DOT
            @parser.advance # consume '.'
            
            if @parser.current_token.nil?
              return create_error_placeholder("Incomplete method call - missing method name")
            end
            
            if @parser.current_token.type == :IDENTIFIER
              method_name = @parser.current_token.value
              @parser.advance
              
              if @parser.current_token&.type == :LPAREN
                # Method call with arguments
                @parser.advance # consume '('
                
                arguments = []
                unless @parser.current_token&.type == :RPAREN
                  arg_circuit_breaker = create_circuit_breaker(50)
                  loop do
                    arg_circuit_breaker.check_iteration(@parser.current_token_index)
                    
                    if @parser.current_token.nil?
                      return create_error_placeholder("Incomplete method call arguments")
                    end
                    
                    arg = expression
                    arguments << arg if arg
                    
                    if @parser.current_token&.type == :COMMA
                      @parser.advance
                    else
                      break
                    end
                  end
                end
                
                if @parser.current_token&.type == :RPAREN
                  @parser.advance
                else
                  return create_error_placeholder("Missing closing parenthesis in method call")
                end
                left = MethodCallNode.new(left, method_name, arguments)
              else
                # Method call without arguments
                left = MethodCallNode.new(left, method_name, [])
              end
            else
              return create_error_placeholder("Expected method name after '.'")
            end
          else
            break
          end
        end
        
        left
      rescue EmergencyTimeout::TimeoutError => e
        create_error_placeholder("Postfix operation timeout: #{e.message}")
      end
    end

    def primary
      token = @parser.current_token
      
      # Error recovery for nil token
      return create_error_placeholder("Unexpected end of input") if token.nil?
      
      if token.type == :NUMBER
        @parser.advance
        return NumberNode.new(token.value.to_f)
      elsif token.type == :STRING
        @parser.advance
        return StringNode.new(token.value)
      elsif token.type == :TRUE || token.type == :FALSE
        return parse_boolean
      elsif token.type == :IDENTIFIER
        # This could be a variable reference or function call
        if @parser.peek(1)&.type == :LPAREN
          # This looks like a function call
          function_name = token.value
          @parser.advance
          
          if @parser.current_token&.type == :LPAREN
            @parser.advance # consume '('
          else
            return create_error_placeholder("Expected '(' for function call")
          end
          
          arguments = []
          unless @parser.current_token&.type == :RPAREN
            arg_circuit_breaker = create_circuit_breaker(50)
            loop do
              arg_circuit_breaker.check_iteration(@parser.current_token_index)
              
              if @parser.current_token.nil?
                return create_error_placeholder("Incomplete function call arguments")
              end
              
              arg = expression
              arguments << arg if arg
              
              if @parser.current_token&.type == :COMMA
                @parser.advance
              else
                break
              end
            end
          end
          
          if @parser.current_token&.type == :RPAREN
            @parser.advance
          else
            return create_error_placeholder("Missing closing parenthesis in function call")
          end
          return FunctionCallNode.new(function_name, arguments)
        else
          # Variable reference
          @parser.advance
          return VariableNode.new(token.value)
        end
      elsif token.type == :MAKE
        # MAKE token used as variable reference (not function definition)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :CALL
        return @parser.parse_function_call
      elsif token.type == :FUNCTION
        # FUNCTION token used as variable reference (not function definition)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :CALLED
        # CALLED token used as variable reference (not function definition)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :TAKES
        # TAKES token used as variable reference (not function definition)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :RETURNS
        # RETURNS token used as variable reference (not function definition)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :LPAREN
        @parser.advance # consume '('
        
        # Handle empty parentheses as error recovery
        if @parser.current_token&.type == :RPAREN
          @parser.advance
          return create_error_placeholder("Empty parentheses expression")
        end
        
        if @parser.current_token.nil?
          return create_error_placeholder("Incomplete parenthesized expression")
        end
        
        node = expression
        if @parser.current_token&.type == :RPAREN
          @parser.advance
        else
          return create_error_placeholder("Missing closing parenthesis")
        end
        return node
      elsif token.type == :LBRACE
        # Handle LBRACE in expression context - could be block expression or object literal
        @parser.advance # consume '{'
        statements = []
        
        # Parse statements inside the block until we hit RBRACE
        until @parser.current_token&.type == :RBRACE
          if @parser.current_token.nil?
            return create_error_placeholder("Incomplete block - missing '}'")
          end
          
          stmt = expression
          statements << stmt if stmt
          
          # Optional semicolon or newline between statements
          if @parser.current_token&.type == :SEMICOLON
            @parser.advance
          end
        end
        
        if @parser.current_token&.type == :RBRACE
          @parser.advance
        else
          return create_error_placeholder("Missing closing brace in block")
        end
        return BlockNode.new(statements)
      elsif token.type == :COLON
        # Handle COLON in expression context - could be type annotation or label
        @parser.advance # consume ':'
        
        # For now, treat as a simple token that can be referenced
        # This handles cases where colon appears in expressions
        return VariableNode.new(":")
      elsif token.type == :RETURN
        # Handle RETURN keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :IF
        # Handle IF keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :WHILE
        # Handle WHILE keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :COMMA
        # Handle COMMA as variable reference in expression context
        @parser.advance
        return VariableNode.new(",")
      elsif token.type == :ASSIGN
        # Handle ASSIGN as variable reference in expression context
        @parser.advance
        return VariableNode.new("=")
      elsif token.type == :THEN
        # Handle THEN keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :END
        # Handle END keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :ELSE
        # Handle ELSE keyword as variable reference in expression context
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :FACT
        # Handle FACT keyword as variable reference in expression context (for fact() calls)
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :PURSUE
        # Handle PURSUE keyword as function name for goal pursuit
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :QUERY
        # Handle QUERY keyword as function name for logic queries
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :GOAL
        # Handle GOAL keyword as identifier in expressions
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :DOUBLE_COLON
        # Handle DOUBLE_COLON in expression context - this creates a type annotation node
        # This allows expressions like "user.value :: String" to be parsed
        @parser.advance
        return VariableNode.new("::")
      elsif token.type == :WHERE
        # Handle WHERE keyword as identifier in query expressions
        @parser.advance
        return VariableNode.new(token.value)
      elsif token.type == :EOF
        # Handle EOF token gracefully
        return create_error_placeholder("Unexpected end of input")
      elsif [:PLUS, :MINUS, :STAR, :SLASH, :PERCENT].include?(token.type)
        # Handle operators appearing where primary expressions are expected
        return create_error_placeholder("Unexpected operator '#{token.value}' in expression")
      elsif [:RPAREN, :RBRACKET, :RBRACE].include?(token.type)
        # Handle unmatched closing tokens
        return create_error_placeholder("Unexpected closing '#{token.value}'")
      elsif token.type == :DOT
        # Handle dot without preceding expression
        return create_error_placeholder("Unexpected '.' at start of expression")
      elsif token.type == :LBRACKET
        # Handle array literals and bracket expressions
        return create_error_placeholder("Array literals not supported in this context")
      else
        return create_error_placeholder("Unexpected token '#{token.value}' in expression")
      end
    end
    
    private
    
    def create_error_placeholder(message)
      # Create a special error node that doesn't crash the parser
      # This allows parsing to continue and provides better error reporting
      ErrorNode.new(message)
    end

    # Grammar: boolean → 'true' | 'false'
    def parse_boolean
      token = @parser.current_token
      
      if token.type == :TRUE
        @parser.eat(:TRUE)
        return BooleanNode.new(true)
      elsif token.type == :FALSE
        @parser.eat(:FALSE)
        return BooleanNode.new(false)
      else
        @parser.error("Expected boolean")
      end
    end
  end
end