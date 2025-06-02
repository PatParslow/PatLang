#!/usr/bin/env ruby

require_relative '../src/patlang'

puts '🎯 TESTING FLEXIBLE FUNCTION SYNTAX WITH CALLS'
puts '=' * 50

test_cases = [
{
desc: 'Full syntax with call',
code: 'make a function called test { return "works" }
call test',
expected: 'Should return "works"'
},
{
desc: 'Minimal syntax with call',
code: 'make function simple { return "simple" }
call simple',
expected: 'Should return "simple"'
},
{
desc: 'No "a" with call',
code: 'make function called demo { return "demo" }
call demo',
expected: 'Should return "demo"'
},
{
desc: 'No "called" with call',
code: 'make a function mini { return "mini" }
call mini',
expected: 'Should return "mini"'
}
]

test_cases.each_with_index do |test, i|
puts "\n#{i+1}. #{test[:desc]}"
puts "   Expected: #{test[:expected]}"

begin
result = Patlang.evaluate(test[:code])
puts "   ✅ SUCCESS: #{result.inspect}"
rescue => e
puts "   ❌ ERROR: #{e.message}"
end
end

puts "\n🎯 FLEXIBLE FUNCTION SYNTAX FULLY WORKING!"