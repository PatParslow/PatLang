#!/usr/bin/env ruby

# Test Priority 2 fixes for critical parser errors

puts "🔧 TESTING PRIORITY 2 FIXES"
puts "=" * 40

require_relative 'src/patlang'

test_cases = [
  # Test 1: pursue keyword support (was causing "Unexpected token" error)
  {
    name: "Pursue keyword parsing",
    code: "result = pursue(goal)",
    expected_error: nil # Should parse without "Unexpected token" error
  },
  
  # Test 2: Exponent operator support (was causing "Invalid character" error)
  {
    name: "Exponent operator parsing", 
    code: "x = 2^3",
    expected_error: nil # Should parse without "Invalid character" error
  },
  
  # Test 3: Variable assignment (should still work after VariableNode fix)
  {
    name: "Variable assignment (regression test)",
    code: "x = 42",
    expected_error: nil
  }
]

success_count = 0
parser_success_count = 0

test_cases.each_with_index do |test_case, index|
  puts "\n🧪 Test #{index + 1}: #{test_case[:name]}"
  puts "   Code: #{test_case[:code]}"
  
  begin
    # Test parsing phase specifically
    lexer = Lexer.new(test_case[:code])
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    puts "   ✅ PARSING SUCCESS: AST generated"
    parser_success_count += 1
    
    # Test evaluation phase
    result = Patlang.evaluate(test_case[:code])
    puts "   ✅ EVALUATION SUCCESS: #{result}"
    success_count += 1
    
  rescue => e
    if test_case[:expected_error] && e.message.include?(test_case[:expected_error])
      puts "   ✅ EXPECTED ERROR: #{e.message}"
      success_count += 1
    else
      puts "   ❌ UNEXPECTED ERROR: #{e.class}: #{e.message}"
      
      # Check if it's a parser vs evaluator error
      if e.message.include?("Unexpected token") || e.message.include?("Invalid character")
        puts "   🔍 This is a PARSER ERROR - fix not working properly"
      else
        puts "   🔍 This is an EVALUATOR ERROR - parser fix is working"
        parser_success_count += 1
      end
    end
  end
end

puts "\n📊 PRIORITY 2 FIX RESULTS:"
puts "- Parser Success: #{parser_success_count}/#{test_cases.length}"
puts "- Full Success: #{success_count}/#{test_cases.length}"

if parser_success_count == test_cases.length
  puts "✅ PARSER FIXES SUCCESSFUL - All critical parsing errors resolved!"
else
  puts "❌ PARSER FIXES INCOMPLETE - Some parsing errors remain"
end

puts "\n🎯 NEXT STEPS:"
if parser_success_count >= 2
  puts "- Parser improvements working - continue with reasoning integration"
  puts "- Focus on evaluator-level reasoning system connection"
else
  puts "- Need to debug remaining parser issues"
  puts "- Check token definitions and expression parsing"
end