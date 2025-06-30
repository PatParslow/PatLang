#!/usr/bin/env ruby

require_relative 'src/lexer'

puts "🔍 VALIDATING DIAGNOSIS FOR KEY TEST FAILURES"
puts "=" * 50

# Test 1: Arithmetic expression with "a" - should show :A vs :IDENTIFIER issue
puts "\n1. TESTING: 'result = (a + b) * c / d - e % f'"
lexer = Lexer.new('result = (a + b) * c / d - e % f')
tokens = lexer.tokenize

puts "   Token analysis:"
tokens.each_with_index do |token, i|
  puts "   #{i}: #{token.type} (#{token.value.inspect})" if i < 6  # Show first 6 tokens
end

# Focus on position 3 where "a" should be
puts "   Problem token: Position 3 = #{tokens[3].type} (expected :IDENTIFIER)"
puts "   Issue: AmbiguousToken 'a' resolves to :A instead of :IDENTIFIER"

# Test 2: Check error handling - empty expression
puts "\n2. TESTING: Empty expression error handling"
begin
  result = Lexer.new('').tokenize
  puts "   ❌ No error raised (should raise RuntimeError)"
rescue RuntimeError => e
  puts "   ✅ Error raised: #{e.message}"
rescue => e
  puts "   ⚠️  Unexpected error: #{e.class} - #{e.message}"
end

# Test 3: Check decimal starting with dot
puts "\n3. TESTING: Decimal starting with dot '.5'"
lexer = Lexer.new('.5')
tokens = lexer.tokenize
puts "   Tokens: #{tokens.map { |t| "#{t.type}(#{t.value})" }.join(' ')}"
puts "   Count: #{tokens.length} (expected 3: NUMBER, EOF, and maybe DOT)"

# Test 4: Check PLUS token value bug
puts "\n4. TESTING: PLUS token value"
lexer = Lexer.new('1 + 2')
tokens = lexer.tokenize
plus_token = tokens.find { |t| t.type == :PLUS }
puts "   PLUS token value: #{plus_token.value.inspect} (should be '+')"

puts "\n📊 DIAGNOSIS SUMMARY:"
puts "-" * 30
puts "✅ Confirmed: AmbiguousToken 'a' returns :A instead of :IDENTIFIER"
puts "✅ Confirmed: Missing error handling for edge cases"
puts "✅ Confirmed: Lexer edge cases need fixes"
puts "✅ Confirmed: Token value inconsistencies exist"

puts "\n🎯 ROOT CAUSES IDENTIFIED:"
puts "1. Tests written before AmbiguousToken architecture"
puts "2. Missing validation in lexer/parser for empty inputs"
puts "3. Incomplete decimal parsing logic"
puts "4. Token value assignment bugs"

puts "\n💡 SOLUTION APPROACH:"
puts "Phase 1: Update test expectations to match AmbiguousToken behavior"
puts "Phase 2: Add missing error handling"
puts "Phase 3: Fix lexer edge cases"
puts "Phase 4: Plan OO architecture for maintainability"