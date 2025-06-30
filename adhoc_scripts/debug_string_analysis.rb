#!/usr/bin/env ruby

# String-related test failure analysis
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "=== STRING-RELATED TEST FAILURES ANALYSIS ==="
puts ""

# Test the number.length() issue
puts "1. NUMBER LENGTH ISSUE:"
puts "   Problem: Numbers stored as floats, so length includes decimal point"
puts ""

test_cases = [
  ['1.length()', 1, '1 -> 1.0 -> "1.0" (3 chars, expected 1)'],
  ['42.length()', 2, '42 -> 42.0 -> "42.0" (4 chars, expected 2)'],
  ['123.length()', 3, '123 -> 123.0 -> "123.0" (5 chars, expected 3)'],
  ['12345.length()', 5, '12345 -> 12345.0 -> "12345.0" (7 chars, expected 5)']
]

test_cases.each do |code, expected, description|
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.expression
  evaluator = Evaluator.new
  actual = evaluator.evaluate(ast)
  
  puts "   #{code} => Expected: #{expected}, Actual: #{actual}"
  puts "   Reason: #{description}"
  puts ""
end

puts "2. ERROR MESSAGE MISMATCH ISSUE:"
puts "   Problem: Tests expect 'integer' but code says 'number'"
puts ""

# Test error message
begin
  lexer = Lexer.new('"hello".substring("bad", 2)')
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.expression
  evaluator = Evaluator.new
  evaluator.evaluate(ast)
rescue => e
  puts "   Current error: #{e.message}"
  puts "   Expected pattern: /String.substring start must be an integer/"
  puts "   This mismatch causes test failures"
  puts ""
end

puts "3. SUMMARY OF STRING-RELATED FAILURES:"
puts ""
puts "   Type 1: Number.length() method returns wrong values"
puts "   - Affects: TestExtendedStringMethods#test_number_length_method"
puts "   - Affects: TestExtendedStringMethods#test_number_method_with_variables" 
puts "   - Affects: TestEvaluator#test_number_method_comprehensive"
puts "   - Affects: TestEvaluatorEdgeCases#test_method_call_branches"
puts "   - Root cause: All numbers stored as floats (e.g., 1 -> 1.0)"
puts ""
puts "   Type 2: Error message text mismatches"
puts "   - Affects: TestEvaluator#test_string_method_argument_validation"
puts "   - Affects: TestEvaluator#test_string_indexing_comprehensive_errors"
puts "   - Affects: TestEvaluatorEdgeCases#test_comprehensive_error_conditions"
puts "   - Root cause: Code says 'number' but tests expect 'integer'"
puts ""

puts "4. PROPOSED FIXES:"
puts ""
puts "   Fix 1: Modify number.length() method to handle integer display"
puts "   - In StringEvaluator#handle_number_method"
puts "   - Convert float to int for display if it's a whole number"
puts ""
puts "   Fix 2: Update error messages to use 'integer' instead of 'number'"
puts "   - In StringEvaluator validation messages"
puts "   - Update both indexing and method argument errors"
puts ""

puts "5. NON-STRING ISSUES (not in scope):"
puts "   - Control flow evaluator errors (NoMethodError: undefined method `[]')"
puts "   - Parser block expectation failures" 
puts "   - Lexer token type mismatches (A vs IDENTIFIER)"
puts "   - Function parsing errors"
puts ""

puts "=== ANALYSIS COMPLETE ==="