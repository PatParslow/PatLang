#!/usr/bin/env ruby

# Validation script for division by zero error handling fix
# Uses the same pattern as the test file to properly test the functionality

require_relative 'test/helpers/test_helper'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/exceptions'

puts "=" * 60
puts "VALIDATING DIVISION BY ZERO ERROR HANDLING FIX"
puts "=" * 60
puts ""

# Chain of Drafts Summary: Test division operation, expect PatlangDivisionByZeroError not ZeroDivisionError

def parse_and_evaluate(input)
  evaluator = Evaluator.new
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  evaluator.evaluate(ast)
end

# Test the exact same Patlang code from the failing test
test_input = <<~PATLANG
make a function called divide takes: x, y {
  return x / y
}
call divide(10, 0)
PATLANG

puts "Testing Patlang code:"
puts test_input
puts ""

begin
  puts "Executing division by zero operation..."
  result = parse_and_evaluate(test_input)
  
  puts "❌ UNEXPECTED SUCCESS: Code executed without throwing an error!"
  puts "Result: #{result}"
  puts "This indicates the division by zero is not being caught properly."
  exit 1
  
rescue PatlangDivisionByZeroError => e
  puts "✅ SUCCESS: PatlangDivisionByZeroError was thrown correctly!"
  puts ""
  puts "Error Details:"
  puts "- Error Class: #{e.class}"
  puts "- Error Message: '#{e.message}'"
  
  # Validate the error message contains "Division by zero"
  if e.message.match?(/Division by zero/i)
    puts "✅ Message Validation: Contains 'Division by zero' ✓"
  else
    puts "❌ Message Validation: Missing 'Division by zero'"
    puts "  Expected: Message containing 'Division by zero'"
    puts "  Actual: '#{e.message}'"
    exit 1
  end
  
  # Check additional error context if available
  if e.respond_to?(:context) && e.context
    puts "- Error Context: #{e.context}"
  end
  
  if e.respond_to?(:operator)
    puts "- Operator: #{e.operator}"
  end
  
  puts ""
  puts "✅ VALIDATION SUCCESSFUL!"
  puts "- PatlangDivisionByZeroError is properly thrown instead of ZeroDivisionError"
  puts "- Error message validation passed"
  puts "- No Ruby native exceptions leaked through"
  puts ""
  puts "The division by zero error handling fix is working correctly!"
  
rescue ZeroDivisionError => e
  puts "❌ VALIDATION FAILED: Ruby native ZeroDivisionError was thrown!"
  puts ""
  puts "Error Details:"
  puts "- Error Class: #{e.class} (should be PatlangDivisionByZeroError)"
  puts "- Error Message: '#{e.message}'"
  puts ""
  puts "ISSUE ANALYSIS:"
  puts "- The fix is not properly implemented in the evaluation chain"
  puts "- Ruby's native division operation is still being used directly"
  puts "- Need to check where arithmetic operations are handled in:"
  puts "  • src/evaluator.rb"
  puts "  • src/evaluator/arithmetic_evaluator.rb" 
  puts "  • src/evaluator/function_evaluator.rb"
  puts ""
  puts "The division operations should be wrapped to catch ZeroDivisionError"
  puts "and re-throw as PatlangDivisionByZeroError"
  exit 1
  
rescue ParseError, PatlangError => e
  puts "❌ PARSING/PATLANG ERROR: #{e.class}"
  puts "- Error Message: '#{e.message}'"
  puts "- This suggests an issue with parsing, not the division fix"
  puts ""
  puts "This may indicate the test setup has other issues that need"
  puts "to be resolved before validating the division by zero fix."
  exit 1
  
rescue => e
  puts "❌ UNEXPECTED ERROR: #{e.class}"
  puts "- Error Message: '#{e.message}'"
  puts ""
  puts "Backtrace (first 10 lines):"
  e.backtrace[0..9].each_with_index do |line, i|
    puts "  #{i+1}. #{line}"
  end
  exit 1
end

puts "=" * 60
puts "VALIDATION COMPLETE: SUCCESS"
puts "=" * 60