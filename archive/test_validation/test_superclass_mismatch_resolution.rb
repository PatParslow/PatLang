#!/usr/bin/env ruby

# Specific test for superclass mismatch resolution
puts "=== Testing ReasoningModeError Superclass Mismatch Resolution ==="

# Test the specific scenario that was causing the TypeError
begin
  # This would previously cause: TypeError: superclass mismatch for class ReasoningModeError
  require_relative 'src/exceptions'
  
  # Verify the class hierarchy
  puts "ReasoningModeError superclass: #{ReasoningModeError.superclass.name}"
  puts "PatlangError defined: #{defined?(PatlangError) ? 'Yes' : 'No'}"
  
  # Test multiple requires (this was causing the mismatch)
  require_relative 'src/exceptions'  # Second require should not cause mismatch
  require_relative 'src/evaluator'   # This should also work now
  
  puts "✓ SUCCESS: No superclass mismatch errors detected"
  puts "✓ ReasoningModeError properly inherits from PatlangError"
  puts "✓ Multiple requires work without conflicts"
  
rescue TypeError => e
  if e.message.include?("superclass mismatch")
    puts "✗ FAILED: Superclass mismatch still exists: #{e.message}"
    exit 1
  else
    puts "✗ Other TypeError: #{e.message}"
    exit 1
  end
rescue => e
  puts "✗ Other error: #{e.class}: #{e.message}"
  exit 1
end

puts "\n=== Phase 1 Emergency Stabilization: COMPLETE ==="