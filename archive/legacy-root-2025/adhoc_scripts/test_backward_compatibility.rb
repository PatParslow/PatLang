#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "🔍 BACKWARD COMPATIBILITY TEST"
puts "=" * 40

# Test cases to ensure we didn't break anything
test_cases = [
  {
    desc: "Variable assignment with 'a'",
    code: 'a = 5',
    expected: 5.0
  },
  {
    desc: "Variable assignment with 'function'", 
    code: 'function = "hello"',
    expected: "hello"
  },
  {
    desc: "Variable assignment with 'called'",
    code: 'called = 42',
    expected: 42.0
  },
  {
    desc: "Variable usage with keywords as identifiers",
    code: 'function = "test"\nfunction',
    expected: "test"
  }
]

test_cases.each_with_index do |test, i|
  puts "\n#{i+1}. #{test[:desc]}"
  puts "   Code: #{test[:code].inspect}"
  
  begin
    result = Patlang.evaluate(test[:code])
    if result == test[:expected]
      puts "   ✅ PASS: #{result.inspect}"
    else
      puts "   ❌ FAIL: Got #{result.inspect}, expected #{test[:expected].inspect}"
    end
  rescue => e
    puts "   💥 ERROR: #{e.message}"
  end
end