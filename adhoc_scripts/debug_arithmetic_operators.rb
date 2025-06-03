#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== ARITHMETIC OPERATOR ISSUE ANALYSIS ==="
puts

# Test cases to understand the arithmetic operator issue
test_cases = [
  "5 + 3",
  "x = 5 + 3", 
  "a + b",
  "result = a + b * 2",
  "x - y / 2"
]

test_cases.each do |code|
  puts "Testing: '#{code}'"
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    puts "Tokens:"
    tokens.each_with_index do |token, i|
      next if token.type == Token::TOKEN_TYPES[:EOF]
      puts "  #{i}: #{token.type} (#{token.value})"
    end
    
    # Look for plus tokens specifically
    plus_tokens = tokens.select { |t| t.type == Token::TOKEN_TYPES[:PLUS] }
    if plus_tokens.empty?
      puts "❌ No PLUS tokens found!"
    else
      puts "✅ Found #{plus_tokens.length} PLUS token(s)"
    end
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts "Backtrace: #{e.backtrace.first(3).join("\n  ")}"
  end
  
  puts
end

# Let's also check what token types are actually defined
puts "=== AVAILABLE TOKEN TYPES ==="
Token::TOKEN_TYPES.each do |name, value|
  puts "#{name}: #{value}"
end