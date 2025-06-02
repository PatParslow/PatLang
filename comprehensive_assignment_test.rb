#!/usr/bin/env ruby

require_relative 'src/patlang'

puts '🎯 COMPREHENSIVE ASSIGNMENT PARSING VERIFICATION'
puts '=' * 60

def test_case(description, code, expected_result = nil)
  puts "\n#{description}"
  puts "Code: #{code}"
  puts "Expected: #{expected_result}" if expected_result
  
  begin
    result = Patlang.evaluate(code)
    puts "✅ SUCCESS: #{result.inspect}"
    return { status: :success, result: result }
  rescue => e
    puts "❌ ERROR: #{e.message}"
    return { status: :error, error: e.message }
  end
end

results = {}

puts "\n🔍 1. AMBIGUOUS TOKEN TESTING - MAKE KEYWORD DISAMBIGUATION"
puts '=' * 55

results[:ambiguous] = []
results[:ambiguous] << test_case(
  "Variable assignment with 'make'",
  'make = 5',
  "Should assign 5 to variable 'make'"
)

results[:ambiguous] << test_case(
  "Function definition with 'make'", 
  'make a function called test { return 1 }',
  "Should define function 'test'"
)

results[:ambiguous] << test_case(
  "Mixed: assignment then function definition",
  "make = 42\nmake a function called greet { return \"hello\" }\ncall greet",
  "Should return 'hello' from function call"
)

puts "\n🧪 2. ASSIGNMENT VS FUNCTION DEFINITION VERIFICATION"
puts '=' * 50

results[:assignments] = []
assignments = [
  ['x = 42', 42],
  ['name = "hello"', "hello"], 
  ['result = 5 + 3', 8],
  ['flag = true', true]
]

assignments.each do |code, expected|
  results[:assignments] << test_case("Assignment: #{code}", code, expected)
end

results[:functions] = []
functions = [
  'make a function called test { return 1 }',
  'make a function called greet { return "Hello" }',
  'make a function called add takes: x, y { return x + y }'
]

functions.each do |code|
  results[:functions] << test_case("Function definition: #{code}", code)
end

puts "\n🔧 3. REGRESSION TESTING - EXISTING FUNCTIONALITY"
puts '=' * 45

results[:arithmetic] = []
arithmetic_tests = [
  ['5 + 3', 8],
  ['10 - 4', 6],
  ['6 * 7', 42], 
  ['15 / 3', 5],
  ['2 + 3 * 4', 14],
  ['(2 + 3) * 4', 20]
]

arithmetic_tests.each do |code, expected|
  results[:arithmetic] << test_case("Arithmetic: #{code}", code, expected)
end

results[:control_flow] = []
control_tests = [
  ['if true then "yes" else "no" end', "yes"],
  ['if 5 > 3 then "greater" else "lesser" end', "greater"],
  ['if false then 1 else 2 end', 2]
]

control_tests.each do |code, expected|
  results[:control_flow] << test_case("Control flow: #{code}", code, expected)
end

puts "\n🧪 4. EDGE CASE TESTING"
puts '=' * 25

results[:edge_cases] = []

# Test complex mixed scenarios
results[:edge_cases] << test_case(
  "Complex mixed scenario",
  "x = 10\nmake a function called double takes: n { return n * 2 }\ny = call double with x\ny",
  20
)

# Test function calls with parameters
results[:edge_cases] << test_case(
  "Function with parameters",
  "make a function called add takes: x, y { return x + y }\ncall add with 5, 3",
  8
)

# Test nested function calls
results[:edge_cases] << test_case(
  "Nested function scenario",
  "make a function called triple takes: n { return n * 3 }\nmake a function called calc takes: x { return call triple with x + 1 }\ncall calc with 4",
  15
)

puts "\n📊 COMPREHENSIVE TEST RESULTS SUMMARY"
puts '=' * 40

total_tests = 0
passed_tests = 0
failed_tests = 0

results.each do |category, tests|
  category_passed = tests.count { |t| t[:status] == :success }
  category_total = tests.size
  total_tests += category_total
  passed_tests += category_passed
  failed_tests += (category_total - category_passed)
  
  puts "#{category.to_s.upcase}: #{category_passed}/#{category_total} passed"
end

puts "\n🎯 OVERALL RESULTS:"
puts "Total Tests: #{total_tests}"
puts "Passed: #{passed_tests}"
puts "Failed: #{failed_tests}"
puts "Success Rate: #{((passed_tests.to_f / total_tests) * 100).round(1)}%"

if failed_tests == 0
  puts "\n✅ ALL TESTS PASSED - Assignment parsing fixes are working correctly!"
else
  puts "\n❌ SOME TESTS FAILED - Assignment parsing fixes need attention"
  
  puts "\nFailed test details:"
  results.each do |category, tests|
    failed = tests.select { |t| t[:status] == :error }
    if failed.any?
      puts "#{category.to_s.upcase} failures:"
      failed.each { |t| puts "  - #{t[:error]}" }
    end
  end
end

puts "\n🏁 VERIFICATION COMPLETE"