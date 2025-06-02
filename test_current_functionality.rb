require_relative 'src/patlang'

puts '🔍 TESTING CURRENT FUNCTIONALITY STATUS'
puts '=' * 50

test_cases = [
  {
    name: 'Simple Assignment',
    code: 'a = 5',
    expected: 'Should work for variable assignment'
  },
  {
    name: 'Function Definition',
    code: 'make a function called greet { return "Hello" }',
    expected: 'Should work for function definition'
  },
  {
    name: 'Function Call',
    code: 'make a function called greet { return "Hello" }
call greet',
    expected: 'Should work for function definition + call'
  },
  {
    name: 'Arithmetic',
    code: '5 + 3',
    expected: 'Should work for simple arithmetic'
  },
  {
    name: 'String',
    code: '"Hello World"',
    expected: 'Should work for string literals'
  }
]

test_cases.each do |test_case|
  puts "\n#{test_case[:name]}:"
  puts "Code: #{test_case[:code]}"
  puts "Expected: #{test_case[:expected]}"
  
  begin
    result = Patlang.evaluate(test_case[:code])
    puts "✅ SUCCESS: #{result.inspect}"
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first}"
  end
end

puts "\n🎯 SUMMARY: Testing what currently works vs what needs fixing"