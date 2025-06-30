#!/usr/bin/env ruby
# frozen_string_literal: true

# Test to validate parser infinite loop fixes
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/emergency_timeout'

puts "=== Parser Infinite Loop Fixes Validation ==="

# Test cases that previously caused infinite loops
test_cases = [
  {
    name: "Simple function call",
    code: "call add(2, 3)",
    expected_success: true
  },
  {
    name: "Function call with multiple arguments",
    code: "call multiply(2, 3, 4)",
    expected_success: true
  },
  {
    name: "Function call with WITH syntax",
    code: "call add with 2, 3",
    expected_success: true
  },
  {
    name: "Function call with WHICH syntax",
    code: "call func which requires: 1, 2",
    expected_success: true
  },
  {
    name: "Nested function calls",
    code: "call outer(call inner(1), 2)",
    expected_success: true
  },
  {
    name: "Complex expression with function calls",
    code: "x = call add(2, 3) + call multiply(4, 5)",
    expected_success: true
  },
  {
    name: "Function definition",
    code: "make a function called test takes: x { return x }",
    expected_success: true
  },
  {
    name: "Malformed function call (should not hang)",
    code: "call incomplete(",
    expected_success: false # Should fail gracefully, not hang
  },
  {
    name: "Deeply nested expressions",
    code: "((((((1 + 2) * 3) - 4) / 2) + 1) * 3)",
    expected_success: true
  },
  {
    name: "Complex chained method calls",
    code: "obj.method1().method2().method3()",
    expected_success: true
  }
]

successful_tests = 0
total_tests = test_cases.length

puts "Running #{total_tests} parser timeout protection tests...\n"

test_cases.each_with_index do |test_case, index|
  print "Test #{index + 1}/#{total_tests}: #{test_case[:name]}... "
  
  begin
    # Use emergency timeout to ensure test doesn't hang
    result = EmergencyTimeout.protect(5.0, error_message: "Test timeout") do
      lexer = Lexer.new(test_case[:code])
      parser = Parser.new(lexer)
      ast = parser.parse
      
      # Check if parsing succeeded
      if ast.is_a?(ErrorNode)
        { success: false, error: ast.message }
      else
        { success: true, ast: ast }
      end
    end
    
    if test_case[:expected_success]
      if result[:success]
        puts "✅ PASS"
        successful_tests += 1
      else
        puts "❌ FAIL - Expected success but got error: #{result[:error]}"
      end
    else
      # For cases expected to fail, we just want them to fail gracefully (not hang)
      puts "✅ PASS - Failed gracefully without hanging"
      successful_tests += 1
    end
    
  rescue EmergencyTimeout::TimeoutError => e
    puts "❌ FAIL - Test timed out (likely infinite loop): #{e.message}"
  rescue => e
    if test_case[:expected_success]
      puts "❌ FAIL - Unexpected error: #{e.message}"
    else
      puts "✅ PASS - Failed gracefully: #{e.message}"
      successful_tests += 1
    end
  end
end

puts "\n=== Parser Infinite Loop Fix Validation Results ==="
puts "Successful tests: #{successful_tests}/#{total_tests}"
puts "Success rate: #{(successful_tests.to_f / total_tests * 100).round(1)}%"

if successful_tests == total_tests
  puts "🎉 ALL TESTS PASSED - Parser infinite loop fixes are working correctly!"
  exit 0
else
  puts "⚠️  Some tests failed - Parser may still have infinite loop issues"
  exit 1
end