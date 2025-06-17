require_relative 'src/lexer'
require_relative 'src/parser'

# Test the enhanced error reporting fix
puts "Testing enhanced error reporting fix..."

# Test case: Invalid syntax that should trigger syntax_error
code = "make x = "  # Missing value after assignment operator
lexer = Lexer.new(code)
tokens = lexer.tokenize

puts "Tokens generated:"
tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} = '#{token.value}' (line #{token.line}, col #{token.column})"
end

# Test the parser error reporting
begin
  parser = Parser.new(tokens)
  result = parser.parse
  puts "\n❌ ERROR: Expected syntax error but parsing succeeded"
rescue RuntimeError => e
  puts "\n✅ SUCCESS: Enhanced error reporting triggered"
  puts "Error message: #{e.message}"
  
  # Check if the error message includes position information
  if e.message.include?("line") && e.message.include?("column") && e.message.include?("position")
    puts "✅ CORRECT: Error message includes line, column, and position information"
  else
    puts "❌ ERROR: Error message missing position information"
  end
rescue => e
  puts "\n⚠️  Other error type: #{e.class} - #{e.message}"
end