require 'set'
require_relative '../token'
require_relative '../ambiguous_token'
require_relative 'parser_timeout_protection'

# Token resolution module for handling context-dependent tokens
module ParserModules
  class TokenResolver
    include TimeoutProtection
    
    def initialize(tokens)
      @tokens = tokens
      @resolution_depth = 0
      @visited_positions = Set.new
    end

    # Core logic for resolving context-dependent tokens with circular reference protection
    def resolve_ambiguous_token(token, context_index = nil)
      return token unless token.is_a?(AmbiguousToken)
      
      # Prevent infinite recursion with depth tracking
      @resolution_depth += 1
      if @resolution_depth > 100
        @resolution_depth -= 1
        # Return fallback resolution to break potential recursion
        return Token.new(token.possibilities.first[:type], token.possibilities.first[:value], token.position, token.line, token.column)
      end
      
      # Prevent circular references by tracking visited positions
      if context_index && @visited_positions.include?(context_index)
        @resolution_depth -= 1
        # Already visited this position, use fallback
        return Token.new(token.possibilities.first[:type], token.possibilities.first[:value], token.position, token.line, token.column)
      end
      
      @visited_positions.add(context_index) if context_index
      
      begin
        # Check if this is an assignment context: identifier followed by =
        if context_index && context_index + 1 < @tokens.length &&
           @tokens[context_index + 1]&.type == :ASSIGN
          # This is a variable assignment, resolve to identifier
          identifier_possibility = token.resolve_to(:IDENTIFIER)
          return identifier_possibility if identifier_possibility
        end
        
        # Check if this token is part of a function definition context
        if context_index && is_function_definition_context?(context_index)
          # Check for specific function keywords in function context
          if token.can_be?(:FUNCTION)
            return token.resolve_to(:FUNCTION)
          elsif token.can_be?(:CALLED)
            return token.resolve_to(:CALLED)
          elsif token.can_be?(:MAKE)
            return token.resolve_to(:MAKE)
          elsif token.can_be?(:A) && token.value == "a"
            # Keep "a" as IDENTIFIER in function context since parser expects it
            return token.resolve_to(:IDENTIFIER)
          end
        end
        
        # CONTEXT-AWARE DEFAULT: Only resolve to IDENTIFIER if keywords don't fit context
        # For function keywords, preserve their type unless we're clearly NOT in function context
        if token.can_be?(:FUNCTION) && could_be_function_keyword?(token, context_index)
          return token.resolve_to(:FUNCTION)
        elsif token.can_be?(:CALLED) && could_be_called_keyword?(token, context_index)
          return token.resolve_to(:CALLED)
        elsif token.can_be?(:MAKE) && could_be_make_keyword?(token, context_index)
          return token.resolve_to(:MAKE)
        end
        
        # DEFAULT CASE: For variables and simple identifiers, resolve to IDENTIFIER
        # This handles cases like 'a = 5' where 'a' is ambiguous between type A and IDENTIFIER
        identifier_possibility = token.resolve_to(:IDENTIFIER)
        if identifier_possibility
          return identifier_possibility
        end
        
        # Fallback: use the first possibility
        return Token.new(token.possibilities.first[:type], token.possibilities.first[:value], token.position, token.line, token.column)
      ensure
        @visited_positions.delete(context_index) if context_index
        @resolution_depth -= 1
      end
    end

    # Check if the current position is within a function definition context with loop protection
    def is_function_definition_context?(context_index)
      return false unless context_index
      
      # Look backwards to see if we have a MAKE token that started a function definition
      look_back = [context_index - 1, 0].max
      iterations = 0
      max_iterations = 50 # Prevent infinite backward search
      
      while look_back >= 0 && iterations < max_iterations
        token = @tokens[look_back]
        if token&.type == :MAKE || (token&.type == :IDENTIFIER && token&.value == "make")
          return true
        elsif token&.type == :LBRACE || token&.type == :SEMICOLON || token&.type == :EOF
          # Hit a statement boundary, stop looking
          break
        end
        look_back -= 1
        iterations += 1
      end
      
      false
    end
    
    # Check if a 'function' token could be a keyword in the current context
    def could_be_function_keyword?(token, context_index)
      return false unless token.can_be?(:FUNCTION)
      
      # Look backward for 'make' or 'make a'
      if context_index && context_index > 0
        prev_token = @tokens[context_index - 1]
        if prev_token&.type == :MAKE || (prev_token&.type == :IDENTIFIER && prev_token&.value == "make")
          return true
        elsif prev_token&.value == "a" && context_index > 1
          prev_prev_token = @tokens[context_index - 2]
          if prev_prev_token&.type == :MAKE || (prev_prev_token&.type == :IDENTIFIER && prev_prev_token&.value == "make")
            return true
          end
        end
      end
      
      false
    end
    
    # Check if a 'called' token could be a keyword in the current context
    def could_be_called_keyword?(token, context_index)
      return false unless token.can_be?(:CALLED)
      
      # Look backward for 'function' pattern
      if context_index && context_index > 0
        prev_token = @tokens[context_index - 1]
        # Check for 'function called' pattern
        if prev_token&.value == "function"
          return true
        end
      end
      
      false
    end
    
    # Check if a 'make' token could be a keyword in the current context
    def could_be_make_keyword?(token, context_index)
      return false unless token.can_be?(:MAKE)
      
      # Look ahead for function definition patterns:
      # make function ...
      # make a function ...
      if context_index && context_index + 1 < @tokens.length
        next_token = @tokens[context_index + 1]
        
        # Pattern: make function
        if next_token&.value == "function"
          return true
        end
        
        # Pattern: make a function
        if next_token&.value == "a" && context_index + 2 < @tokens.length
          next_next_token = @tokens[context_index + 2]
          if next_next_token&.value == "function"
            return true
          end
        end
      end
      
      false
    end
    
    # Check if an IDENTIFIER(make) looks like the start of a function definition
    def looks_like_function_definition_start?(index)
      # Look ahead for function definition patterns:
      # make function ...
      # make a function ...
      # make function called ...
      # make a function called ...
      
      return false unless index + 1 < @tokens.length
      
      next_token = @tokens[index + 1]
      
      # Pattern: make function
      if next_token&.value == "function"
        return true
      end
      
      # Pattern: make a function
      if next_token&.value == "a" && index + 2 < @tokens.length
        next_next_token = @tokens[index + 2]
        if next_next_token&.value == "function"
          return true
        end
      end
      
      false
    end

    # Pre-process all tokens to resolve ambiguous contexts with comprehensive protection
    def resolve_all_ambiguous_tokens
      result = with_token_resolution_timeout("token resolution") do
        resolved_tokens = []
        i = 0
        circuit_breaker = create_circuit_breaker(@tokens.length * 2)
        
        # Reset tracking state for new resolution pass
        @resolution_depth = 0
        @visited_positions.clear
        
        while i < @tokens.length
          circuit_breaker.check_iteration(i)
          token = @tokens[i]
          
          if token.is_a?(AmbiguousToken)
            # Use the current context to resolve the ambiguous token
            resolved_token = resolve_ambiguous_token(token, i)
            resolved_tokens << resolved_token
            i += 1
          elsif token.type == :IDENTIFIER && token.value == "make"
            # Convert IDENTIFIER(make) to MAKE in function definition contexts
            if looks_like_function_definition_start?(i)
              resolved_tokens << Token.new(:MAKE, "make", token.position, token.line, token.column)
            else
              resolved_tokens << token
            end
            i += 1
          else
            resolved_tokens << token
            i += 1
          end
        end
        
        @tokens = resolved_tokens
        @tokens
      end
      
      return result if result
      return @tokens
    rescue EmergencyTimeout::TimeoutError => e
      # Return original tokens if resolution times out
      puts "[TokenResolver WARNING] Token resolution timeout: #{e.message}"
      return @tokens
    end
  end
end