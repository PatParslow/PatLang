#!/usr/bin/env ruby

# Test runner for the specific division by zero test method
puts "=" * 60
puts "RUNNING SPECIFIC DIVISION BY ZERO TEST METHOD"
puts "=" * 60
puts

require_relative 'test/helpers/test_helper'
require_relative 'test/ruby_implementation/test_function_evaluator'

begin
  puts "Creating test instance..."
  test_instance = TestFunctionEvaluator.new('test_function_with_runtime_error')
  test_instance.setup
  puts "✓ Test instance created successfully"
  puts
  
  puts "Running test_function_with_runtime_error method..."
  puts "This test should expect PatlangDivisionByZeroError to be raised"
  puts "-" * 40
  
  begin
    # Run the specific test method
    test_instance.test_function_with_runtime_error
    puts "✅ TEST PASSED!"
    puts "The test_function_with_runtime_error method completed successfully."
    puts "This means PatlangDivisionByZeroError was properly raised and caught."
    
  rescue Minitest::Assertion => e
    puts "❌ TEST ASSERTION FAILED!"
    puts "Error: #{e.message}"
    puts
    puts "This means the test's expectations were not met."
    puts "The division by zero fix may not be working as expected."
    
  rescue => e
    puts "❌ UNEXPECTED ERROR during test execution!"
    puts "Error class: #{e.class}"
    puts "Error message: #{e.message}"
    puts
    puts "Backtrace (first 5 lines):"
    e.backtrace[0..4].each do |line|
      puts "  #{line}"
    end
  end
  
rescue => e
  puts "❌ SETUP ERROR!"
  puts "Error class: #{e.class}"
  puts "Error message: #{e.message}"
  puts
  puts "Could not set up the test properly."
end

puts
puts "=" * 60
puts "TEST EXECUTION COMPLETE"
puts "=" * 60