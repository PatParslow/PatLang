require_relative 'src/patlang'

puts '🎯 COMPREHENSIVE PATLANG TESTING WITH FIXES'
puts '=' * 50

# Test 1: Variable assignment
puts '\n1. Variable Assignment Test:'
test_code = 'x = 42'
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Assignment: #{result}"
rescue => e
  puts "❌ Assignment: #{e.message}"
end

# Test 2: Function definition and call
puts '\n2. Function Definition and Call Test:'
test_code = '
make a function called greet {
  return "Hello, World!"
}
call greet
'
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Function: #{result}"
rescue => e
  puts "❌ Function: #{e.message}"
end

# Test 3: Function with parameters
puts '\n3. Function with Parameters Test:'
test_code = '
make a function called add takes: x, y {
  return x + y
}
call add with 5, 3
'
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Function with params: #{result}"
rescue => e
  puts "❌ Function with params: #{e.message}"
end

# Test 4: Complex integration test
puts '\n4. Complex Integration Test:'
test_code = '
make a function called calculate takes: a, b {
  result = a * b + 10
  return result
}

x = 5
y = 3
call calculate with x, y
'
begin
  result = Patlang.evaluate(test_code)
  puts "✅ Integration: #{result}"
rescue => e
  puts "❌ Integration: #{e.message}"
end

puts '\n🎯 ALL CORE FUNCTIONALITY TESTING COMPLETE!'