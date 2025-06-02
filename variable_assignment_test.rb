require_relative 'src/patlang'

puts '🔍 TESTING VARIABLE ASSIGNMENT DIRECTLY'
puts '=' * 50

test_cases = [
  'a = 5',
  'x = 10', 
  'message = "hello"',
  'result = 42'
]

test_cases.each do |code|
  puts "\nTesting: #{code}"
  begin
    result = Patlang.evaluate(code)
    puts "✅ SUCCESS: #{result}"
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts "Backtrace: #{e.backtrace.first(3).join('\n')}"
  end
end

puts "\n" + "=" * 50
puts "Testing variable usage after assignment:"

combined_test = '
a = 5
b = 10
a + b
'

puts "\nTesting combined assignment and usage:"
puts combined_test

begin
  result = Patlang.evaluate(combined_test)
  puts "✅ SUCCESS: #{result}"
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join('\n')}"
end