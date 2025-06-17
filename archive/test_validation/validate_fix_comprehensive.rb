#!/usr/bin/env ruby
# Comprehensive validation of the AST serialization fix

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

def test_specific_hanging_scenario
  puts "Testing the exact scenario that was hanging..."
  
  # This is the exact test case from test_function_integration.rb line 512-521
  input = "call nonexistent_function"
  
  start_time = Time.now
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    # This should raise a RuntimeError but not hang
    result = evaluator.evaluate(ast)
    
    end_time = Time.now
    puts "✗ UNEXPECTED: No error was raised"
    return false
    
  rescue RuntimeError => error
    end_time = Time.now
    duration = end_time - start_time
    
    puts "✓ Test completed in #{duration.round(3)} seconds"
    puts "✓ Correct error type: #{error.class}"
    puts "✓ Error message: #{error.message}"
    
    # Check if it contains the expected message
    if error.message.include?("Undefined function: nonexistent_function")
      puts "✓ Correct error message format"
    else
      puts "⚠ Warning: Error message format different than expected"
      puts "  Expected to contain: 'Undefined function: nonexistent_function'"
    end
    
    # Most importantly, check that it completed quickly (no infinite recursion)
    if duration < 2.0
      puts "✓ SUCCESS: No infinite recursion - completed quickly"
      return true
    else
      puts "✗ FAILURE: Test took #{duration} seconds - may still be hanging"
      return false
    end
    
  rescue => error
    end_time = Time.now
    duration = end_time - start_time
    
    puts "✓ Test completed in #{duration.round(3)} seconds"
    puts "✓ Error raised: #{error.class}"
    puts "✓ Error message: #{error.message}"
    
    if duration < 2.0
      puts "✓ SUCCESS: No infinite recursion detected"
      return true
    else
      puts "✗ FAILURE: Test took too long"
      return false
    end
  end
end

def test_arguments_with_parameters_scenario
  puts "\nTesting wrong parameter count scenario..."
  
  # Test the other PatlangFunctionError case
  input = <<~PATLANG
    make a function called test takes: a, b {
      return a + b
    }
    call test with 5
  PATLANG
  
  start_time = Time.now
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    
    puts "✗ UNEXPECTED: No error was raised"
    return false
    
  rescue => error
    end_time = Time.now
    duration = end_time - start_time
    
    puts "✓ Test completed in #{duration.round(3)} seconds"
    puts "✓ Error raised: #{error.class}"
    puts "✓ Error message: #{error.message}"
    
    if duration < 2.0
      puts "✓ SUCCESS: No infinite recursion in parameter count validation"
      return true
    else
      puts "✗ FAILURE: Test took too long"
      return false
    end
  end
end

def test_normal_function_works
  puts "\nTesting that normal functions still work..."
  
  input = <<~PATLANG
    make a function called greet takes: name {
      return "Hello, " + name + "!"
    }
    call greet with "World"
  PATLANG
  
  begin
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    
    if result == "Hello, World!"
      puts "✓ SUCCESS: Normal function calls work correctly"
      return true
    else
      puts "✗ FAILURE: Unexpected result: #{result.inspect}"
      return false
    end
  rescue => error
    puts "✗ FAILURE: Unexpected error in normal function: #{error.message}"
    return false
  end
end

puts "=" * 60
puts "COMPREHENSIVE AST SERIALIZATION FIX VALIDATION"
puts "=" * 60

test1 = test_specific_hanging_scenario
test2 = test_arguments_with_parameters_scenario  
test3 = test_normal_function_works

puts "\n" + "=" * 60
puts "SUMMARY:"
puts "- Undefined function test: #{test1 ? 'PASS' : 'FAIL'}"
puts "- Wrong parameter count test: #{test2 ? 'PASS' : 'FAIL'}"
puts "- Normal function test: #{test3 ? 'PASS' : 'FAIL'}"

if test1 && test2 && test3
  puts "\n✓ ALL TESTS PASSED - AST serialization fix is working!"
  puts "The hanging integration test should now complete successfully."
  exit 0
else
  puts "\n✗ SOME TESTS FAILED - Fix needs more investigation."
  exit 1
end