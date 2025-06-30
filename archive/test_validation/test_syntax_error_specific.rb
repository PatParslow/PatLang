require_relative 'src/lexer'
require_relative 'src/parser'

# Test the enhanced syntax_error method specifically
puts "Testing enhanced syntax_error method fix..."

# Test case: Assignment without value (triggers syntax_error at line 287)
code = "x = "  # Missing value after assignment operator
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
  puts "\n✅ SUCCESS: syntax_error method triggered"
  puts "Error message: #{e.message}"
  
  # Check if the error message includes position information
  if e.message.include?("line") && e.message.include?("column") && e.message.include?("position")
    puts "✅ CORRECT: Error message includes line, column, and position information"
  else
    puts "❌ ERROR: Error message missing position information"
    puts "Expected format: 'message at line X, column Y: [TOKEN] (position Z)'"
  end
rescue => e
  puts "\n⚠️  Other error type: #{e.class} - #{e.message}"
end

puts "\n" + "="*50
puts "Testing syntax_error with no current token..."

# Test syntax_error when current_token is nil
begin
  parser = Parser.new([])  # Empty token array
  parser.instance_eval { syntax_error("Test error") }
rescue RuntimeError => e
  puts "✅ SUCCESS: syntax_error handled nil token case"
  puts "Error message: #{e.message}"
  
  if e.message.include?("end of input") && e.message.include?("position")
    puts "✅ CORRECT: Error message handles nil token case properly"
  else
    puts "❌ ERROR: Error message doesn't handle nil token case properly"
  end
rescue => e
  puts "⚠️  Other error type: #{e.class} - #{e.message}"
end