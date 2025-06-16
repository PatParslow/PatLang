#!/usr/bin/env ruby

# Test to verify parser debug messages are silenced
require 'stringio'
require_relative 'src/patlang'

puts "Testing parser with silenced debug messages..."
puts "=" * 50

# Test cases that would previously generate noisy output
test_cases = [
  "x = 5",           # Simple assignment
  "invalid syntax @", # Should trigger error collection without spam
  "y = x + z",       # Valid expression
  "func(missing_arg" # Should trigger recovery without spam
]

test_cases.each_with_index do |code, i|
  puts "\nTest #{i + 1}: #{code}"
  puts "-" * 30
  
  # Capture stdout to verify no debug spam
  original_stdout = $stdout
  captured_output = StringIO.new
  $stdout = captured_output
  
  begin
    result = Patlang.evaluate_string(code)
    puts "Result: #{result}"
  rescue => e
    puts "Error: #{e.message}"
  ensure
    $stdout = original_stdout
    captured = captured_output.string
    
    # Check for silenced messages
    if captured.include?("[Parser ERROR COLLECTION]") || 
       captured.include?("[Parser RECOVERY]") || 
       captured.include?("[Parser WARNING]")
      puts "❌ FAILED: Debug messages still present in output"
      puts "Captured: #{captured}"
    else
      puts "✅ PASSED: No debug spam detected"
    end
  end
end

puts "\n" + "=" * 50
puts "Parser silence test completed!"