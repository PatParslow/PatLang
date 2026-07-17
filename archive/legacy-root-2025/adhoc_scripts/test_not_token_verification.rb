#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

# Test that '!' now correctly returns a NOT token instead of throwing an error
puts "Testing NOT token support..."

begin
  lexer = Lexer.new('!')
  tokens = lexer.tokenize
  
  if tokens.length == 2 && tokens[0].type == :NOT && tokens[0].value == '!' && tokens[1].type == :EOF
    puts "✅ SUCCESS: '!' correctly tokenized as NOT token"
    puts "   Token type: #{tokens[0].type}"
    puts "   Token value: #{tokens[0].value}"
  else
    puts "❌ FAILURE: Unexpected tokenization result"
    puts "   Tokens: #{tokens.map(&:to_s)}"
  end
rescue => e
  puts "❌ FAILURE: Exception raised - #{e.message}"
end

# Test that '!=' still works for NOT_EQUAL
begin
  lexer = Lexer.new('!=')
  tokens = lexer.tokenize
  
  if tokens.length == 2 && tokens[0].type == :NOT_EQUAL && tokens[0].value == '!=' && tokens[1].type == :EOF
    puts "✅ SUCCESS: '!=' correctly tokenized as NOT_EQUAL token"
    puts "   Token type: #{tokens[0].type}"
    puts "   Token value: #{tokens[0].value}"
  else
    puts "❌ FAILURE: Unexpected tokenization result for '!='"
    puts "   Tokens: #{tokens.map(&:to_s)}"
  end
rescue => e
  puts "❌ FAILURE: Exception raised for '!=' - #{e.message}"
end

puts "\nTest complete!"