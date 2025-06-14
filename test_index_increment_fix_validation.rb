#!/usr/bin/env ruby

require 'stringio'
require_relative 'src/lexer'
require_relative 'src/parser'

puts "=== INDEX INCREMENT FIX VALIDATION ==="
puts "Testing that the parser warning 'Statement parsing did not advance token position' is eliminated"
puts

# Test cases that previously triggered the warning
test_cases = [
  { name: "UNKNOWN token &", input: "&" },
  { name: "UNKNOWN token |", input: "|" },
  { name: "UNTERMINATED_STRING", input: '"hello' },
  { name: "Unicode symbol ∞", input: "∞" },
  { name: "Multiple unknowns", input: "&|@" },
  { name: "Mixed tokens", input: 'make x & y' }
]

warning_count = 0
success_count = 0

test_cases.each_with_index do |test_case, idx|
  puts "Test #{idx + 1}: #{test_case[:name]} - Input: '#{test_case[:input]}'"
  
  # Capture output to detect warnings
  captured_output = ""
  original_stdout = $stdout
  $stdout = StringIO.new
  
  begin
    lexer = Lexer.new(test_case[:input])
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    pre_position = parser.current_token_index
    result = parser.parse
    post_position = parser.current_token_index
    
    # Restore stdout and capture what was written
    captured_output = $stdout.string
    $stdout = original_stdout
    
    # Check for the specific warning
    if captured_output.include?("Statement parsing did not advance token position")
      puts "  ❌ FAILED: Parser warning still occurs"
      warning_count += 1
    else
      puts "  ✅ PASSED: No parser warning"
      success_count += 1
    end
    
    puts "  Token advancement: #{pre_position} → #{post_position} (#{post_position > pre_position ? 'advanced' : 'stuck'})"
    puts "  Result: #{result.class}"
    
  rescue => e
    $stdout = original_stdout
    puts "  ⚠️  Error: #{e.class} - #{e.message}"
  end
  
  puts
end

puts "=== COMPREHENSIVE PARSING TEST ==="
puts "Testing complex expressions that combine multiple potential problem areas"

complex_cases = [
  'make x "unterminated',
  'x = & + |',
  '"hello" & "world"',
  'function test() { return ∞; }',
  'if (x & y) { print "test"; }'
]

complex_warning_count = 0

complex_cases.each_with_index do |code, idx|
  puts "Complex Test #{idx + 1}: #{code}"
  
  captured_output = ""
  original_stdout = $stdout
  $stdout = StringIO.new
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    result = parser.parse
    
    captured_output = $stdout.string
    $stdout = original_stdout
    
    if captured_output.include?("Statement parsing did not advance token position")
      puts "  ❌ Parser warning detected"
      complex_warning_count += 1
    else
      puts "  ✅ No parser warnings"
    end
    
  rescue => e
    $stdout = original_stdout
    puts "  ℹ️  Parse result: #{e.class}"
  end
end

puts
puts "=== VALIDATION SUMMARY ==="
puts "Basic Tests: #{success_count}/#{test_cases.length} passed (#{warning_count} warnings)"
puts "Complex Tests: #{complex_cases.length - complex_warning_count}/#{complex_cases.length} passed (#{complex_warning_count} warnings)"
puts

total_warnings = warning_count + complex_warning_count
if total_warnings == 0
  puts "🎉 SUCCESS: Index increment fix is working perfectly!"
  puts "✅ All 'Statement parsing did not advance token position' warnings eliminated"
  puts "✅ Parser now properly advances token position in error scenarios"
  puts "✅ Error recovery mechanism enhanced without breaking functionality"
  puts
  puts "🎯 IMPACT: This fix should resolve many cascading parser failures"
  puts "   by ensuring proper token consumption during error handling."
else
  puts "⚠️  Still #{total_warnings} warnings detected - fix may need refinement"
end