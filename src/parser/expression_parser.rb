require_relative '../ast_nodes'

# Expression parsing module for handling arithmetic, logical, and comparison parsing
module ParserModules
  class ExpressionParser
    def initialize(parser)
      @parser = parser
    end

    def expression
      logical_or
    end

    def logical_or
      left = logical_and
      
      while @parser.current_token&.type == :OR
        op = @parser.current_token.value
        @parser.advance
        right = logical_and
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def logical_and
      left = equality
      
      while @parser.current_token&.type == :AND
        op = @parser.current_token.value
        @parser.advance
        right = equality
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def equality
      left = comparison
      
      while @parser.current_token&.type == :EQUAL ||
            @parser.current_token&.type == :NOT_EQUAL
        op = @parser.current_token.value
        @parser.advance
        right = comparison
        left = ComparisonNode.new(left, op, right)
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
      
      while @parser.current_token&.type == :PLUS ||
            @parser.current_token&.type == :MINUS
        op = @parser.current_token.value
        @parser.advance
        right = term
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def term
      left = unary
      
      while @parser.current_token&.type == :STAR ||
            @parser.current_token&.type == :SLASH ||
            @parser.current_token&.type == :PERCENT
        op = @parser.current_token.value
        @parser.advance
        right = unary
        left = BinaryOpNode.new(left, op, right)
      end
      
      left
    end

    def unary
      if @parser.current_token&.type == :MINUS
        op = @parser.current_token.value
        @parser.advance
        operand = unary
        return UnaryOpNode.new(op, operand)
      end
      
      postfix
    end

    def postfix
      left = primary
      
      # Handle bracket indexing and string methods
      loop do
        if @parser.current_token&.type == :LBRACKET
          @parser.advance # consume '['
          index = expression
          @parser.eat(:RBRACKET)
          left = IndexAccessNode.new(left, index)
        elsif @parser.current_token&.type == :DOT
          @parser.advance # consume '.'
          
          if @parser.current_token&.type == :IDENTIFIER
            method_name = @parser.current_token.value
            @parser.advance
            
            if @parser.current_token&.type == :LPAREN
              # Method call with arguments
              @parser.advance # consume '('
              
              arguments = []
              unless @parser.current_token&.type == :RPAREN
                loop do
                  arguments << expression
                  
                  if @parser.current_token&.type == :COMMA
                    @parser.advance
                  else
                    break
                  end
                end
              end
              
              @parser.eat(:RPAREN)
              left = MethodCallNode.new(left, method_name, arguments)
            else
              # Method call without arguments
              left = MethodCallNode.new(left, method_name, [])
            end
          else
            @parser.error("Expected method name after '.'")
          end
        else
          break
        end
      end
      
      left
    end

    def primary
      token = @parser.current_token
      
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
          @parser.eat(:LPAREN)
          
          arguments = []
          unless @parser.current_token&.type == :RPAREN
            loop do
              arguments << expression
              
              if @parser.current_token&.type == :COMMA
                @parser.advance
              else
                break
              end
            end
          end
          
          @parser.eat(:RPAREN)
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
        @parser.eat(:LPAREN)
        node = expression
        @parser.eat(:RPAREN)
        return node
      else
        @parser.error("Unexpected token in factor")
      end
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