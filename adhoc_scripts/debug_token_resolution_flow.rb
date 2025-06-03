require_relative 'src/lexer'
require_relative 'src/parser'

# Detailed test to understand the token resolution flow
def test_token_resolution_flow
  puts "=== Detailed Token Resolution Flow Analysis ==="
  
  code = 'make a function called test { return "works" }'
  puts "Testing: #{code}"
  
  # Step 1: Get raw tokens
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  
  puts "\n--- Raw Tokens ---"
  tokens.each_with_index do |token, i|
    if token.is_a?(AmbiguousToken)
      puts "#{i}: #{token} - Possibilities: #{token.possible_types}"
    else
      puts "#{i}: #{token}"
    end
  end
  
  # Step 2: Manual resolution test
  puts "\n--- Manual Token Resolution Analysis ---"
  resolver = ParserModules::TokenResolver.new(tokens)
  
  tokens.each_with_index do |token, i|
    if token.is_a?(AmbiguousToken)
      puts "\nResolving token #{i}: #{token}"
      puts "  Possibilities: #{token.possible_types}"
      
      # Test the resolution logic step by step
      if token.possible_types.include?(:MAKE)
        puts "  -> Has MAKE possibility, checking function definition pattern..."
        
        # Check the lookahead logic
        if i + 3 < tokens.length
          next_token = tokens[i + 1]
          token_2 = tokens[i + 2]  
          token_3 = tokens[i + 3]
          
          puts "    Next token (#{i+1}): #{next_token} (type: #{next_token&.type}, value: #{next_token&.value})"
          puts "    Token 2 (#{i+2}): #{token_2} (type: #{token_2&.type}, value: #{token_2&.value})"
          puts "    Token 3 (#{i+3}): #{token_3} (type: #{token_3&.type}, value: #{token_3&.value})"
          
          # The bug is here - the logic checks for .type == :IDENTIFIER
          # but the next tokens are still AmbiguousToken objects!
          if next_token&.type == :IDENTIFIER && next_token&.value == "a" &&
             token_2&.type == :IDENTIFIER && token_2&.value == "function" &&
             token_3&.type == :IDENTIFIER && token_3&.value == "called"
            puts "    -> Pattern matches! Should resolve to MAKE"
          else
            puts "    -> Pattern doesn't match"
            puts "      Expected: IDENTIFIER(a), IDENTIFIER(function), IDENTIFIER(called)"
            puts "      Got: #{next_token&.type}(#{next_token&.value}), #{token_2&.type}(#{token_2&.value}), #{token_3&.type}(#{token_3&.value})"
          end
        end
      end
      
      # Show what it actually resolves to
      resolved = resolver.resolve_ambiguous_token(token, i)
      puts "  -> Resolved to: #{resolved} (type: #{resolved.type})"
    end
  end
  
  # Step 3: Show the final resolved tokens
  puts "\n--- Final Resolved Tokens ---"
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  resolved_tokens.each_with_index do |token, i|
    puts "#{i}: #{token}"
  end
end

test_token_resolution_flow