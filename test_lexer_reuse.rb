require_relative "patlang-core/lexer/lexer"

content = 'make a class Test inherits BaseObject { make a function called hello { } }'

5.times do |i|
  lexer = Patlang::Lexer::Lexer.new(content)
  tokens = lexer.tokenize
  types = tokens.map { |t| t.type.to_s }
  puts "Run #{i+1}: #{types.join(', ')}"
end