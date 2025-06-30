#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "=== DETAILED LEXER DEBUGGING ==="
puts "Step-by-step analysis of lexer state"
puts

input = "@#$%"
puts "Input: '#{input}' (length: #{input.length})"
puts "Characters: #{input.chars.map.with_index { |c, i| "#{i}:'#{c}'" }.join(', ')}"
puts

lexer = Lexer.new(input)

# Access lexer internals for debugging
puts "Initial lexer state:"
puts "  @position = #{lexer.instance_variable_get(:@position)}"
puts "  @current_char = #{lexer.instance_variable_get(:@current_char).inspect}"
puts "  @text.length = #{lexer.instance_variable_get(:@text).length}"
puts

token1 = lexer.get_next_token
puts "After first token:"
puts "  Token: #{token1.type} = #{token1.value.inspect}"
puts "  @position = #{lexer.instance_variable_get(:@position)}"
puts "  @current_char = #{lexer.instance_variable_get(:@current_char).inspect}"
puts

token2 = lexer.get_next_token
puts "After second token:"
puts "  Token: #{token2.type} = #{token2.value.inspect}"
puts "  @position = #{lexer.instance_variable_get(:@position)}"
puts "  @current_char = #{lexer.instance_variable_get(:@current_char).inspect}"
puts

puts "Analysis:"
if lexer.instance_variable_get(:@position) >= input.length
  puts "  Position is at or beyond end of input - this explains EOF"
else
  puts "  Position is still within input bounds - unexpected EOF"
end