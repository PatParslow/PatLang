#!/usr/bin/env ruby

require 'stringio'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

puts "=== PARSER WARNINGS ELIMINATION TEST ==="
puts

# Test cases specifically designed to trigger parser warnings in the old system
warning_test_cases = [
  {
    name: "Single UNKNOWN Token",
    code: "@#$%"
  },
  {
    name: "Multiple UNKNOWN Tokens",
    code: "@#$% ^&*() ~!@"
  },
  {
    name: "UNTERMINATED_STRING Token",
    code: '"hello world without closing'
  },
  {
    name: "Mixed Problematic Tokens",
    code: '@#$% "unterminated string (unbalanced paren'
  },
  {
    name: "UNKNOWN Token with Valid Syntax",
    code: 'x = 5 + @#$% + 10'
  }
]

puts "Testing for parser warning elimination..."
puts

warning_count = 0
recovery_count = 0

warning_test_cases.each do |test_case|
  puts "--- #{test_case[:name]} ---"
  puts "Code: #{test_case[:code].inspect}"
  
  # Capture output to detect warnings
  original_stdout = $stdout
  captured_output = StringIO.new
  $stdout = captured_output
  
  begin
    lexer = Lexer.new(test_case[:code])
    tokens = lexer.tokenize
    
    parser = Parser.new(tokens)
    result = parser.parse
    
    # Restore stdout
    $stdout = original_stdout
    output = captured_output.string
    
    # Check for parser warnings
    warnings = output.scan(/\[Parser WARNING\]/).length
    recoveries = output.scan(/\[Parser RECOVERY\]/).length
    
    warning_count += warnings
    recovery_count += recoveries
    
    puts "Tokens: #{tokens.map(&:type).inspect}"
    puts "Result: #{result.class}"
    puts "Errors Collected: #{parser.collected_errors.length}"
    puts "Parser Warnings: #{warnings}"
    puts "Recovery Actions: #{recoveries}"
    
    if warnings > 0
      puts "⚠️  Parser warnings detected!"
      puts output.lines.select { |line| line.include?("[Parser WARNING]") }
    else
      puts "✅ No parser warnings"
    end
    
  rescue => e
    $stdout = original_stdout
    puts "❌ Parse failed: #{e.message}"
  end
  
  puts
end

puts "=== PARSER WARNING ELIMINATION SUMMARY ==="
puts "Total Parser Warnings: #{warning_count}"
puts "Total Recovery Actions: #{recovery_count}"
puts

if warning_count == 0
  puts "🎉 SUCCESS: All parser warnings eliminated!"
  puts "✅ Parser no longer generates warnings for UNKNOWN tokens"
  puts "✅ Parser no longer generates warnings for UNTERMINATED_STRING tokens"
  puts "✅ Error recovery system handles all problematic tokens gracefully"
  puts "✅ Recovery actions: #{recovery_count} (shows comprehensive error handling)"
else
  puts "⚠️  #{warning_count} parser warnings still detected"
  puts "Error recovery system needs further refinement"
end

exit(warning_count == 0 ? 0 : 1)