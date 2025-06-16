#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "=== LEXER DIAGNOSIS TEST ==="
puts "Testing specific characters that should produce tokens (NOT raise RuntimeError)"
puts "The lexer follows 'Never Fail, Always Token' principle"
puts

# Test cases that should produce tokens according to lexer specification
test_cases = [
  { name: "Single @ character", input: "@", expected_tokens: ["AT"] },
  { name: "Invalid symbols @#$%", input: "@#$%", expected_tokens: ["AT", "UNKNOWN", "UNKNOWN", "PERCENT"] },
  { name: "Currency symbols €£¥", input: "€£¥", expected_tokens: ["UNKNOWN", "UNKNOWN", "UNKNOWN"] },
  { name: "Emojis 🚀💻", input: "🚀💻", expected_tokens: ["UNKNOWN", "UNKNOWN"] },
  { name: "Greek letters αβγ", input: "αβγ", expected_tokens: ["UNKNOWN", "UNKNOWN", "UNKNOWN"] }
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
    
    # Remove EOF token for comparison
    non_eof_tokens = tokens.select { |t| t.type != :EOF && t.type != Token::TOKEN_TYPES[:EOF] }
    
    puts "  ✓ CORRECT: Tokens generated (no errors raised):"
    non_eof_tokens.each_with_index do |token, i|
      expected = test_case[:expected_tokens][i] || "?"
      status = token.type.to_s == expected ? "✓" : "?"
      puts "    #{status} Type: #{token.type}, Value: #{token.value.inspect} (expected: #{expected})"
    end
    
    # Verify token count matches expectation
    if non_eof_tokens.length == test_case[:expected_tokens].length
      puts "  ✓ Token count matches expectation: #{non_eof_tokens.length}"
    else
      puts "  ? Token count mismatch: got #{non_eof_tokens.length}, expected #{test_case[:expected_tokens].length}"
    end
    
  rescue RuntimeError => e
    puts "  ✗ UNEXPECTED: RuntimeError raised - #{e.message}"
    puts "  ✗ LEXER VIOLATION: Lexer should NEVER raise RuntimeError for invalid characters"
  rescue => e
    puts "  ✗ UNEXPECTED ERROR TYPE: #{e.class} - #{e.message}"
  end
  
  puts
end

puts "=== DIAGNOSIS SUMMARY ==="
puts "This test validates that the lexer correctly follows the 'Never Fail, Always Token' principle."
puts "Expected behavior: ALL test cases should produce tokens (NEVER raise RuntimeError)"
puts "✓ = Correct behavior: tokens produced as expected"
puts "✗ = Incorrect behavior: RuntimeError raised (violates lexer specification)"
puts
puts "The lexer is working CORRECTLY if it produces tokens instead of raising errors."