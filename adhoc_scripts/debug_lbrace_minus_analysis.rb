#!/usr/bin/env ruby

# LBRACE and MINUS Token Analysis Script
# This script analyzes the specific failures related to LBRACE and MINUS tokens

puts "🔍 ANALYZING LBRACE AND MINUS TOKEN FAILURES"
puts "=" * 60

# Extract LBRACE-related failures from test output
lbrace_failures = [
  {
    test: "TestFunctionParser#test_function_definition_with_parameters_and_return_type",
    error: "Expected LBRACE, got MINUS at token Token(MINUS, -)",
    location: "src/parser/function_parser.rb:63",
    input_context: "Function definition with parameters and return type"
  },
  {
    test: "TestFunctionParser#test_function_definition_with_multiple_parameters", 
    error: "Expected LBRACE, got MINUS at token Token(MINUS, -)",
    location: "src/parser/function_parser.rb:63",
    input_context: "Function definition with multiple parameters"
  },
  {
    test: "TestFunctionParser#test_function_definition_with_typed_parameter",
    error: "Expected LBRACE, got MINUS at token Token(MINUS, -)",
    location: "src/parser/function_parser.rb:63", 
    input_context: "Function definition with typed parameter"
  }
]

# Extract MINUS-related failures from test output
minus_failures = [
  {
    test: "TestParser#test_parse_simple_while_statement",
    issue: "MINUS operator in arithmetic expression (x - 1)",
    node_type: "BinaryOpNode with operator='-'",
    context: "While loop with decrement operation"
  },
  {
    test: "TestParser#test_parse_if_else_statement", 
    issue: "MINUS as unary operator (-1)",
    node_type: "UnaryOpNode with operator='-'",
    context: "Negative number in if/else statement"
  }
]

puts "\n📊 LBRACE FAILURE ANALYSIS"
puts "-" * 40

puts "Total LBRACE failures: #{lbrace_failures.length}"
puts "\nFailure Pattern:"
lbrace_failures.each_with_index do |failure, i|
  puts "#{i+1}. #{failure[:test]}"
  puts "   Error: #{failure[:error]}"
  puts "   Location: #{failure[:location]}"
  puts "   Context: #{failure[:input_context]}"
  puts
end

puts "🎯 LBRACE Root Cause Assessment:"
puts "- All 3 failures occur at the same location: function_parser.rb:63"
puts "- All involve 'Expected LBRACE, got MINUS' error"
puts "- Pattern suggests parser expects '{' but encounters '-' instead"
puts "- Likely issue: Function parameter parsing incorrectly consumes MINUS tokens"

puts "\n📊 MINUS FAILURE ANALYSIS" 
puts "-" * 40

puts "Total MINUS failures: #{minus_failures.length}"
puts "\nFailure Pattern:"
minus_failures.each_with_index do |failure, i|
  puts "#{i+1}. #{failure[:test]}"
  puts "   Issue: #{failure[:issue]}"
  puts "   Node Type: #{failure[:node_type]}"
  puts "   Context: #{failure[:context]}"
  puts
end

puts "🎯 MINUS Root Cause Assessment:"
puts "- MINUS token correctly parsed in arithmetic contexts"
puts "- Both unary (-1) and binary (x - 1) MINUS operations working"
puts "- Issue appears to be structural (BlockNode expectations) not MINUS parsing"

puts "\n🔍 CROSS-PATTERN ANALYSIS"
puts "-" * 40

puts "Key Insight: LBRACE and MINUS failures are RELATED!"
puts "- Function parser expects LBRACE ({) to start function body"
puts "- But encounters MINUS (-) token instead"
puts "- Suggests parameter parsing consumes too many tokens"
puts "- MINUS token gets consumed during parameter parsing phase"

puts "\n📈 SEVERITY ASSESSMENT"
puts "-" * 30

puts "LBRACE Issues:"
puts "- ❌ HIGH: Blocks function definitions with parameters"
puts "- ❌ HIGH: Affects fundamental language constructs"
puts "- ❌ HIGH: 3 distinct test categories failing"

puts "\nMINUS Issues:"
puts "- ✅ LOW: MINUS parsing actually works correctly"
puts "- ✅ LOW: Arithmetic operations functioning"
puts "- ⚠️  MEDIUM: Structural issues with BlockNode expectations"

puts "\n🎯 RECOMMENDED PRIORITY ORDER"
puts "-" * 35

puts "1. HIGHEST: Fix LBRACE expectation in function_parser.rb:63"
puts "   - Investigate parameter parsing token consumption"
puts "   - Check if MINUS being incorrectly consumed as parameter"
puts "   - Root cause likely in function parameter parsing logic"

puts "2. MEDIUM: Address BlockNode structure expectations" 
puts "   - Parser creating correct nodes but test expects BlockNode wrappers"
puts "   - May be test issue rather than parser issue"

puts "3. LOWER: MINUS token handling (appears functional)"
puts "   - MINUS operations work in arithmetic contexts"
puts "   - Issue is positioning/consumption, not parsing"

puts "\n✅ ANALYSIS COMPLETE"
puts "Focus area: function_parser.rb parameter parsing logic"