#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

# Test parser routing for function definition
test_code = "make a function called greet {
  return \"Hello\"
}"

puts "=== Testing Parser Routing for Function Definition ==="
puts "Code: #{test_code}"
puts

begin
  lexer = Lexer.new(test_code)
  tokens = []
  
  loop do
    token = lexer.get_next_token
    tokens << token
    break if token.type == :EOF
  end
  
  parser = Parser.new(tokens)
  
  # Check what the parser sees
  puts "Current token: #{parser.current_token&.type} | Value: '#{parser.current_token&.value}'"
  puts "peek(1): #{parser.peek(1)&.type} | Value: '#{parser.peek(1)&.value}'"
  puts "peek(2): #{parser.peek(2)&.type} | Value: '#{parser.peek(2)&.value}'"
  puts "peek(3): #{parser.peek(3)&.type} | Value: '#{parser.peek(3)&.value}'"
  
  # Test the parser routing logic manually
  puts "\n=== Checking Parser Routing Logic ==="
  current = parser.current_token
  
  if current.type == :MAKE
    puts "✓ Found MAKE token"
    
    # Check assignment conditions
    peek1 = parser.peek(1)
    peek2 = parser.peek(2)
    
    puts "peek(1) type: #{peek1&.type}, value: '#{peek1&.value}'"
    puts "peek(2) type: #{peek2&.type}, value: '#{peek2&.value}'"
    
    if peek1&.type == :ASSIGN || peek1&.type == :IS
      puts "→ Would route to assignment (peek1 is ASSIGN/IS)"
    elsif peek1&.type == :IDENTIFIER && 
          (peek2&.type == :ASSIGN || peek2&.type == :IS || 
           peek2&.type == :NUMBER || peek2&.type == :STRING || 
           peek2&.type == :IDENTIFIER || peek2&.type == :LPAREN ||
           peek2&.type == :EOF || peek2 == nil)
      puts "→ Would route to assignment (peek1 IDENTIFIER, peek2 matches assignment pattern)"
    elsif (peek1&.type == :A && peek1&.value == "a" && peek2&.type == :FUNCTION) ||
          (peek1&.type == :FUNCTION)
      puts "→ Would route to function definition"
    else
      puts "→ Would route to expression (standalone make variable)"
    end
  end
  
  puts "\n=== Attempting to Parse ==="
  result = parser.statement
  puts "Parse result: #{result.class}"
  puts "Parse result inspect: #{result.inspect}" if result
  
rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.first(10)
end