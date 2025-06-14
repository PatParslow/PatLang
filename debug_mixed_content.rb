#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== Testing mixed content tokenization ==="

mixed_input = "valid = 42\n@invalid\n$unknown\nmore = 123"
lexer = Lexer.new(mixed_input)
tokens = lexer.tokenize

puts "Input: #{mixed_input.inspect}"
puts "Tokens produced:"
tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} = #{token.value.inspect} (#{token.value.class})"
end

puts
puts "Numbers:"
numbers = tokens.select { |token| token.type == :NUMBER }
number_values = numbers.map(&:value)
puts "  Values: #{number_values.inspect}"
puts "  Classes: #{number_values.map(&:class)}"