require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ambiguous_token'

# Test what tokens are being generated after resolution
def test_token_resolution(input)
  puts "\n🔍 Testing resolution for: #{input}"
  puts '=' * 40
  
  lexer = Lexer.new(input)
  original_tokens = lexer.tokenize
  
  puts "Original tokens:"
  original_tokens.each_with_index do |token, i|
    if token.is_a?(AmbiguousToken)
      puts "  #{i}: AmbiguousToken[#{token.possibilities.map { |p| "#{p[:type]}(#{p[:value]})" }.join(', ')}]"
    else
      puts "  #{i}: #{token.class.name}(#{token.type}, #{token.value})"
    end
  end
  
  parser = Parser.new(original_tokens)
  parser.resolve_all_ambiguous_tokens
  
  puts "Resolved tokens:"
  resolved_tokens = parser.instance_variable_get(:@tokens)
  resolved_tokens.each_with_index do |token, i|
    if token.is_a?(AmbiguousToken)
      puts "  #{i}: AmbiguousToken[#{token.possibilities.map { |p| "#{p[:type]}(#{p[:value]})" }.join(', ')}]"
    else
      puts "  #{i}: #{token.class.name}(#{token.type}, #{token.value})"
    end
  end
end

test_token_resolution('a = 5')
test_token_resolution('x = 10')
test_token_resolution('message = "hello"')