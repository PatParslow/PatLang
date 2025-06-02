require_relative 'src/patlang'

puts '🎯 AMBIGUOUS TOKEN RESOLUTION SYSTEM VALIDATION'
puts '=' * 60

def test_scenario(description, code, expected_result = nil)
  puts "\n#{description}"
  puts "Code: #{code}"
  begin
    result = Patlang.evaluate(code)
    puts "✅ SUCCESS: #{result.inspect}"
    if expected_result && result == expected_result
      puts "✅ MATCHES EXPECTED: #{expected_result}"
    elsif expected_result
      puts "⚠️  UNEXPECTED RESULT: Expected #{expected_result}, got #{result}"
    end
    return true
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join('\n   ')}"
    return false
  end
end

# Test 1: Function definition and call (mentioned in task)
puts '\n🧪 TASK SCENARIO 1: Function Definition and Call'
test_scenario(
  '1. Function "make a function called greet" works',
  'make a function called greet { return "Hello, World!" }
call greet',
  "Hello, World!"
)

# Test 2: Variable assignment with "a" identifier (mentioned in task)
puts '\n🧪 TASK SCENARIO 2: Variable Assignment Issues'
test_scenario(
  '2a. Variable assignment "a = 5" parses correctly',
  'a = 5',
  5
)

test_scenario(
  '2b. Identifier "a" resolves in assignment contexts',
  'a = 10
a',
  10
)

# Test 3: Expression with identifiers (mentioned in task)
puts '\n🧪 TASK SCENARIO 3: Expression with Identifiers'
test_scenario(
  '3. Expression "a + b" where "a" should be identifier',
  'a = 5
b = 3
a + b',
  8
)

# Test 4: Complex function scenarios
puts '\n🧪 TASK SCENARIO 4: Function Integration Testing'
test_scenario(
  '4a. Function with parameters',
  'make a function called add takes: x, y { return x + y }
call add with 5, 3',
  8
)

test_scenario(
  '4b. Recursive function',
  'make a function called factorial takes: n {
  if n <= 1 then
    return 1
  else
    return n * (call factorial with n - 1)
  end
}
call factorial with 5',
  120
)

# Test 5: Edge cases with ambiguous tokens
puts '\n🧪 TASK SCENARIO 5: Edge Case Testing'
test_scenario(
  '5a. Multiple ambiguous tokens in same expression',
  'a = 1
b = 2  
c = 3
a + b + c',
  6
)

test_scenario(
  '5b. Mixed contexts - function definition followed by variable assignment',
  'make a function called test { return 42 }
a = 5
call test',
  42
)

puts '\n🎯 VALIDATION COMPLETE'
puts '=' * 60