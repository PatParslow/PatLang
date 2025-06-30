require_relative 'src/lexer'
require_relative 'src/parser'

# Test the specific function syntax from function_demo.pat
test_code = 'make a function called greet {
  return "Hello, World!"
}'

puts "=== Testing Routing Logic ==="
puts "Code to parse:"
puts test_code
puts

# Test lexing
lexer = Lexer.new(test_code)
tokens = lexer.tokenize

puts "First 5 tokens:"
tokens[0..4].each_with_index do |token, i|
  puts "#{i}: #{token.type} - '#{token.value}'"
end
puts

# Test the peek logic manually
parser = Parser.new(tokens)

puts "=== Manual Peek Testing ==="
puts "current_token: #{parser.current_token.type} - '#{parser.current_token.value}'"

# Test peek method
puts "peek(1): #{parser.peek(1)&.type} - '#{parser.peek(1)&.value}'"
puts "peek(2): #{parser.peek(2)&.type} - '#{parser.peek(2)&.value}'"
puts

# Test the exact condition from the parser
puts "=== Testing Exact Conditions ==="

# First condition: (peek(1)&.type == :IDENTIFIER && peek(1)&.value == "a" && peek(2)&.type == :FUNCTION)
peek1 = parser.peek(1)
peek2 = parser.peek(2)

puts "peek(1)&.type == :IDENTIFIER: #{peek1&.type == :IDENTIFIER}"
puts "peek(1)&.value == 'a': #{peek1&.value == 'a'}"
puts "peek(2)&.type == :FUNCTION: #{peek2&.type == :FUNCTION}"

condition1 = (peek1&.type == :IDENTIFIER && peek1&.value == "a" && peek2&.type == :FUNCTION)
puts "First condition result: #{condition1}"

# Second condition: (peek(1)&.type == :FUNCTION)
condition2 = (peek1&.type == :FUNCTION)
puts "Second condition result: #{condition2}"

# Overall condition
overall = condition1 || condition2
puts "Overall condition (should route to function): #{overall}"

if overall
  puts "Should route to function parser"
else
  puts "Will NOT route to function parser - THIS IS THE BUG!"
end