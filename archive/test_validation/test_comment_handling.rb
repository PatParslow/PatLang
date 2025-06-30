#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "=== TESTING COMMENT HANDLING ==="
puts "Ensuring fix doesn't break legitimate comment functionality"
puts

test_cases = [
  { name: "Comment at start of line", input: "# This is a comment\nx = 1" },
  { name: "Comment after whitespace", input: "x = 1 # This is a comment" },
  { name: "Hash symbol in expression", input: "@#$%" },
  { name: "Mixed case", input: "x = 1 # comment\n@#$\n# another comment" }
]

test_cases.each do |test_case|
  puts "Testing: #{test_case[:name]}"
  puts "Input: #{test_case[:input].inspect}"
  
  lexer = Lexer.new(test_case[:input])
  tokens = lexer.tokenize
  
  puts "Tokens:"
  tokens.each do |token|
    next if token.type == :EOF || token.type == Token::TOKEN_TYPES[:EOF]
    puts "  #{token.type}: #{token.value.inspect}"
  end
  puts
end