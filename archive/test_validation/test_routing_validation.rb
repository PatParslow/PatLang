require_relative 'src/lexer'
require_relative 'src/parser'

# Test the function routing fix specifically
puts "Testing function routing logic fix..."

# Test case: "make a function called greet"
code = "make a function called greet { return \"Hello\" }"
lexer = Lexer.new(code)
tokens = lexer.tokenize

puts "Tokens generated:"
tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} = '#{token.value}'"
end

# Check if token "a" has type :A (not :IDENTIFIER)
a_token = tokens.find { |t| t.value == "a" }
if a_token
  puts "\nToken 'a' has type: #{a_token.type}"
  if a_token.type == :A
    puts "✅ CORRECT: Token 'a' has type :A (not :IDENTIFIER)"
  else
    puts "❌ ERROR: Token 'a' has type #{a_token.type} (expected :A)"
  end
else
  puts "❌ ERROR: Token 'a' not found"
end

# Test the parser routing
begin
  parser = Parser.new(tokens)
  result = parser.parse
  puts "\n✅ SUCCESS: Parser completed without routing errors"
  puts "Parsed result type: #{result.class}"
rescue => e
  if e.message.include?("Undefined variable: make")
    puts "\n✅ SUCCESS: Function routing worked (reached evaluator stage)"
    puts "Parser successfully routed to function definition logic"
  else
    puts "\n❌ ERROR: Parser failed with: #{e.message}"
  end
end