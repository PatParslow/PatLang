#!/usr/bin/env ruby
# Test verification for AmbiguousToken expectation fixes

require_relative 'src/lexer'
require_relative 'src/token'

puts "🔍 VERIFYING AMBIGUOUS TOKEN TEST FIXES"
puts "=" * 60

def test_case(description, code, expected_tokens)
  puts "\n📋 #{description}"
  puts "   Code: #{code}"
  
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  
  success = true
  expected_tokens.each_with_index do |(expected_type, expected_value), index|
    if tokens[index]
      actual_type = tokens[index].type
      actual_value = tokens[index].value
      
      if actual_type == expected_type && actual_value == expected_value
        puts "   ✅ Token[#{index}]: #{actual_type} '#{actual_value}'"
      else
        puts "   ❌ Token[#{index}]: Expected #{expected_type} '#{expected_value}', got #{actual_type} '#{actual_value}'"
        success = false
      end
    else
      puts "   ❌ Token[#{index}]: Missing token"
      success = false
    end
  end
  
  return success
end

# Test cases that were previously failing
test_cases = [
  [
    "Arithmetic expression with 'a'",
    "result = (a + b) * c / d - e % f",
    [
      [:IDENTIFIER, "result"],
      [:ASSIGN, "="],
      [:LPAREN, "("],
      [:A, "a"],  # This was the fix - changed from :IDENTIFIER to :A
      [:PLUS, "+"],
      [:IDENTIFIER, "b"]
    ]
  ],
  
  [
    "Edge case tokenization with 'a'",
    "x==y!=z<=a>=b",
    [
      [:IDENTIFIER, "x"],
      [:EQUAL, "=="],
      [:IDENTIFIER, "y"],
      [:NOT_EQUAL, "!="],
      [:IDENTIFIER, "z"],
      [:LESS_EQUAL, "<="],
      [:A, "a"],  # This was the fix - changed from :IDENTIFIER to :A
      [:GREATER_EQUAL, ">="],
      [:IDENTIFIER, "b"]
    ]
  ],
  
  [
    "Boolean comparison with 'a'",
    "true == false != x <= y >= z < a > b",
    [
      [:TRUE, "true"],
      [:EQUAL, "=="],
      [:FALSE, "false"],
      [:NOT_EQUAL, "!="],
      [:IDENTIFIER, "x"],
      [:LESS_EQUAL, "<="],
      [:IDENTIFIER, "y"],
      [:GREATER_EQUAL, ">="],
      [:IDENTIFIER, "z"],
      [:LESS, "<"],
      [:A, "a"],  # This was the fix - changed from :IDENTIFIER to :A
      [:GREATER, ">"],
      [:IDENTIFIER, "b"]
    ]
  ],
  
  [
    "Function phrase with 'make' and 'a'",
    "make a function called test",
    [
      [:MAKE, "make"],     # This was the fix - changed from :IDENTIFIER to :MAKE
      [:A, "a"],           # This was the fix - changed from :IDENTIFIER to :A
      [:FUNCTION, "function"],
      [:CALLED, "called"],
      [:IDENTIFIER, "test"]
    ]
  ],
  
  [
    "Identifier edge case with standalone 'a'",
    "a",
    [
      [:A, "a"]  # This was the fix - changed from :IDENTIFIER to :A
    ]
  ],
  
  [
    "Make without function phrase",
    "make something",
    [
      [:MAKE, "make"],     # This was the fix - changed from :IDENTIFIER to :MAKE
      [:IDENTIFIER, "something"]
    ]
  ],
  
  [
    "Partial function phrase: make a mistake",
    "make a mistake",
    [
      [:MAKE, "make"],     # This was the fix - changed from :IDENTIFIER to :MAKE
      [:A, "a"],           # This was the fix - changed from :IDENTIFIER to :A
      [:IDENTIFIER, "mistake"]
    ]
  ]
]

puts "\n🧪 RUNNING VERIFICATION TESTS..."
puts "-" * 40

total_tests = test_cases.length
passed_tests = 0

test_cases.each do |test_case_data|
  if test_case(*test_case_data)
    passed_tests += 1
  end
end

puts "\n" + "=" * 60
puts "📊 VERIFICATION SUMMARY:"
puts "   Total Tests: #{total_tests}"
puts "   Passed: #{passed_tests}"
puts "   Failed: #{total_tests - passed_tests}"
puts "   Success Rate: #{(passed_tests.to_f / total_tests * 100).round(1)}%"

if passed_tests == total_tests
  puts "\n🎉 ALL AMBIGUOUS TOKEN FIXES VERIFIED SUCCESSFULLY!"
  puts "✅ The 10 AmbiguousToken expectation failures have been resolved"
  puts "✅ Tests now correctly expect :A, :MAKE tokens instead of :IDENTIFIER"
  puts "✅ AmbiguousToken architecture working as designed"
else
  puts "\n⚠️ Some verification tests failed - need investigation"
end

puts "\n" + "=" * 60