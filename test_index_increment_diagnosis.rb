#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

puts "=== INDEX INCREMENT DIAGNOSIS TEST ==="
puts "Testing specific cases that trigger 'Statement parsing did not advance token position' warning"
puts

# Test cases that likely trigger index increment issues
test_cases = [
  { name: "Unrecognized token &", input: "&" },
  { name: "Unrecognized token |", input: "|" },
  { name: "Invalid string parsing", input: '"unterminated' },
  { name: "Unknown symbol ∞", input: "∞" },
  { name: "Random special char %", input: "%" }
]

test_cases.each do |test_case|
  puts "Testing: #{test_case[:name]} - Input: '#{test_case[:input]}'"
  
  begin
    lexer = Lexer.new(test_case[:input])
    tokens = lexer.tokenize
    puts "  Tokens generated:"
    tokens.each_with_index do |token, idx|
      puts "    [#{idx}] Type: #{token.type}, Value: #{token.value.inspect}"
    end
    
    parser = Parser.new(tokens)
    puts "  Parser initial position: #{parser.current_token_index}"
    
    # This should trigger the warning if the index doesn't advance
    result = parser.parse
    
    puts "  ✓ Parse completed without infinite loop"
    puts "  Final parser position: #{parser.current_token_index}"
    puts "  Result: #{result.class}"
    
  rescue => e
    puts "  ❌ Error: #{e.class} - #{e.message}"
  end
  
  puts
end

puts "=== FOCUSED TEST: Index Advancement in Expression Parser ==="
puts "Testing expression parser behavior with unrecognized tokens"

# Test the specific scenario where expression parsing fails
begin
  lexer = Lexer.new("&")  # This creates UNKNOWN tokens
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  
  puts "Token stream: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
  
  # Test direct expression parsing
  pre_position = parser.current_token_index
  puts "Pre-expression position: #{pre_position}"
  
  result = parser.expression
  post_position = parser.current_token_index
  
  puts "Post-expression position: #{post_position}"
  puts "Position advanced: #{post_position > pre_position}"
  puts "Expression result: #{result.class}"
  
  if post_position == pre_position
    puts "🚨 CONFIRMED: Expression parsing did NOT advance token position!"
    puts "    This explains the '[Parser WARNING] Statement parsing did not advance token position' message"
  else
    puts "✓ Expression parsing correctly advanced token position"
  end
  
rescue => e
  puts "Expression parsing error: #{e.class} - #{e.message}"
end

puts
puts "=== DIAGNOSIS SUMMARY ==="
puts "If 'Position advanced: false' appears above, this confirms the bug:"
puts "- Expression parser creates ErrorNode without advancing token index"
puts "- Statement parser detects no advancement and forces advance"
puts "- This causes the warning and potential parsing inconsistencies"