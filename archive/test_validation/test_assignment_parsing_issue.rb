#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/parser'
require_relative 'src/lexer'

# Test to reproduce the specific "Undefined variable: =" issue
puts "=== Assignment Parsing Issue Test ==="
puts

# Test 1: Check what type of AST node is created for assignments
puts "Test 1: AST node type analysis"
test_expressions = [
  "x = 5",
  "obj.value = -5",  # This is from the failing test
  "Object.new"
]

test_expressions.each_with_index do |expr, i|
  puts "Test 1.#{i+1}: #{expr}"
  begin
    lexer = Lexer.new(expr)
    tokens = lexer.tokenize
    puts "  Tokens: #{tokens.map { |t| "#{t.type}(#{t.value})" }.join(', ')}"
    
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "  AST: #{ast.class}"
    
    if ast.respond_to?(:statements)
      ast.statements.each_with_index do |stmt, j|
        puts "    Statement #{j}: #{stmt.class} - #{stmt}"
        if stmt.class.to_s == "BinaryOpNode"
          puts "      Left: #{stmt.left.class} - #{stmt.left}"
          puts "      Operator: #{stmt.operator}"
          puts "      Right: #{stmt.right.class} - #{stmt.right}"
        end
      end
    end
    
  rescue => e
    puts "  ✗ Parse Error: #{e.message}"
    puts "    Class: #{e.class}"
  end
  puts
end

puts

# Test 2: Check the problematic constraint expression
puts "Test 2: Constraint parsing issue"
constraint_expr = "obj.value = -5"
puts "Testing: #{constraint_expr}"

begin
  # This should fail with "Undefined variable: ="
  result = Patlang.evaluate(constraint_expr)
  puts "✓ Unexpected success: #{result}"
rescue => e
  puts "✗ Error as expected: #{e.message}"
  puts "  Class: #{e.class}"
  
  if e.message.include?("Undefined variable: =")
    puts "  *** CONFIRMED: This is the '=' undefined variable error ***"
    puts "  *** ROOT CAUSE: Assignment is being parsed as binary operation ***"
  end
end

puts

# Test 3: Check if this is a property assignment vs variable assignment issue
puts "Test 3: Property assignment vs variable assignment"
test_cases = [
  "x = 5",           # Variable assignment - should work
  "obj = Object.new", # Variable assignment - should work  
  "obj.value = 5"     # Property assignment - might be the issue
]

test_cases.each_with_index do |expr, i|
  puts "Test 3.#{i+1}: #{expr}"
  begin
    result = Patlang.evaluate(expr)
    puts "  ✓ Success: #{result}"
  rescue => e
    puts "  ✗ Error: #{e.message}"
    if e.message.include?("Undefined variable: =")
      puts "    *** PROPERTY ASSIGNMENT ISSUE FOUND ***"
    end
  end
end

puts "=== Test Complete ==="