#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

def test_current_behavior
  puts "Testing current keyword recognition behavior..."
  
  # Test the specific phrase mentioned in the task
  lexer = Lexer.new("make a function called test_func")
  tokens = lexer.tokenize
  
  puts "\nTokenizing: 'make a function called test_func'"
  tokens.each_with_index do |token, i|
    puts "#{i}: #{token.type} -> '#{token.value}'"
  end
  
  # Check what we expect vs what we get
  puts "\nExpected according to task: [:MAKE, :A, :FUNCTION, :CALLED, :IDENTIFIER]"
  puts "Actual: [#{tokens.map(&:type).join(', ')}]"
  
  # Test context-sensitive behavior
  puts "\n" + "="*50
  puts "Testing context sensitivity..."
  
  # Test "make a mistake" - should be identifiers
  lexer2 = Lexer.new("make a mistake")
  tokens2 = lexer2.tokenize
  puts "\nTokenizing: 'make a mistake'"
  tokens2.each_with_index do |token, i|
    puts "#{i}: #{token.type} -> '#{token.value}'"
  end
  
  puts "\nExpected: [:IDENTIFIER, :IDENTIFIER, :IDENTIFIER] (not function context)"
  puts "Actual: [#{tokens2.map(&:type).join(', ')}]"
end

if __FILE__ == $0
  test_current_behavior
end