require_relative 'src/lexer'

# Test reasoning token recognition
test_code = "reasoning mode on"
lexer = Lexer.new(test_code)
tokens = lexer.tokenize

puts "Testing: #{test_code}"
tokens.each do |token|
  puts "  #{token}"
end

# Test constraint syntax
test_code2 = "constrain x :: Number"
lexer2 = Lexer.new(test_code2)
tokens2 = lexer2.tokenize

puts "\nTesting: #{test_code2}"
tokens2.each do |token|
  puts "  #{token}"
end