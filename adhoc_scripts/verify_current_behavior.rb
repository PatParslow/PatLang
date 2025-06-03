#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/parser/function_parser'

def test_current_behavior
  puts "=== Testing Current Behavior of Failed Tests ==="
  
  # Test 1: Empty parameter list in function
  puts "\n1. Testing empty parameter list: 'make a function called empty takes: { return nil }'"
  begin
    input = "make a function called empty takes: { return nil }"
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    result = parser.parse
    puts "   Result: SUCCESS - No error raised, parsed as: #{result.class}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
  
  # Test 2: Empty expression evaluation
  puts "\n2. Testing empty expression evaluation: ''"
  begin
    input = ""
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    puts "   Result: SUCCESS - No error raised, result: #{result.inspect}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
  
  # Test 3: Invalid number format
  puts "\n3. Testing invalid number format: '3.14.159'"
  begin
    lexer = Lexer.new('3.14.159')
    result = lexer.tokenize
    puts "   Result: SUCCESS - No error raised, tokens: #{result.map(&:type)}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
  
  # Test 4: Invalid characters
  puts "\n4. Testing invalid character: '@'"
  begin
    lexer = Lexer.new('@')
    result = lexer.tokenize
    puts "   Result: SUCCESS - No error raised, tokens: #{result.map(&:type)}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
  
  # Test 5: Empty expression parsing
  puts "\n5. Testing empty expression parsing: ''"
  begin
    lexer = Lexer.new("")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    result = parser.parse
    puts "   Result: SUCCESS - No error raised, parsed as: #{result.inspect}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
  
  # Test 6: Invalid assignment
  puts "\n6. Testing invalid assignment: '42 = x'"
  begin
    lexer = Lexer.new("42 = x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    result = parser.parse
    puts "   Result: SUCCESS - No error raised, parsed as: #{result.class}"
  rescue => e
    puts "   Result: ERROR - #{e.class}: #{e.message}"
  end
end

test_current_behavior