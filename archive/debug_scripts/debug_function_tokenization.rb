#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

# Test the tokenization of the function definition syntax
test_code = "make a function called greet {"

puts "=== Testing Function Definition Tokenization ==="
puts "Code: #{test_code}"
puts

lexer = Lexer.new(test_code)
tokens = []

begin
  loop do
    token = lexer.get_next_token
    tokens << token
    puts "Token: #{token.type} | Value: '#{token.value}' | Position: #{token.position}"
    break if token.type == :EOF
  end
rescue => e
  puts "ERROR during tokenization: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== Testing Parser Recognition ==="
begin
  parser = Parser.new(tokens)
  parser.debug = true
  
  # Check what the first few tokens are
  puts "Current token: #{parser.current_token&.type} | Value: '#{parser.current_token&.value}'"
  puts "Next token: #{parser.peek(1)&.type} | Value: '#{parser.peek(1)&.value}'"
  puts "Token after: #{parser.peek(2)&.type} | Value: '#{parser.peek(2)&.value}'"
  puts "Token after that: #{parser.peek(3)&.type} | Value: '#{parser.peek(3)&.value}'"
  
rescue => e
  puts "ERROR during parsing setup: #{e.message}"
  puts e.backtrace.first(5)
end