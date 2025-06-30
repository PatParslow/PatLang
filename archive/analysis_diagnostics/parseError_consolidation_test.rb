#!/usr/bin/env ruby

puts "=== ParseError Consolidation Test ==="
puts

# Test 1: Load exceptions.rb with unified ParseError
puts "1. Loading src/exceptions.rb (unified version):"
begin
  require_relative 'src/exceptions'
  puts "   ✓ Loaded successfully"
  puts "   ParseError superclass: #{ParseError.superclass}"
  puts "   ParseError attributes: #{ParseError.instance_methods(false) & [:line, :column, :position, :token]}"
rescue => e
  puts "   ✗ Error: #{e.class}: #{e.message}"
end
puts

# Test 2: Test ParseError functionality
puts "2. Testing ParseError functionality:"
begin
  # Test with line/column
  error1 = ParseError.new("Test error", line: 10, column: 5)
  puts "   ✓ Line/column error: #{error1}"
  
  # Test with position
  error2 = ParseError.new("Position error", position: 42)
  puts "   ✓ Position error: #{error2}"
  
  # Test with token 
  error3 = ParseError.new("Token error", token: "badtoken", line: 3, column: 2)
  puts "   ✓ Token error: #{error3}"
  
rescue => e
  puts "   ✗ Functionality error: #{e.class}: #{e.message}"
end
puts

# Test 3: Test parser.rb loads correctly
puts "3. Testing parser.rb with unified exceptions:"
begin
  require_relative 'src/parser'
  puts "   ✓ Parser loaded successfully with unified ParseError"
rescue => e
  puts "   ✗ Parser error: #{e.class}: #{e.message}"
end
puts

puts "=== Consolidation Test Complete ==="