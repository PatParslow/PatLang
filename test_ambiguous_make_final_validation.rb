require_relative 'src/patlang'

puts '🎯 COMPREHENSIVE AMBIGUOUS MAKE TOKEN VALIDATION'
puts '=' * 65

test_cases = [
  {
    desc: 'MAKE as variable assignment',
    code: 'make = 42',
    expected: 42.0,
    test_type: :assignment
  },
  {
    desc: 'MAKE function definition',
    code: 'make a function called test { return "works" }',
    expected: 'test',
    test_type: :function_def
  },
  {
    desc: 'MAKE assignment with evaluation',
    code: 'make = 10 + 5',
    expected: 15.0,
    test_type: :assignment
  },
  {
    desc: 'MAKE function with parameters',
    code: 'make a function called add takes: x, y { return x + y }',
    expected: 'add',
    test_type: :function_def
  },
  {
    desc: 'MAKE assignment with string',
    code: 'make = "hello world"',
    expected: 'hello world',
    test_type: :assignment
  },
  {
    desc: 'MAKE assignment then function call',
    code: "make = 5\nmake a function called get_make { return make }\ncall get_make",
    expected: 5.0,
    test_type: :complex
  },
  {
    desc: 'Function then MAKE assignment',
    code: "make a function called test { return \"func\" }\nmake = \"var\"\nmake",
    expected: 'var',
    test_type: :complex
  }
]

passed = 0
total = test_cases.length

test_cases.each_with_index do |test, i|
  puts "\n#{i+1}. #{test[:desc]}"
  puts "   Code: #{test[:code].inspect}"
  
  begin
    result = Patlang.evaluate(test[:code])
    if result == test[:expected]
      puts "   ✅ PASSED: #{result} (#{result.class})"
      passed += 1
    else
      puts "   ❌ FAILED: Expected #{test[:expected]} but got #{result}"
    end
  rescue => e
    puts "   💥 ERROR: #{e.message}"
  end
end

puts "\n" + "=" * 65
puts "🏆 FINAL RESULTS: #{passed}/#{total} tests passed"

if passed == total
  puts "✅ SUCCESS: All ambiguous MAKE token handling is working perfectly!"
  puts "✅ Parser correctly distinguishes between:"
  puts "   - make = value (assignment)"
  puts "   - make a function called name (function definition)"
  puts "✅ Both syntaxes can coexist in the same program"
else
  puts "❌ Some tests failed - further investigation needed"
end