#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "Testing String-Related Fixes"
puts "="*40

# Test 1: Number.length() method for whole numbers
puts "\n1. Testing Number.length() for whole numbers:"
test_cases = [
  { code: "1.length()", expected: 1, description: "1 should have length 1" },
  { code: "12345.length()", expected: 5, description: "12345 should have length 5" },
  { code: "0.length()", expected: 1, description: "0 should have length 1" },
  { code: "3.14.length()", expected: 4, description: "3.14 should have length 4 (includes decimal)" }
]

test_cases.each do |test|
  begin
    result = Patlang.evaluate(test[:code])
    if result == test[:expected]
      puts "  ✅ #{test[:description]} - PASS"
    else
      puts "  ❌ #{test[:description]} - FAIL (got #{result}, expected #{test[:expected]})"
    end
  rescue => e
    puts "  ❌ #{test[:description]} - ERROR: #{e.message}"
  end
end

# Test 2: Error message terminology
puts "\n2. Testing error message terminology:"
error_test_cases = [
  { code: '"hello"["not_a_number"]', expected_error: "integer", description: "String index error should mention 'integer'" },
  { code: '"test".substring("not_a_number", 1)', expected_error: "integer", description: "Substring start error should mention 'integer'" },
  { code: '"test".substring(1, "not_a_number")', expected_error: "integer", description: "Substring length error should mention 'integer'" }
]

error_test_cases.each do |test|
  begin
    result = Patlang.evaluate(test[:code])
    puts "  ❌ #{test[:description]} - FAIL (should have raised error)"
  rescue => e
    if e.message.include?(test[:expected_error])
      puts "  ✅ #{test[:description]} - PASS"
    else
      puts "  ❌ #{test[:description]} - FAIL (error: #{e.message})"
    end
  end
end

puts "\n" + "="*40
puts "String fixes verification complete!"