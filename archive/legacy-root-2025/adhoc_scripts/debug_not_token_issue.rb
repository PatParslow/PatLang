#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== DEBUGGING :NOT TOKEN ISSUE ==="
puts

# Test cases from the failing test
test_cases = [
  ['<', :LESS],
  ['>', :GREATER], 
  ['=', :ASSIGN],
  ['!', :NOT]
]

puts "1. Checking TOKEN_TYPES for :NOT definition:"
puts "   :NOT defined in TOKEN_TYPES? #{Token::TOKEN_TYPES.key?(:NOT)}"
puts

puts "2. Testing each character individually:"
test_cases.each do |input, expected_type|
  puts "   Testing '#{input}' expecting #{expected_type}:"
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    actual_type = tokens[0].type
    puts "     ✓ Result: #{actual_type} (#{actual_type == expected_type ? 'PASS' : 'FAIL'})"
  rescue => e
    puts "     ✗ Error: #{e.message}"
  end
end

puts
puts "3. Key findings:"
puts "   - The test expects '!' to return :NOT token type"
puts "   - TOKEN_TYPES hash does not define :NOT"
puts "   - Lexer treats standalone '!' as error (line 128 calls error())"
puts "   - Need to: 1) Add :NOT to TOKEN_TYPES, 2) Fix lexer logic"

puts
puts "4. Suggested fix locations:"
puts "   - src/token.rb: Add NOT: :NOT to TOKEN_TYPES hash"
puts "   - src/lexer.rb: Change line 128 from error() to return :NOT token"