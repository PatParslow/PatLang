#!/usr/bin/env ruby

# Test script to check syntax errors in test_helper.rb
puts "Testing syntax of test/helpers/test_helper.rb..."

begin
  # Try to load the file to check for syntax errors
  load 'test/helpers/test_helper.rb'
  puts "✅ File loaded successfully - no syntax errors found"
rescue SyntaxError => e
  puts "❌ Syntax Error detected:"
  puts "  Error: #{e.message}"
  puts "  Location: #{e.backtrace&.first}"
rescue LoadError => e
  puts "⚠️ Load Error (dependencies missing but syntax OK):"
  puts "  Error: #{e.message}"
rescue => e
  puts "❌ Other error:"
  puts "  Error: #{e.class}: #{e.message}"
end

puts "\nDone."