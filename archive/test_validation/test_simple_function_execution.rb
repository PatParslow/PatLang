#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

# Test simple function execution
test_code = <<~CODE
make a function called greet {
  return "Hello, World!"
}

call greet
CODE

puts "Testing simple function execution..."
puts "Code:"
puts test_code
puts "\n" + "="*50

begin
  lexer = Lexer.new(test_code)
  parser = Parser.new(lexer)
  ast = parser.parse
  
  puts "Parsing successful!"
  puts "AST: #{ast.class}"
  
  evaluator = Evaluator.new
  result = evaluator.evaluate(ast)
  
  puts "Execution successful!"
  puts "Result: #{result}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace[0..5].join("\n")
end