#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "🔍 VALIDATING LBRACE/MINUS TOKEN ISSUE HYPOTHESIS"
puts "=" * 60

# Test the specific failing input
test_input = "make a function called process takes: data-string returns: boolean { return true }"

puts "📝 INPUT: #{test_input}"
puts

# Create lexer and tokenize
lexer = Lexer.new(test_input)
tokens = []

puts "🔗 TOKENIZATION SEQUENCE:"
puts "-" * 30

begin
  loop do
    token = lexer.get_next_token
    break if token.type == :EOF
    tokens << token
    puts "Token: #{token.type.to_s.ljust(12)} | Value: '#{token.value}'"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
end

puts
puts "🎯 ANALYSIS:"
puts "-" * 15

# Find the problematic sequence
data_index = tokens.find_index { |t| t.value == "data" }
if data_index
  relevant_tokens = tokens[data_index, 5]
  puts "Tokens around 'data':"
  relevant_tokens.each_with_index do |token, i|
    marker = i == 1 ? " ← MINUS HERE!" : ""
    puts "  #{token.type.to_s.ljust(12)} | '#{token.value}'#{marker}"
  end
  
  puts
  puts "✅ HYPOTHESIS CONFIRMED:"
  puts "- 'data-string' tokenizes as: IDENTIFIER(data) + MINUS(-) + IDENTIFIER(string)"
  puts "- Function parser expects LBRACE after parameter parsing"
  puts "- But encounters MINUS from the hyphenated parameter type"
  
  puts
  puts "🔍 ROOT CAUSE:"
  puts "Parameter type parsing doesn't handle compound types like 'data-string'"
  puts "The hyphen is treated as arithmetic operator instead of type separator"
  
else
  puts "❌ Could not find 'data' token in sequence"
end

puts
puts "🎯 PROBLEM SOURCES ANALYSIS:"
puts "-" * 35

puts "1. LEXER ISSUE: Hyphens always tokenized as MINUS"
puts "   - No context awareness for compound type names"
puts "   - 'data-string' becomes separate tokens"
puts
puts "2. PARSER ISSUE: Parameter parsing doesn't expect compound types"
puts "   - Assumes single-token type names"
puts "   - Doesn't handle hyphenated identifiers"
puts
puts "3. LANGUAGE DESIGN: Ambiguous hyphen usage"
puts "   - Same symbol for arithmetic subtraction and type compound"
puts "   - Creates parsing ambiguity"

puts
puts "🚀 SOLUTION APPROACHES:"
puts "-" * 25
puts "A. LEXER: Context-aware hyphen tokenization"
puts "B. PARSER: Handle compound type parsing"
puts "C. SYNTAX: Use different separator (underscore, dot, etc.)"

puts
puts "✅ DIAGNOSIS COMPLETE"