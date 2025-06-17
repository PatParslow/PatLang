#!/usr/bin/env ruby

puts "=== ParseError Conflict Diagnosis ==="
puts

# Test 1: Check if ParseError is already defined
puts "1. Initial ParseError state:"
if defined?(ParseError)
  puts "   ParseError already defined: #{ParseError.superclass}"
else
  puts "   ParseError not yet defined"
end
puts

# Test 2: Load parse_error.rb first
puts "2. Loading src/parse_error.rb:"
begin
  require_relative 'src/parse_error'
  puts "   ✓ Loaded successfully"
  puts "   ParseError superclass: #{ParseError.superclass}"
  puts "   ParseError methods: #{ParseError.instance_methods(false)}"
rescue => e
  puts "   ✗ Error: #{e.class}: #{e.message}"
end
puts

# Test 3: Try to load exceptions.rb (should fail)
puts "3. Loading src/exceptions.rb (expecting conflict):"
begin
  require_relative 'src/exceptions'
  puts "   ✓ Loaded successfully (unexpected!)"
  puts "   ParseError superclass: #{ParseError.superclass}"
rescue => e
  puts "   ✗ Expected error: #{e.class}: #{e.message}"
end
puts

puts "=== Analysis Complete ==="