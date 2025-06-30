#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "=== Debugging Constraint Types ==="

code = "constrain x :: Number"

lexer = Lexer.new(code)
tokens = lexer.tokenize
parser = Parser.new(tokens)
ast = parser.parse

evaluator = Evaluator.new
result = evaluator.evaluate(ast)

puts "result.class: #{result.class}"
puts "result.variable: #{result.variable.inspect}"
puts "result.constraint_type: #{result.constraint_type.inspect}"
puts "result.constraint_data: #{result.constraint_data.inspect}"

# Check what the constraint_type method is doing
puts "\nDebugging constraint_type method:"
puts "result.instance_variable_get(:@constraint_type): #{result.instance_variable_get(:@constraint_type).inspect}"
puts "result.instance_variable_get(:@constraint_data): #{result.instance_variable_get(:@constraint_data).inspect}"