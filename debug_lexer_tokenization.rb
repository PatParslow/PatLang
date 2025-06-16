#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "=== DEBUGGING LEXER TOKENIZATION ==="
puts "Investigating why '@#$%' only produces 1 token instead of 4"
puts

input = "@#$%"
lexer = Lexer.new(input)

puts "Input: '#{input}'"
puts "Character by character tokenization:"
puts

token_count = 0
loop do
  token = lexer.get_next_token
  token_count += 1
  
  puts "Token #{token_count}: Type=#{token.type}, Value=#{token.value.inspect}"
  
  break if token.type == :EOF || token.type == Token::TOKEN_TYPES[:EOF]
  
  # Safety check to prevent infinite loops
  if token_count > 10
    puts "Safety break - too many tokens"
    break
  end
end

puts
puts "Total tokens generated: #{token_count - 1} (excluding EOF)"
puts "Expected: 4 tokens (@, #, $, %)"