require_relative 'src/lexer'

def test_tokenization(input)
  puts "Input: #{input.inspect}"
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  
  puts "Tokens:"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.type} = #{token.value.inspect}"
  end
  puts
end

# Test cases
test_tokenization("make a function called greet")
test_tokenization("make")
test_tokenization("a = 5")