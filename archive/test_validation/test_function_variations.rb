#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

# Test all function definition variations
test_cases = [
  'make a function called fred { return "variation 1" }',
  'make function called fred { return "variation 2" }',
  'make a function fred { return "variation 3" }',
  'make function fred { return "variation 4" }'
]

test_cases.each_with_index do |test_code, index|
  puts "Testing variation #{index + 1}: #{test_code}"
  puts "="*60
  
  begin
    lexer = Lexer.new(test_code)
    parser = Parser.new(lexer)
    ast = parser.parse
    
    puts "✅ Parsing successful! AST: #{ast.class}"
    
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    
    puts "✅ Execution successful!"
    puts
    
  rescue => e
    puts "❌ Error: #{e.message}"
    puts
  end
end

# Test calling the function
puts "Testing function call:"
puts "="*60

call_test = <<~CODE
make a function called greet { return "Hello from function!" }
call greet
CODE

begin
  lexer = Lexer.new(call_test)
  parser = Parser.new(lexer)
  ast = parser.parse
  
  evaluator = Evaluator.new
  result = evaluator.evaluate(ast)
  
  puts "✅ Function call successful! Result: #{result}"
  
rescue => e
  puts "❌ Error: #{e.message}"
end