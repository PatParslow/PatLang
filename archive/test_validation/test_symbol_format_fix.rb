#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "=== Testing Symbol Format Fix ==="

# Test the constraint parsing and evaluation
code = "constrain x :: Number"

begin
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse

  puts "Parsing successful!"
  
  evaluator = Evaluator.new
  result = evaluator.evaluate(ast)
  
  puts "Evaluation successful!"
  puts "Result type: #{result.class}"
  
  if result.respond_to?(:variable)
    puts "Variable: #{result.variable.inspect} (#{result.variable.class})"
    if result.variable.is_a?(Symbol)
      puts "✓ Variable is correctly returned as symbol!"
    else
      puts "✗ Variable is still a #{result.variable.class}"
    end
  end
  
  if result.respond_to?(:constraint_type)
    puts "Constraint type: #{result.constraint_type.inspect} (#{result.constraint_type.class})"
  end
  
  if result.respond_to?(:constraint_data)
    puts "Constraint data: #{result.constraint_data.inspect} (#{result.constraint_data.class})"
  end

rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace[0..5].join("\n")}"
end

puts "\n=== Testing Range Constraint ==="
code2 = "constrain age :: Number where age >= 0 and age <= 150"

begin
  lexer = Lexer.new(code2)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse

  evaluator = Evaluator.new
  result = evaluator.evaluate(ast)
  
  puts "Range constraint test:"
  if result.respond_to?(:variable)
    puts "Variable: #{result.variable.inspect} (#{result.variable.class})"
    if result.variable.is_a?(Symbol)
      puts "✓ Range constraint variable is correctly returned as symbol!"
    else
      puts "✗ Range constraint variable is still a #{result.variable.class}"
    end
  end

rescue => e
  puts "Error: #{e.message}"
end