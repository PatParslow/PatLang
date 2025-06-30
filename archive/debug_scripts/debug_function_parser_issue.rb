#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

# Test the specific function parser issue
test_code = "make a function called greet {}"

puts "=== Debugging Function Parser Issue ==="
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
  
  # Simulate the function parser logic step by step
  puts "=== Simulating Function Parser Logic ==="
  
  # 1. eat(:MAKE)
  puts "1. Current token before eat(:MAKE): #{parser.current_token.type} | '#{parser.current_token.value}'"
  parser.eat(:MAKE)
  
  # 2. Check for 'a'
  puts "2. Current token after eat(:MAKE): #{parser.current_token.type} | '#{parser.current_token.value}'"
  puts "   Checking: current_token.type == :IDENTIFIER && current_token.value == 'a'"
  puts "   Result: #{parser.current_token&.type == :IDENTIFIER && parser.current_token.value == "a"}"
  puts "   But token type is actually: #{parser.current_token&.type}"
  
  # The bug: it should check for :A, not :IDENTIFIER with value "a"
  puts "   Should check: current_token.type == :A"
  puts "   Result if checking :A: #{parser.current_token&.type == :A}"
  
  # 3. Skip 'a' incorrectly (current logic)
  if parser.current_token&.type == :IDENTIFIER && parser.current_token.value == "a"
    puts "3. Skipping 'a' (this won't execute due to bug)"
    parser.advance
  else
    puts "3. NOT skipping 'a' (due to bug - :A token not recognized as :IDENTIFIER)"
  end
  
  # 4. Check for FUNCTION
  puts "4. Current token when checking for FUNCTION: #{parser.current_token.type} | '#{parser.current_token.value}'"
  puts "   Expected: :FUNCTION, Got: #{parser.current_token.type}"
  
  if parser.current_token.nil? || parser.current_token.type != :FUNCTION
    puts "   ❌ This is where the error occurs: 'Expected function after make'"
  else
    puts "   ✓ FUNCTION token found correctly"
  end
  
rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.first(5)
end