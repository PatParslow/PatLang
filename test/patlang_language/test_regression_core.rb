#!/usr/bin/env ruby

require_relative '../../ruby-host/bootstrap/patlang'

puts '🔍 CORE REGRESSION TEST FOR FLEXIBLE FUNCTION SYNTAX'
puts '=' * 60

# Test core functionality that should still work
core_tests = [
  {
    desc: 'Basic arithmetic',
    code: '5 + 3',
    expected: 8.0
  },
  {
    desc: 'String literals',
    code: '"Hello World"',
    expected: "Hello World"
  },
  {
    desc: 'Variable assignment',
    code: 'x = 5',
    expected: 5.0
  },
  {
    desc: 'Control flow',
    code: 'if true then "yes" else "no" end',
    expected: "yes"
  },
  {
    desc: 'Original function syntax (should still work)',
    code: 'make a function called test { return "works" }
call test',
    expected: "works"
  },
  {
    desc: 'New flexible syntax 1',
    code: 'make function test2 { return "flex1" }
call test2',
    expected: "flex1"
  },
  {
    desc: 'New flexible syntax 2',
    code: 'make a function test3 { return "flex2" }
call test3',
    expected: "flex2"
  },
  {
    desc: 'New flexible syntax 3',
    code: 'make function called test4 { return "flex3" }
call test4',
    expected: "flex3"
  }
]

puts "\n🧪 RUNNING CORE REGRESSION TESTS:"
puts "=" * 40

passed = 0
failed = 0

core_tests.each_with_index do |test, i|
  puts "\n#{i+1}. #{test[:desc]}"
  puts "   Code: #{test[:code].inspect}"
  puts "   Expected: #{test[:expected].inspect}"
  
  begin
    result = Patlang.evaluate(test[:code])
    if result == test[:expected]
      puts "   ✅ PASS: #{result.inspect}"
      passed += 1
    else
      puts "   ❌ FAIL: Got #{result.inspect}, expected #{test[:expected].inspect}"
      failed += 1
    end
  rescue => e
    puts "   💥 ERROR: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(2).join('\n   ')}"
    failed += 1
  end
end

puts "\n" + "=" * 60
puts "🎯 REGRESSION TEST SUMMARY:"
puts "✅ Passed: #{passed}"
puts "❌ Failed: #{failed}"
puts "📊 Success Rate: #{(passed.to_f / (passed + failed) * 100).round(1)}%"

if failed == 0
  puts "\n🎉 ALL CORE FUNCTIONALITY WORKING!"
  puts "✅ Flexible function syntax implementation is solid"
else
  puts "\n⚠️  REGRESSIONS DETECTED!"
  puts "❌ Need to fix core functionality before proceeding"
end
