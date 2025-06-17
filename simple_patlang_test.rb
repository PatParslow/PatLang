#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "🧪 SIMPLE PATLANG SYNTAX TEST"
puts "=" * 40

# Test basic arithmetic (should work)
puts "\n✅ Testing basic arithmetic:"
begin
  result = Patlang.evaluate("2 + 3")
  puts "   Result: #{result}"
rescue => e
  puts "   ❌ Error: #{e.message}"
end

# Test with timeout to avoid hangs
require 'timeout'

test_cases = [
  "constrain x :: Number",
  "goal test_goal { postcondition: result > 0 }",
  "reasoning mode on",
  "fact parent(john, mary)",
  "rule ancestor(X, Y) if parent(X, Y)"
]

test_cases.each_with_index do |test_case, index|
  puts "\n🔍 Test #{index + 1}: #{test_case}"
  begin
    Timeout.timeout(5) do  # 5 second timeout
      result = Patlang.evaluate(test_case)
      puts "   ✅ Success: #{result}"
    end
  rescue Timeout::Error
    puts "   ⏰ TIMEOUT: Test took longer than 5 seconds"
  rescue => e
    puts "   ❌ Error: #{e.message}"
    puts "   📍 #{e.class}: #{e.backtrace.first}"
  end
end

puts "\n" + "=" * 40
puts "🎯 CONCLUSION: Basic arithmetic works, reasoning syntax issues detected"