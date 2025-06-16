#!/usr/bin/env ruby

# Division by Zero Fix Validation Script
# This script validates that the division by zero error handling is working correctly

puts "=" * 60
puts "DIVISION BY ZERO FIX VALIDATION"
puts "=" * 60
puts

# Add current directory and test helpers to load path
$LOAD_PATH.unshift(File.expand_path('.', __dir__))
$LOAD_PATH.unshift(File.expand_path('./test/helpers', __dir__))

begin
  # Require necessary test infrastructure
  puts "Loading test infrastructure..."
  require_relative 'test/helpers/test_helper'
  require_relative 'test/ruby_implementation/test_function_evaluator'
  puts "✓ Test infrastructure loaded successfully"
  puts
  
  # Create test instance
  puts "Creating test instance..."
  test_instance = TestFunctionEvaluator.new("test_function_with_runtime_error")
  test_instance.setup
  puts "✓ Test instance created and setup complete"
  puts
  
  # Run the specific division by zero test
  puts "Running division by zero test..."
  puts "Test method: test_function_with_runtime_error"
  puts "Expected: PatlangDivisionByZeroError should be raised"
  puts "-" * 40
  
  test_passed = false
  error_details = nil
  
  begin
    # Call the specific test method
    test_instance.test_function_with_runtime_error
    
    # If we reach here, the test didn't raise the expected error
    test_passed = false
    error_details = "TEST FAILED: No error was raised, but PatlangDivisionByZeroError was expected"
    
  rescue PatlangDivisionByZeroError => e
    # This is the expected error - test should pass
    test_passed = true
    error_details = "✓ CORRECT: PatlangDivisionByZeroError was raised as expected"
    puts "Error message: #{e.message}"
    puts "Error class: #{e.class}"
    
  rescue => e
    # Wrong type of error was raised
    test_passed = false
    error_details = "TEST FAILED: Wrong error type raised"
    puts "Expected: PatlangDivisionByZeroError"
    puts "Actual: #{e.class}"
    puts "Message: #{e.message}"
    puts "Backtrace (first 10 lines):"
    puts e.backtrace[0..9].join("\n") if e.backtrace
  end
  
  puts "-" * 40
  puts
  
  # Report results
  if test_passed
    puts "🎉 TEST PASSED!"
    puts "The division by zero fix is working correctly."
    puts error_details
  else
    puts "❌ TEST FAILED!"
    puts error_details
    puts
    puts "DIAGNOSTIC INFORMATION:"
    puts "- The test expects PatlangDivisionByZeroError to be raised"
    puts "- This error should be thrown when dividing by zero in a function"
    puts "- Check the evaluator's arithmetic operations handling"
  end
  
rescue LoadError => e
  puts "❌ SETUP FAILED: Could not load required files"
  puts "Error: #{e.message}"
  puts "Make sure you're running this from the project root directory"
  
rescue => e
  puts "❌ UNEXPECTED ERROR during test setup"
  puts "Error class: #{e.class}"
  puts "Error message: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.join("\n") if e.backtrace
end

puts
puts "=" * 60
puts "VALIDATION COMPLETE"
puts "=" * 60