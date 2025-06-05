#!/usr/bin/env ruby

require_relative '../../src/patlang'

puts '🎯 TESTING FLEXIBLE FUNCTION SYNTAX'
puts '=' * 50

test_cases = [
{
desc: 'Full syntax: make a function called',
code: 'make a function called greet { return "Hello" }',
expected: 'Should work (original syntax)'
},
{
desc: 'No "a": make function called',
code: 'make function called greet { return "Hello" }',
expected: 'Should work (no "a")'
},
{
desc: 'No "called": make a function',
code: 'make a function greet { return "Hello" }',
expected: 'Should work (no "called")'
},
{
desc: 'Minimal: make function',
code: 'make function greet { return "Hello" }',
expected: 'Should work (minimal syntax)'
},
{
desc: 'Test function definition (full)',
code: 'make a function called test { return "works" }',
expected: 'Should define function successfully'
},
{
desc: 'Test function definition (minimal)',
code: 'make function simple { return "simple" }',
expected: 'Should define function successfully'
}
]

test_cases.each_with_index do |test, i|
puts "\n#{i+1}. #{test[:desc]}"
puts "   Code: #{test[:code]}"
puts "   Expected: #{test[:expected]}"

begin
result = Patlang.evaluate(test[:code])
puts "   ✅ SUCCESS: #{result.inspect}"
rescue => e
puts "   ❌ ERROR: #{e.message}"
puts "   Backtrace: #{e.backtrace.first(2).join('\n   ')}"
end
end

puts "\n🎯 TESTING COMPLETE!"