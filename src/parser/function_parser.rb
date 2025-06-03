require_relative '../ast_nodes'

# Function parsing module for handling function definitions and calls
module ParserModules
  class FunctionParser
    def initialize(parser)
      @parser = parser
    end

    # Grammar: function_definition → 'make' ['a'] 'function' ['called'] IDENTIFIER parameter_list? '{' statement* '}'
    def parse_function_definition
      @parser.eat(:MAKE)
      
      # Skip 'a' if present (optional)
      if @parser.current_token&.type == :IDENTIFIER && @parser.current_token.value == "a"
        @parser.advance
      end
      
      @parser.eat(:FUNCTION)
      
      # Skip 'called' if present (optional)
      if @parser.current_token&.type == :CALLED
        @parser.advance
      end
      
      function_name = @parser.current_token.value
      @parser.eat(:IDENTIFIER)
      
      # Parse parameters if present
      parameters = []
      return_type = nil
      
      if @parser.current_token&.type == :TAKES
        @parser.eat(:TAKES)
        @parser.eat(:COLON) if @parser.current_token&.type == :COLON
        
        # Parse parameter list
        loop do
          break unless @parser.current_token&.type == :IDENTIFIER
          
          param_name = @parser.current_token.value
          @parser.eat(:IDENTIFIER)
          
          # Check for compound type (parameter-type syntax)
          param_type = nil
          if @parser.current_token&.type == :MINUS &&
             @parser.peek&.type == :IDENTIFIER
            @parser.eat(:MINUS)
            param_type = @parser.current_token.value
            @parser.eat(:IDENTIFIER)
          end
          
          parameters << ParameterNode.new(param_name, param_type)
          
          if @parser.current_token&.type == :COMMA
            @parser.eat(:COMMA)
          else
            break
          end
        end
      end
      
      # Parse return type if present
      if @parser.current_token&.type == :RETURNS
        @parser.eat(:RETURNS)
        @parser.eat(:COLON) if @parser.current_token&.type == :COLON
        return_type = @parser.current_token.value
        @parser.eat(:IDENTIFIER)
      end
      
      # Parse function body
      @parser.eat(:LBRACE)
      
      body_statements = []
      while @parser.current_token && @parser.current_token.type != :RBRACE
        stmt = @parser.statement
        body_statements << stmt if stmt
      end
      
      @parser.eat(:RBRACE)
      
      body = BlockNode.new(body_statements)
      
      return FunctionDefinitionNode.new(function_name, parameters, body, return_type)
    end

    # Grammar: function_call → 'call' IDENTIFIER ('with' argument_list)?
    def parse_function_call
      @parser.eat(:CALL)
      
      function_name = @parser.current_token.value
      @parser.eat(:IDENTIFIER)
      
      arguments = []
      
      # Handle different function call syntaxes
      if @parser.current_token&.type == :LPAREN
        # Parentheses syntax: call func(arg1, arg2)
        @parser.eat(:LPAREN)
        
        unless @parser.current_token&.type == :RPAREN
          loop do
            arguments << @parser.expression
            
            if @parser.current_token&.type == :COMMA
              @parser.eat(:COMMA)
            else
              break
            end
          end
        end
        
        @parser.eat(:RPAREN)
      elsif @parser.current_token&.type == :WITH
        # With syntax: call func with arg1, arg2
        @parser.eat(:WITH)
        
        loop do
          arguments << @parser.expression
          
          if @parser.current_token&.type == :COMMA
            @parser.eat(:COMMA)
          else
            break
          end
        end
      elsif @parser.current_token&.type == :IDENTIFIER && @parser.current_token.value == "which"
        # Goal-oriented syntax: call func which requires: arg1, arg2
        @parser.advance # skip 'which'
        if @parser.current_token&.type == :IDENTIFIER && @parser.current_token.value == "requires"
          @parser.advance # skip 'requires'
          @parser.eat(:COLON) if @parser.current_token&.type == :COLON
          
          loop do
            arguments << @parser.expression
            
            if @parser.current_token&.type == :COMMA
              @parser.eat(:COMMA)
            else
              break
            end
          end
        end
      end
      
      return FunctionCallNode.new(function_name, arguments)
    end
  end
end