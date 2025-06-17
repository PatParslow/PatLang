#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

# Test simple function parsing
test_code = <<~CODE
make a function called greet {
  return "Hello, World!"
}
CODE

puts "Testing simple function parsing..."
puts "Code:"
puts test_code
puts "\n" + "="*50

begin
  lexer = Lexer.new(test_code)
  tokens = lexer.tokenize
  
  puts "Tokens:"
  tokens.each_with_index do |token, i|
    puts "#{i}: #{token.type} = '#{token.value}'"
  end
  puts "\n" + "="*50
  
  parser = Parser.new(tokens)
  ast = parser.parse
  
  puts "Parsing successful!"
  puts "AST: #{ast.class}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace[0..5].join("\n")
end