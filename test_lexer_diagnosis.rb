#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "=== LEXER DIAGNOSIS TEST ==="
puts "Testing specific characters that should raise RuntimeError according to failing tests"
puts

# Test cases that should raise RuntimeError according to the failing tests
test_cases = [
  { name: "Single @ character", input: "@" },
  { name: "Invalid symbols @#$%", input: "@#$%" },
  { name: "Currency symbols €£¥", input: "€£¥" },
  { name: "Emojis 🚀💻", input: "🚀💻" },
  { name: "Greek letters αβγ", input: "αβγ" }
]

test_cases.each do |test_case|
  puts "Testing: #{test_case[:name]} - Input: '#{test_case[:input]}'"
  
  begin
    lexer = Lexer.new(test_case[:input])
    tokens = []
    
    # Try to tokenize the entire input
    loop do
      token = lexer.get_next_token
      tokens << token
      break if token.type == :EOF || token.type == Token::TOKEN_TYPES[:EOF]
    end
    
    puts "  ✗ UNEXPECTED: No error raised. Tokens generated:"
    tokens.each do |token|
      puts "    - Type: #{token.type}, Value: #{token.value.inspect}"
    end
    
  rescue RuntimeError => e
    puts "  ✓ EXPECTED: RuntimeError raised - #{e.message}"
  rescue => e
    puts "  ? UNEXPECTED ERROR TYPE: #{e.class} - #{e.message}"
  end
  
  puts
end

puts "=== DIAGNOSIS SUMMARY ==="
puts "This test reveals which characters are incorrectly handled by the lexer."
puts "Expected behavior: ALL test cases should raise RuntimeError"
puts "If any test case shows 'No error raised', that confirms the diagnosis."