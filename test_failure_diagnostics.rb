#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "🔍 DIAGNOSING TEST FAILURES"
puts "=" * 50

puts "\n1. FUNCTION INTEGRATION TEST - OPERATOR PRECEDENCE ISSUE"
puts "-" * 50

# Test the exact failing expression from test_function_integration.rb
test_code = <<~PATLANG
  make a function called multiply takes: a, b {
    return a * b
  }
  
  make a function called add takes: a, b {
    return a + b
  }
  
  result = call multiply with 3, 4 + call add with 2, 3
  result
PATLANG

puts "Code under test:"
puts test_code
puts "\nExpected: 17 (should be: 3 * 4 + (2 + 3) = 12 + 5 = 17)"

begin
  result = Patlang.evaluate(test_code)
  puts "✅ Result: #{result}"
  puts "✅ Type: #{result.class}"
  if result == 17
    puts "✅ TEST PASSES"
  else
    puts "❌ TEST FAILS - operator precedence issue detected"
    puts "   Current parsing likely treats it as: call multiply with 3, (4 + call add with 2, 3)"
    puts "   Should be: (call multiply with 3, 4) + (call add with 2, 3)"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join('\n')}"
end

puts "\n2. LEXER COMMENT HANDLING TEST"
puts "-" * 50

# Test what the lexer tests are expecting for comment errors
puts "Testing comment handling in lexer..."

require_relative 'src/lexer'

test_cases = [
  { desc: "Simple hash character", input: "#" },
  { desc: "Hash with text", input: "# comment" },
  { desc: "Hash in expression", input: "5 + # comment\n3" },
  { desc: "Multiple hashes", input: "## double comment" }
]

test_cases.each do |test_case|
  puts "\nTesting: #{test_case[:desc]}"
  puts "Input: #{test_case[:input].inspect}"
  
  begin
    lexer = Lexer.new(test_case[:input])
    tokens = lexer.tokenize
    puts "✅ Tokens: #{tokens.map(&:type)}"
  rescue => e
    puts "❌ Error: #{e.message}"
  end
end

puts "\n3. FUNCTION CALCULATOR TEST - PARAMETER COUNT ISSUE"
puts "-" * 50

# Let's look at the other failing test from the function integration
calculator_test = <<~PATLANG
  make a function called add takes: x, y {
    return x + y
  }
  
  make a function called subtract takes: x, y {
    return x - y
  }
  
  make a function called multiply takes: x, y {
    return x * y
  }
  
  make a function called divide takes: x, y {
    return x / y
  }
  
  sum = call add with 10, 5
  diff = call subtract with 10, 5
  prod = call multiply with 10, 5
  quot = call divide with 10, 5
  
  call add with call multiply with sum, diff, prod
PATLANG

puts "Calculator test code:"
puts calculator_test

begin
  result = Patlang.evaluate(calculator_test)
  puts "✅ Result: #{result}"
rescue => e
  puts "❌ Error: #{e.message}"
  puts "This is likely the 'Function add expects 2 arguments, got 1' error"
  puts "Issue: call add with call multiply with sum, diff, prod"
  puts "Should be: call add with (call multiply with sum, diff), prod"
end

puts "\n4. SOLUTION ANALYSIS"
puts "-" * 50
puts "Issues identified:"
puts "1. Function call parsing with operator precedence needs parentheses"
puts "2. Comment handling in lexer may have changed expectations"
puts "3. Complex function call arguments need proper grouping"
puts "\nNext steps: Fix parser to handle operator precedence correctly"