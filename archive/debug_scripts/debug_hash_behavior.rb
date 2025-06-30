#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== Testing '#' character behavior ==="

lexer = Lexer.new("#")
tokens = lexer.tokenize

puts "Input: '#'"
puts "Tokens produced:"
tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} = '#{token.value}'"
end

puts
puts "Non-EOF tokens: #{tokens.reject { |t| t.type == :EOF }.length}"