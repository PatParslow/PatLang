#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

# Test script to diagnose critical string evaluation and function system issues

puts "=== PATLANG CRITICAL ISSUES DIAGNOSTIC ==="
puts

def test_string_evaluation
  puts "1. STRING EVALUATION ISSUES TESTING"
  puts "-" * 40
  
  test_cases = [
    { code: '"hello"', expected: "hello", desc: "Simple string literal" },
    { code: '"hello" + "world"', expected: "helloworld", desc: "String concatenation" },
    { code: '"hello" + 123', expected: "hello123", desc: "String + number concatenation" },
    { code: 'x = "test"; x', expected: "test", desc: "String variable assignment and retrieval" }
  ]
  
  test_cases.each_with_index do |test_case, i|
    puts "\nTest #{i+1}: #{test_case[:desc]}"
    puts "Code: #{test_case[:code]}"
    puts "Expected: #{test_case[:expected].inspect}"
    
    begin
      lexer = Lexer.new(test_case[:code])
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.map(&:to_s).join(', ')}"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "AST: #{ast}"
      
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      puts "Result: #{result.inspect}"
      
      if result == test_case[:expected]
        puts "✓ PASS"
      elsif result.nil?
        puts "✗ FAIL - Returned nil instead of expected value"
      else
        puts "✗ FAIL - Got #{result.inspect}, expected #{test_case[:expected].inspect}"
      end
      
    rescue => e
      puts "✗ ERROR: #{e.class}: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3).join('; ')}"
    end
  end
end

def test_function_system
  puts "\n2. FUNCTION SYSTEM ISSUES TESTING"
  puts "-" * 40
  
  test_cases = [
    {
      code: 'make a function called test { return "hello" }',
      desc: "Function definition"
    },
    {
      code: 'make a function called add takes: x, y { return x + y }; call add(2, 3)',
      expected: 5,
      desc: "Function definition and call"
    }
  ]
  
  test_cases.each_with_index do |test_case, i|
    puts "\nTest #{i+1}: #{test_case[:desc]}"
    puts "Code: #{test_case[:code]}"
    
    begin
      lexer = Lexer.new(test_case[:code])
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.length} tokens"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "AST: #{ast.class}"
      
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      puts "Result: #{result.inspect}"
      puts "Functions registered: #{evaluator.functions.keys}"
      
      if test_case[:expected] && result == test_case[:expected]
        puts "✓ PASS"
      elsif test_case[:expected] && result != test_case[:expected]
        puts "✗ FAIL - Got #{result.inspect}, expected #{test_case[:expected].inspect}"
      else
        puts "- Function registered"
      end
      
    rescue => e
      puts "✗ ERROR: #{e.class}: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3).join('; ')}"
    end
  end
end

def test_method_resolution
  puts "\n3. PARSER METHOD RESOLUTION ISSUES TESTING"
  puts "-" * 40
  
  test_cases = [
    { code: '"hello".length', desc: "String method call" },
    { code: 'x :: number', desc: "Type constraint syntax" }
  ]
  
  test_cases.each_with_index do |test_case, i|
    puts "\nTest #{i+1}: #{test_case[:desc]}"
    puts "Code: #{test_case[:code]}"
    
    begin
      lexer = Lexer.new(test_case[:code])
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.map(&:to_s).join(', ')}"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "AST: #{ast}"
      puts "AST class: #{ast.class}"
      
      # Check if AST node has expected methods
      if ast.respond_to?(:object) && ast.object.respond_to?(:name)
        puts "AST object.name: #{ast.object.name}"
      elsif ast.respond_to?(:object)
        puts "AST object: #{ast.object}, class: #{ast.object.class}"
      else
        puts "AST structure: #{ast.inspect}"
      end
      
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      puts "Result: #{result.inspect}"
      puts "✓ PASS - No method resolution errors"
      
    rescue NoMethodError => e
      puts "✗ METHOD ERROR: #{e.message}"
      puts "Missing method on: #{e.receiver.class}" if e.receiver
    rescue => e
      puts "✗ ERROR: #{e.class}: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3).join('; ')}"
    end
  end
end

def test_integration_issues
  puts "\n4. INTEGRATION ISSUES TESTING"
  puts "-" * 40
  
  # Test the interaction between components
  puts "\nTesting evaluate_string method availability:"
  evaluator = Evaluator.new
  if evaluator.respond_to?(:evaluate_string)
    puts "✓ evaluate_string method available"
    
    begin
      result = evaluator.evaluate_string('"test"')
      puts "✓ evaluate_string works: #{result.inspect}"
    rescue => e
      puts "✗ evaluate_string fails: #{e.message}"
    end
  else
    puts "✗ evaluate_string method missing"
  end
end

# Run all diagnostic tests
test_string_evaluation
test_function_system  
test_method_resolution
test_integration_issues

puts "\n=== DIAGNOSTIC SUMMARY ==="
puts "Review the output above to identify:"
puts "1. String operations returning nil instead of values"
puts "2. Function storage/retrieval problems"  
puts "3. AST node method resolution issues"
puts "4. Integration problems between components"