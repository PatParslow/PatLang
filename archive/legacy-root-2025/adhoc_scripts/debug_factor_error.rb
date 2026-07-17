require_relative 'src/lexer'
require_relative 'src/parser'

# Test case to reproduce the "Unexpected token in factor" error
def test_factor_error
  puts "=== Testing AmbiguousToken Factor Error ==="
  
  # Test the failing case from regression test
  code = 'make a function called test { return "works" }'
  puts "Testing: #{code}"
  
  # Step 1: Tokenize
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  
  puts "\n--- Raw Tokens from Lexer ---"
  tokens.each_with_index do |token, i|
    puts "#{i}: #{token} (class: #{token.class})"
  end
  
  # Step 2: Initialize parser and check token resolution
  parser = Parser.new(tokens)
  
  puts "\n--- Testing Token Resolution ---"
  resolver = ParserModules::TokenResolver.new(tokens)
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  
  puts "--- Resolved Tokens ---"
  resolved_tokens.each_with_index do |token, i|
    puts "#{i}: #{token} (class: #{token.class})"
  end
  
  # Step 3: Try to parse and catch the error
  puts "\n--- Attempting to Parse ---"
  begin
    result = parser.parse
    puts "SUCCESS: Parsed successfully"
    puts "Result: #{result}"
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Current token when error occurred: #{parser.current_token} (class: #{parser.current_token&.class})"
    
    # Let's trace the parsing flow
    puts "\n--- Tracing Parser Flow ---"
    puts "This error suggests that an AmbiguousToken is reaching the primary() method"
    puts "without being resolved to a concrete token type."
  end
end

# Run the test
test_factor_error