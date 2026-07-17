#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

def test_phrase_only
  puts "Testing: 'make a function'"
  lexer = Lexer.new("make a function")
  tokens = lexer.tokenize
  
  tokens.each_with_index do |token, i|
    puts "#{i}: #{token.type} -> '#{token.value}'"
  end
  
  puts "\nExpected: [:MAKE, :A, :FUNCTION]"
  puts "Actual: [#{tokens[0..-2].map(&:type).join(', ')}]"
end

if __FILE__ == $0
  test_phrase_only
end