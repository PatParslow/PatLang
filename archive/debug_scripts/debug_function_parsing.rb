require_relative 'src/lexer'
require_relative 'src/parser'

# Test the specific function syntax from function_demo.pat
test_code = 'make a function called greet {
  return "Hello, World!"
}'

puts "=== Testing Function Parsing ==="
puts "Code to parse:"
puts test_code
puts

# Test lexing
puts "=== Lexer Analysis ==="
lexer = Lexer.new(test_code)
tokens = lexer.tokenize

puts "Tokens generated:"
tokens.each_with_index do |token, i|
  puts "#{i}: #{token.type} - '#{token.value}' (line #{token.line}, col #{token.column})"
end
puts

# Test parsing
puts "=== Parser Analysis ==="
begin
  parser = Parser.new(tokens)
  puts "Current token at start: #{parser.current_token&.type} - '#{parser.current_token&.value}'"
  
  # Try to parse as a statement
  result = parser.statement
  puts "Parse result: #{result.class}"
  puts "Success!"
rescue => e
  puts "Error: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Current token at error: #{parser.current_token&.type} - '#{parser.current_token&.value}'" if parser.respond_to?(:current_token)
  puts "Current token index: #{parser.current_token_index}" if parser.respond_to?(:current_token_index)
  
  # Show tokens around the error position
  if parser.respond_to?(:current_token_index)
    idx = parser.current_token_index
    puts "\nTokens around error position:"
    (idx-2..idx+2).each do |i|
      next if i < 0 || i >= tokens.length
      marker = i == idx ? " >>> " : "     "
      puts "#{marker}#{i}: #{tokens[i].type} - '#{tokens[i].value}'"
    end
  end
end