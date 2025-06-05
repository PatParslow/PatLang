#!/usr/bin/env ruby

# Test file for IS keyword implementation
# Tests both traditional '=' and revolutionary 'is' assignment syntax
# Plus elegant MAKE patterns as suggested

require_relative '../../src/lexer'
require_relative '../../src/parser'
require_relative '../../src/evaluator'

def test_assignment_syntax
  puts "🚀 TESTING PATLANG'S REVOLUTIONARY 'IS' KEYWORD IMPLEMENTATION"
  puts "=" * 70

  test_cases = [
    # Traditional assignment syntax (backward compatibility)
    {
      name: "Traditional assignment with =",
      code: "x = 42",
      expected: 42
    },
    {
      name: "Traditional MAKE with =",
      code: "make y = 17",
      expected: 17
    },
    
    # Revolutionary IS keyword syntax
    {
      name: "Revolutionary assignment with 'is'",
      code: "x is 42",
      expected: 42
    },
    {
      name: "Complex expression with 'is'",
      code: "result is 10 + 5 * 2",
      expected: 20
    },
    {
      name: "Variable reference with 'is'",
      code: "a is 5\nb is a + 3",
      expected: 8
    },
    
    # NEW: Elegant MAKE syntax (preferred patterns)
    {
      name: "✨ ELEGANT: make without assignment operator",
      code: "make z 25",
      expected: 25
    },
    {
      name: "✨ ELEGANT: make with complex expression",
      code: "make total 10 + 15",
      expected: 25
    }
  ]

  passed_tests = 0
  total_tests = test_cases.length

  test_cases.each_with_index do |test_case, index|
    puts "\n#{index + 1}. #{test_case[:name]}"
    puts "   Code: #{test_case[:code]}"
    
    begin
      # Tokenize
      lexer = Lexer.new(test_case[:code])
      tokens = lexer.tokenize
      
      # Parse
      parser = Parser.new(tokens)
      ast = parser.parse
      
      # Evaluate
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      
      if result == test_case[:expected]
        puts "   ✅ PASSED: Got #{result} (expected #{test_case[:expected]})"
        passed_tests += 1
      else
        puts "   ❌ FAILED: Got #{result}, expected #{test_case[:expected]}"
      end
      
    rescue => e
      puts "   ❌ ERROR: #{e.message}"
    end
  end

  puts "\n" + "=" * 70
  puts "📊 TEST SUMMARY:"
  puts "   Passed: #{passed_tests}/#{total_tests}"
  puts "   Success Rate: #{(passed_tests.to_f / total_tests * 100).round(1)}%"
  
  if passed_tests == total_tests
    puts "   🎉 ALL TESTS PASSED! IS keyword implementation successful!"
  else
    puts "   ⚠️  Some tests failed. Review implementation."
  end

  puts "\n🎯 REVOLUTIONARY SYNTAX EXAMPLES:"
  puts "   Traditional:     x = 42"
  puts "   Natural:         x is 42"
  puts "   Traditional:     make result = 10 + 5"
  puts "   ✨ ELEGANT:      make result 10 + 5"
  puts "   ✨ PREFERRED:    result is 10 + 5"
  puts "\n✨ Patlang brings natural, elegant assignment syntax to programming!"
  puts "   💡 TIP: Use 'is' for natural assignments, 'make variable value' for declarations"
end

# Run the tests
test_assignment_syntax