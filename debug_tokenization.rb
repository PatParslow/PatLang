require_relative 'src/lexer'
require_relative 'src/ambiguous_token'

# Test what tokens are being generated for simple assignment
lexer = Lexer.new('a = 5')
tokens = lexer.tokenize

puts '🔍 Analyzing tokens for: a = 5'
puts '=' * 30
tokens.each_with_index do |token, i|
  if token.is_a?(AmbiguousToken)
    puts "#{i}: AmbiguousToken[#{token.possibilities.map { |p| "#{p[:type]}(#{p[:value]})" }.join(', ')}]"
  else
    puts "#{i}: #{token.class.name}(#{token.type}, #{token.value})"
  end
end

puts "\n🔍 Analyzing tokens for: x = 10"
puts '=' * 30
lexer2 = Lexer.new('x = 10')
tokens2 = lexer2.tokenize

tokens2.each_with_index do |token, i|
  if token.is_a?(AmbiguousToken)
    puts "#{i}: AmbiguousToken[#{token.possibilities.map { |p| "#{p[:type]}(#{p[:value]})" }.join(', ')}]"
  else
    puts "#{i}: #{token.class.name}(#{token.type}, #{token.value})"
  end
end