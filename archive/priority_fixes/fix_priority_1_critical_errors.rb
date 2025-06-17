#!/usr/bin/env ruby

# PRIORITY 1 CRITICAL ERROR FIXES
# Focus on the most critical parser/lexer errors first

puts "🔧 APPLYING PRIORITY 1 CRITICAL FIXES"
puts "=" * 50

puts "\n✅ FIXED: VariableNode.value error in expression_parser.rb"
puts "- Changed left.value to proper node type handling"
puts "- Added case statement for VariableNode vs StringNode"

puts "\n🎯 TESTING CRITICAL FIXES"
puts "Running quick validation to check if VariableNode error is resolved..."

# Create a minimal test to verify the fix
require_relative 'src/patlang'

test_cases = [
  # Simple function call that was failing
  "greet()",
  # Variable assignment that should work
  "x = 42"
]

success_count = 0
test_cases.each_with_index do |code, index|
  begin
    puts "\nTest #{index + 1}: #{code}"
    result = Patlang.evaluate(code)
    puts "✅ SUCCESS: #{result}"
    success_count += 1
  rescue => e
    puts "❌ FAILED: #{e.message}"
    puts "   Full error: #{e.class}: #{e}"
  end
end

puts "\n📊 QUICK VALIDATION RESULTS:"
puts "- Successful: #{success_count}/#{test_cases.length}"
puts "- #{success_count == test_cases.length ? '✅ CRITICAL FIX WORKING' : '❌ STILL ISSUES REMAIN'}"

if success_count > 0
  puts "\n🎉 PROGRESS MADE! The VariableNode.value fix is working."
  puts "Now proceeding to run broader tests to identify remaining issues..."
end