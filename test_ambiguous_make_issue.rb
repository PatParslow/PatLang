require_relative 'src/patlang'

puts '🔍 TESTING CURRENT BROKEN BEHAVIOR - AMBIGUOUS MAKE TOKEN'
puts '=' * 60

# Test the broken case: make = 5
puts '1. Testing assignment that should work: make = 5'
begin
  result = Patlang.evaluate('make = 5')
  puts "✅ SUCCESS: #{result}"
rescue => e
  puts "❌ EXPECTED ERROR: #{e.message}"
end

# Test function definition that should still work
puts '\n2. Testing function definition that should work:'
begin
  result = Patlang.evaluate('make a function called greet { return "Hello" }')
  puts "✅ SUCCESS: #{result}"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

# Test simple variable assignment to confirm regular assignments work
puts '\n3. Testing regular variable assignment:'
begin
  result = Patlang.evaluate('x = 5')
  puts "✅ SUCCESS: #{result}"
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts '\n🎯 ISSUE CONFIRMED: make = 5 fails, but should work as assignment'