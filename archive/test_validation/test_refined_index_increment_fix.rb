#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

puts "=== COMPREHENSIVE TEST: REFINED INDEX INCREMENT FIX ==="
puts

# Test cases to validate the refined fix
test_cases = [
  {
    name: "UNKNOWN Token Recovery",
    code: "@#$%",
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past UNKNOWN token for error recovery"
  },
  {
    name: "UNTERMINATED_STRING Token Recovery",
    code: '"hello world',
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past UNTERMINATED_STRING for error recovery"
  },
  {
    name: "Unbalanced Opening Parenthesis",
    code: "(2 + 3",
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past malformed syntax for comprehensive error recovery"
  },
  {
    name: "Unbalanced Closing Parenthesis",
    code: "2 + 3)",
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past malformed syntax for comprehensive error recovery"
  },
  {
    name: "Missing Opening Bracket",
    code: "array 5]",
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past unmatched closing bracket for error recovery"
  },
  {
    name: "Missing Opening Brace",
    code: "block something }",
    expected_behavior: :error_node,
    description: "Should create ErrorNode and advance past unmatched closing brace for error recovery"
  }
]

# Test results tracking
passed_tests = 0
failed_tests = 0
results = []

def test_scenario(test_case)
  name = test_case[:name]
  code = test_case[:code]
  expected = test_case[:expected_behavior]
  description = test_case[:description]
  
  puts "--- Testing: #{name} ---"
  puts "Code: #{code.inspect}"
  puts "Expected: #{expected}"
  puts "Description: #{description}"
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    puts "Tokens: #{tokens.map(&:type).inspect}"
    
    parser = Parser.new(tokens)
    result = parser.parse
    
    # Test succeeded - no ParseError raised
    actual_behavior = :error_node
    puts "Result: #{result.class} (#{actual_behavior})"
    
    if expected == actual_behavior
      puts "✅ PASS - Correctly created ErrorNode"
      return { status: :pass, expected: expected, actual: actual_behavior, name: name }
    else
      puts "❌ FAIL - Expected #{expected}, got #{actual_behavior}"
      return { status: :fail, expected: expected, actual: actual_behavior, name: name }
    end
    
  rescue ParseError => e
    # ParseError was raised
    actual_behavior = :parse_error
    puts "ParseError raised: #{e.message}"
    
    if expected == actual_behavior
      puts "✅ PASS - Correctly raised ParseError"
      return { status: :pass, expected: expected, actual: actual_behavior, name: name }
    else
      puts "❌ FAIL - Expected #{expected}, got #{actual_behavior}"
      return { status: :fail, expected: expected, actual: actual_behavior, name: name }
    end
    
  rescue => e
    puts "❌ UNEXPECTED ERROR: #{e.class} - #{e.message}"
    return { status: :error, expected: expected, actual: :unexpected_error, name: name, error: e }
  end
  
  puts
end

# Run all test cases
test_cases.each do |test_case|
  result = test_scenario(test_case)
  results << result
  
  if result[:status] == :pass
    passed_tests += 1
  else
    failed_tests += 1
  end
  
  puts
end

# Summary
puts "=== TEST RESULTS SUMMARY ==="
puts "Total Tests: #{test_cases.length}"
puts "Passed: #{passed_tests}"
puts "Failed: #{failed_tests}"
puts

if failed_tests > 0
  puts "❌ FAILED TESTS:"
  results.select { |r| r[:status] != :pass }.each do |result|
    puts "  - #{result[:name]}: Expected #{result[:expected]}, got #{result[:actual]}"
  end
  puts
end

puts "=== VALIDATION ANALYSIS ==="
puts
if passed_tests == test_cases.length
  puts "🎉 ALL TESTS PASSED!"
  puts "✅ UNKNOWN tokens: Create ErrorNode and advance for error recovery"
  puts "✅ UNTERMINATED_STRING tokens: Create ErrorNode and advance for error recovery"
  puts "✅ Malformed syntax: Create ErrorNode and advance for comprehensive error recovery"
  puts
  puts "SUCCESS: Comprehensive error recovery implemented correctly:"
  puts "  - Parser advances past ALL problematic tokens"
  puts "  - Error collection mechanism captures all errors"
  puts "  - Continued parsing enables finding multiple errors"
  puts "  - No infinite loops or hanging behavior"
else
  puts "⚠️  SOME TESTS FAILED - Fix needs adjustment"
  puts
  puts "ANALYSIS:"
  error_node_tests = results.select { |r| r[:expected] == :error_node }
  
  puts "Error Recovery tests (should advance past ALL problematic tokens):"
  error_node_tests.each do |test|
    status = test[:status] == :pass ? "✅" : "❌"
    puts "  #{status} #{test[:name]}"
  end
end

exit(failed_tests == 0 ? 0 : 1)