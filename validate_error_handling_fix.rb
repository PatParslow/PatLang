#!/usr/bin/env ruby

# Validation script for division by zero error handling fix
# This script runs the specific test that was failing and validates the fix

require_relative 'test/helpers/test_helper'
require_relative 'test/ruby_implementation/test_function_evaluator'

puts "=" * 60
puts "VALIDATING DIVISION BY ZERO ERROR HANDLING FIX"
puts "=" * 60
puts ""

# Chain of Drafts Summary: Test expects PatlangDivisionByZeroError, not Ruby ZeroDivisionError

class ValidationRunner < Minitest::Test
  include TestFunctionEvaluator

  def run_validation
    puts "Running specific test: test_function_with_runtime_error"
    puts "Expected behavior:"
    puts "- Should throw PatlangDivisionByZeroError (not ZeroDivisionError)" 
    puts "- Error message should contain 'Division by zero'"
    puts ""
    
    begin
      # Run the specific test method
      test_result = run_single_test_method(:test_function_with_runtime_error)
      
      if test_result[:passed]
        puts "✅ TEST PASSED!"
        puts "- PatlangDivisionByZeroError is correctly thrown"
        puts "- Error message validation passed"
        puts ""
        puts "VALIDATION SUCCESSFUL: Division by zero fix is working correctly"
        return true
      else
        puts "❌ TEST FAILED!"
        puts "Error details:"
        puts test_result[:error]
        puts ""
        analyze_error(test_result[:error])
        return false
      end
      
    rescue => e
      puts "❌ VALIDATION SCRIPT ERROR!"
      puts "Error running validation: #{e.class} - #{e.message}"
      puts "Backtrace:"
      puts e.backtrace[0..5]
      return false
    end
  end
  
private

  def run_single_test_method(method_name)
    begin
      send(method_name)
      { passed: true }
    rescue => e
      { passed: false, error: e }
    end
  end
  
  def analyze_error(error)
    puts "ERROR ANALYSIS:"
    puts "- Error Class: #{error.class}"
    puts "- Error Message: #{error.message}"
    
    case error.class.to_s
    when 'ZeroDivisionError'
      puts "❌ ISSUE: Still throwing Ruby native ZeroDivisionError instead of PatlangDivisionByZeroError"
      puts "- The fix may not be properly implemented in the evaluation chain"
      puts "- Check where division operations are handled in the evaluator"
      
    when 'NameError'
      if error.message.include?('PatlangDivisionByZeroError')
        puts "❌ ISSUE: PatlangDivisionByZeroError class not found"
        puts "- Check if src/exceptions.rb is properly required"
        puts "- Verify class definition exists"
      end
      
    when 'NoMethodError'
      puts "❌ ISSUE: Method missing - #{error.message}" 
      puts "- Check test method implementation"
      
    else
      puts "❌ UNEXPECTED ERROR TYPE: #{error.class}"
      puts "- This may indicate a different problem"
    end
    
    puts ""
    puts "BACKTRACE (first 10 lines):"
    error.backtrace[0..9].each_with_index do |line, i|
      puts "  #{i+1}. #{line}"
    end
  end
end

# Run the validation
runner = ValidationRunner.new
success = runner.run_validation

puts ""
puts "=" * 60
puts success ? "VALIDATION COMPLETE: SUCCESS" : "VALIDATION COMPLETE: FAILED"  
puts "=" * 60

exit(success ? 0 : 1)