# This file contains the fixes needed for the parser.rb file

# 1. Remove the duplicate primary method (lines 384-412)
# 2. Fix parse_parameter method to handle ambiguous tokens
# 3. Fix function call parsing for "with" syntax
# 4. Ensure proper handling of ambiguous tokens in assignments

# Let me create a test to verify what specific token types are being created
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ambiguous_token'

def debug_tokens(input)
  puts "=== DEBUGGING TOKENS FOR: #{input} ==="
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  tokens.each_with_index do |token, i|
    if token.ambiguous?
      puts "#{i}: #{token} (AMBIGUOUS)"
      puts "  Possibilities: #{token.possible_types.join(', ')}"
    else
      puts "#{i}: #{token.type}(#{token.value})"
    end
  end
  puts "========================="
  tokens
end

puts "🔍 DEBUGGING SPECIFIC PROBLEM CASES"
puts

# Test what tokens are created for problematic inputs
debug_tokens("a = 5")
debug_tokens("make a function called test takes: a { return a }")
debug_tokens("call test with 5")