require_relative '../ast_nodes'

# Function parsing module for handling function definitions and calls
module ParserModules
  class FunctionParser
    def initialize(parser)
      @parser = parser
      @debug = ENV['PATLANG_DEBUG'] == 'true' || ENV['DEBUG'] == 'true'
    end

    # Debug print method for conditional debug output
    def debug_print(message)
      return unless @debug
      puts "[FunctionParser DEBUG] #{message}"
    end

    # Grammar: function_definition → 'make' ['a'] 'function' ['called'] IDENTIFIER parameter_list? '{' statement* '}'
    def parse_function_definition
      begin
        @parser.eat(:MAKE)
        
        # Skip 'a' if present (optional)
        if @parser.current_token&.type == :IDENTIFIER && @parser.current_token.value == "a"
          @parser.advance
        end
        
        if @parser.current_token.nil? || @parser.current_token.type != :FUNCTION
          return @parser.safe_error("Expected 'function' after 'make'")
        end
        
        @parser.eat(:FUNCTION)
        
        # Skip 'called' if present (optional)
        if @parser.current_token&.type == :CALLED
          @parser.advance
        end
        
        if @parser.current_token.nil? || @parser.current_token.type != :IDENTIFIER
          @parser.syntax_error("Expected function name after 'function'")
        end
        
        function_name = @parser.current_token.value
        @parser.eat(:IDENTIFIER)
        
        # Parse parameters if present
        parameters = []
        return_type = nil
        
        if @parser.current_token&.type == :TAKES
          @parser.eat(:TAKES)
          @parser.eat(:COLON) if @parser.current_token&.type == :COLON
          
          # Parse parameter list with loop protection
          param_count = 0
          loop do
            break unless @parser.current_token&.type == :IDENTIFIER || @parser.current_token&.type == :MINUS
            break if param_count >= 50  # Safety limit
            
            # Check for missing parameter name (starts with type like "-string")
            if @parser.current_token&.type == :MINUS
              @parser.syntax_error("Expected parameter name before type annotation")
            end
            
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
            param_count += 1
            
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
          
          if @parser.current_token&.type == :IDENTIFIER
            return_type = @parser.current_token.value
            @parser.eat(:IDENTIFIER)
          else
            @parser.syntax_error("Expected return type after 'returns'")
          end
        end
        
        # Parse function body
        if @parser.current_token.nil? || @parser.current_token.type != :LBRACE
          @parser.syntax_error("Expected '{' to start function body")
        end
        
        @parser.eat(:LBRACE)
        
        body_statements = []
        loop_count = 0
        while @parser.current_token &&
              @parser.current_token.type != :RBRACE &&
              loop_count < 1000  # Safety limit
          stmt = @parser.statement
          body_statements << stmt if stmt
          loop_count += 1
        end
        
        if @parser.current_token&.type == :RBRACE
          @parser.eat(:RBRACE)
        else
          return @parser.safe_error("Missing '}' to close function body")
        end
        
        body = BlockNode.new(body_statements)
        
        return FunctionDefinitionNode.new(function_name, parameters, body, return_type)
      rescue ParseError => e
        @parser.safe_error("Function definition parse error: #{e.message}")
      end
    end

    # Grammar: function_call → 'call' IDENTIFIER ('with' argument_list)?
    def parse_function_call
      begin
        @parser.eat(:CALL)
        
        if @parser.current_token.nil? || @parser.current_token.type != :IDENTIFIER
          @parser.syntax_error("Expected function name after 'call'")
        end
        
        function_name = @parser.current_token.value
        @parser.eat(:IDENTIFIER)
        
        arguments = []
        
        # Handle different function call syntaxes with loop protection
        if @parser.current_token&.type == :LPAREN
          # Parentheses syntax: call func(arg1, arg2)
          @parser.eat(:LPAREN)
          
          unless @parser.current_token&.type == :RPAREN
            arg_count = 0
            loop do
              break if arg_count >= 50  # Safety limit
              break if @parser.current_token.nil?
              
              arguments << @parser.expression
              arg_count += 1
              
              if @parser.current_token&.type == :COMMA
                @parser.eat(:COMMA)
              else
                break
              end
            end
          end
          
          if @parser.current_token&.type == :RPAREN
            @parser.eat(:RPAREN)
          else
            return @parser.safe_error("Missing ')' in function call")
          end
        elsif @parser.current_token&.type == :WITH
          # With syntax: call func with arg1, arg2
          @parser.eat(:WITH)
          
          arg_count = 0
          loop do
            break if arg_count >= 50  # Safety limit
            break if @parser.current_token.nil?
            
            arguments << @parser.expression
            arg_count += 1
            
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
            
            arg_count = 0
            loop do
              break if arg_count >= 50  # Safety limit
              break if @parser.current_token.nil?
              
              arguments << @parser.expression
              arg_count += 1
              
              if @parser.current_token&.type == :COMMA
                @parser.eat(:COMMA)
              else
                break
              end
            end
          end
        end
        
        return FunctionCallNode.new(function_name, arguments)
      rescue ParseError => e
        @parser.safe_error("Function call parse error: #{e.message}")
      end
    end

    # Grammar: lambda_definition → 'lambda' parameter_list? '=>' expression | '{' statement* '}'
    def parse_lambda_definition
      debug_print("Parsing lambda definition")
      
      @parser.eat(:LAMBDA) if @parser.current_token&.type == :LAMBDA
      
      # Parse parameters if present
      parameters = []
      
      if @parser.current_token&.type == :LPAREN
        @parser.eat(:LPAREN)
        
        unless @parser.current_token&.type == :RPAREN
          loop do
            break unless @parser.current_token&.type == :IDENTIFIER
            
            param_name = @parser.current_token.value
            @parser.eat(:IDENTIFIER)
            
            # Check for type annotation
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
        
        @parser.eat(:RPAREN)
      elsif @parser.current_token&.type == :TAKES
        # Alternative parameter syntax: lambda takes: param1, param2
        @parser.eat(:TAKES)
        @parser.eat(:COLON) if @parser.current_token&.type == :COLON
        
        loop do
          break unless @parser.current_token&.type == :IDENTIFIER
          
          param_name = @parser.current_token.value
          @parser.eat(:IDENTIFIER)
          
          # Check for type annotation
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
      
      # Parse lambda body
      body = nil
      if @parser.current_token&.type == :ARROW ||
         (@parser.current_token&.type == :EQUALS && @parser.peek&.type == :GT)
        # Arrow function syntax: lambda => expression
        if @parser.current_token&.type == :EQUALS
          @parser.eat(:EQUALS)
          @parser.eat(:GT)
        else
          @parser.eat(:ARROW)
        end
        
        # Single expression body
        expression = @parser.expression
        body = BlockNode.new([ReturnNode.new(expression)])
      elsif @parser.current_token&.type == :LBRACE
        # Block syntax: lambda { statements }
        @parser.eat(:LBRACE)
        
        body_statements = []
        while @parser.current_token && @parser.current_token.type != :RBRACE
          stmt = @parser.statement
          body_statements << stmt if stmt
        end
        
        @parser.eat(:RBRACE)
        body = BlockNode.new(body_statements)
      else
        # Default to empty body for error recovery
        debug_print("Lambda definition missing body, using empty body")
        body = BlockNode.new([])
      end
      
      debug_print("Completed lambda definition parsing")
      return FunctionDefinitionNode.new("lambda", parameters, body, nil)
    end
  end
end