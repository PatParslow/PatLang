#!/usr/bin/env ruby
# Test script to validate AST node serialization fix

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

def test_undefined_function_fix
  puts "Testing undefined function call fix..."
  
  input = "call nonexistent_function"
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    # This should raise an exception but not hang due to infinite recursion
    start_time = Time.now
    result = evaluator.evaluate(ast)
    
  rescue => error
    end_time = Time.now
    duration = end_time - start_time
    
    puts "✓ Test completed in #{duration.round(2)} seconds"
    puts "✓ Error raised as expected: #{error.class}"
    puts "✓ Error message: #{error.message}"
    
    if duration < 5.0  # Should complete quickly now
      puts "✓ SUCCESS: No infinite recursion detected"
      return true
    else
      puts "✗ FAILURE: Test took too long, possible hanging"
      return false
    end
  end
  
  puts "✗ FAILURE: Expected an error but none was raised"
  false
end

def test_normal_function_still_works
  puts "\nTesting normal function still works..."
  
  input = <<~PATLANG
    make a function called test {
      return "success"
    }
    call test
  PATLANG
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    
    if result == "success"
      puts "✓ SUCCESS: Normal function calls still work"
      return true
    else
      puts "✗ FAILURE: Unexpected result: #{result}"
      return false
    end
  rescue => error
    puts "✗ FAILURE: Unexpected error: #{error.message}"
    return false
  end
end

puts "=" * 50
puts "AST Node Serialization Fix Validation"
puts "=" * 50

test1_passed = test_undefined_function_fix
test2_passed = test_normal_function_still_works

puts "\n" + "=" * 50
if test1_passed && test2_passed
  puts "✓ ALL TESTS PASSED - Fix is working correctly"
  exit 0
else
  puts "✗ SOME TESTS FAILED - Fix needs investigation"
  exit 1
end