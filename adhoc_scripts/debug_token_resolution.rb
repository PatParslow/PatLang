#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/lexer'
require_relative 'src/parser/token_resolver'

# Test function patterns
test_cases = [
  "make a function called test",
  "make function test2", 
  "make a function test3",
  "make function called test4"
]

puts "🔍 TOKEN RESOLUTION DEBUG"
puts "=" * 50

test_cases.each_with_index do |code, i|
  puts "\n#{i+1}. Testing: #{code.inspect}"
  
  # Get raw tokens from lexer
  lexer = Lexer.new(code)
  raw_tokens = lexer.tokenize
  
  puts "   Raw tokens:"
  raw_tokens.each_with_index do |token, j|
    puts "     [#{j}] #{token.inspect}"
  end
  
  # Apply token resolver
  resolver = ParserModules::TokenResolver.new(raw_tokens)
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  
  puts "   Resolved tokens:"
  resolved_tokens.each_with_index do |token, j|
    puts "     [#{j}] #{token.inspect}"
  end
  
  puts "   " + "-" * 40
end