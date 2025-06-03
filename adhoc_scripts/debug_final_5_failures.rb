#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'

puts "🔍 DEBUGGING FINAL 5 TEST FAILURES"
puts "=" * 50

# 1. Function validation failure
puts "\n1. FUNCTION VALIDATION FAILURE"
puts "-" * 30
code = 'make a function called test { return 42 }'
result = Patlang.evaluate(code)
puts "Code: #{code}"
puts "Result: #{result.inspect}"
puts "Type: #{result.class}"
puts "Expected: FunctionDefinitionNode"

# 2. Parser if-else failure
puts "\n2. PARSER IF-ELSE FAILURE"
puts "-" * 30
lexer = Lexer.new("if x < 0 then y = -1 else y = 1 end")
tokens = lexer.tokenize
parser = Parser.new(tokens)
ast = parser.parse

puts "Code: if x < 0 then y = -1 else y = 1 end"
assignment = ast.then_body.statements[0]
expression = assignment.expression
puts "Assignment expression: #{expression.inspect}"
puts "Type: #{expression.class}"
puts "Expected: BinaryOpNode (for 0 - 1)"
puts "Got: #{expression.class} (for -1)"

# 3. Lexer token values failure  
puts "\n3. LEXER TOKEN VALUES FAILURE"
puts "-" * 30
input = 'test_var = 42.5 + "hello world"'
lexer = Lexer.new(input)
tokens = lexer.tokenize

puts "Code: #{input}"
plus_token = tokens.find { |t| t.type == :PLUS }
puts "PLUS token: #{plus_token.inspect}"
puts "PLUS value: #{plus_token.value.inspect}"
puts "Expected: nil"

# 4. Decimal starting with dot failure
puts "\n4. DECIMAL STARTING WITH DOT FAILURE"
puts "-" * 30
lexer = Lexer.new('.5')
tokens = lexer.tokenize
puts "Code: .5"
puts "Tokens: #{tokens.map { |t| [t.type, t.value] }}"
puts "Token count: #{tokens.length}"
puts "Expected: 3 tokens (DOT, NUMBER, EOF)"

# 5. Comparison operators failure
puts "\n5. COMPARISON OPERATORS FAILURE"
puts "-" * 30
lexer = Lexer.new('"a" == "b" != "c" < "d" > "e" <= "f" >= "g"')
tokens = lexer.tokenize

operator_tokens = tokens.select do |token|
  [:EQUAL, :NOT_EQUAL, :LESS_THAN, :GREATER_THAN, :LESS_EQUAL, :GREATER_EQUAL].include?(token.type)
end

puts "Code: \"a\" == \"b\" != \"c\" < \"d\" > \"e\" <= \"f\" >= \"g\""
puts "Operator tokens found: #{operator_tokens.length}"
puts "Expected: 6"
puts "Operators:"
operator_tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} = #{token.value}"
end

puts "\n" + "=" * 50
puts "DIAGNOSIS COMPLETE"