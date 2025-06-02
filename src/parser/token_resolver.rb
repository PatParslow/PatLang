require_relative '../token'
require_relative '../ambiguous_token'

# Token resolution module for handling context-dependent tokens
module ParserModules
  class TokenResolver
    def initialize(tokens)
      @tokens = tokens
    end

    # Core logic for resolving context-dependent tokens
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

    # Pre-process all tokens to resolve ambiguous contexts
    def resolve_all_ambiguous_tokens
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
      return @tokens
    end
  end
end