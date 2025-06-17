#!/usr/bin/env ruby

# Load the source files
require_relative 'src/lexer'
require_relative 'src/token'

puts "=== Debug: '@' Character Lexer Behavior Validation ==="
puts

# Test cases that currently fail in the test suite
test_cases = [
  "@#$%",           # From test_invalid_character_error_handling 
  "@invalid",       # From test_error_recovery_mechanisms
  "@",              # Simple @ character
  "valid = 42\n@invalid\nmore = 123"  # Mixed content from error recovery test
]

test_cases.each_with_index do |input, i|
  puts "Test Case #{i + 1}: #{input.inspect}"
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Look for AT tokens
    at_tokens = tokens.select { |token| token.type == :AT }
    
    if at_tokens.any?
      puts "✓ SUCCESS: Lexer correctly produced AT tokens"
      at_tokens.each do |token|
        puts "  - AT token: '#{token.value}' at position #{token.position}"
      end
    else
      puts "⚠ WARNING: No AT tokens found, but no error raised either"
    end
    
    puts "  Total tokens: #{tokens.length}"
    tokens.each { |token| puts "    #{token.type}: '#{token.value}'" }
    
  rescue RuntimeError => e
    puts "✗ ERROR: #{e.message}"
    puts "  This is the WRONG behavior - lexer should produce AT tokens, not errors"
  rescue => e
    puts "✗ UNEXPECTED ERROR: #{e.class}: #{e.message}"
  end
  
  puts
end

puts "=== Analysis ==="
puts "The lexer implementation in src/lexer.rb lines 200-203 shows:"
puts "- '@' character case is handled and returns Token.new(Token::TOKEN_TYPES[:AT], '@', ...)"
puts "- AT token type is defined in src/token.rb line 82"
puts "- Tests should expect AT tokens, not RuntimeError exceptions"
puts
puts "=== Conclusion ==="
puts "Tests in test/infrastructure/test_lexer_error_recovery.rb need to be updated:"
puts "1. Lines 28-48: test_invalid_character_error_handling should expect AT token for '@#$%'"
puts "2. Lines 205-226: test_error_recovery_mechanisms should expect AT token for '@invalid'"