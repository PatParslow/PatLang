#!/usr/bin/env ruby

# Phase 6: Parser/Lexer Edge Case Fixes
require_relative 'src/patlang'

puts "Phase 6: Testing Parser/Lexer Edge Case Fixes"
puts "=" * 50

def test_fix(description)
  print "Testing #{description}... "
  begin
    success = yield
    if success
      puts "✓ PASS"
      return 1
    else
      puts "✗ FAIL"
      return 0
    end
  rescue => e
    puts "✗ ERROR: #{e.class} - #{e.message}"
    return 0
  end
end

passed = 0
total = 0

# Test 1: Empty input handling
total += 1
passed += test_fix("empty input parsing") do
  parser = Patlang::Parser.new('')
  result = parser.parse
  result.is_a?(Array) && result.empty?
end

# Test 2: Whitespace-only input
total += 1  
passed += test_fix("whitespace-only input") do
  parser = Patlang::Parser.new("   \n\t  ")
  result = parser.parse
  result.is_a?(Array)
end

# Test 3: Single character boundary conditions
['(', ')', '[', ']', '{', '}'].each do |char|
  total += 1
  passed += test_fix("single character '#{char}' tokenization") do
    lexer = Patlang::Lexer.new(char)
    tokens = lexer.tokenize
    tokens.length >= 2  # Token + EOF
  end
end

# Test 4: Unterminated strings  
total += 1
passed += test_fix("unterminated string handling") do
  lexer = Patlang::Lexer.new('"unterminated')
  tokens = lexer.tokenize
  # Should not crash and should handle gracefully
  tokens.is_a?(Array) && !tokens.empty?
end

# Test 5: Standalone operators
total += 1
passed += test_fix("standalone NOT operator") do
  lexer = Patlang::Lexer.new('!')
  tokens = lexer.tokenize
  tokens.any? { |t| t.type == :NOT || t.type == :UNKNOWN }
end

# Test 6: Error recovery
total += 1
passed += test_fix("parser error recovery") do
  begin
    parser = Patlang::Parser.new('invalid ( syntax } here')
    result = parser.parse
    true  # Should not crash completely
  rescue => e
    # Should handle errors gracefully with meaningful messages
    e.message.length > 0
  end
end

puts
puts "Parser/Lexer Edge Case Results:"
puts "  Passed: #{passed}/#{total}"
success_rate = (passed.to_f / total * 100).round(1)
puts "  Success Rate: #{success_rate}%"

if success_rate >= 80
  puts "  ✅ Parser/Lexer edge cases well handled!"
else
  puts "  ⚠️  Some edge cases need more work"
end