require_relative 'src/patlang'

puts '🔍 DEBUGGING REMAINING MAKE TOKEN ISSUES'
puts '=' * 55

# Test 1: Simple make variable lookup
puts "\n1. Testing simple make variable lookup:"
test_code = "make = 5\nmake"
puts "Code: #{test_code.inspect}"
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Result: #{result}"
rescue => e
  puts "❌ Error: #{e.message}"
end

# Test 2: Make in expression context
puts "\n2. Testing make in expression:"
test_code = "make = 10\nmake + 5"
puts "Code: #{test_code.inspect}"
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Result: #{result}"
rescue => e
  puts "❌ Error: #{e.message}"
end

# Test 3: Make in function return
puts "\n3. Testing make in function return:"
test_code = "make = 42\nmake a function called get_value { return make }"
puts "Code: #{test_code.inspect}"
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Result: #{result}"
rescue => e
  puts "❌ Error: #{e.message}"
end