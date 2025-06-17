#!/usr/bin/env ruby
# Test script to verify UnificationEngine constructor fix

require_relative 'src/reasoning/unification_engine'

puts "Testing UnificationEngine constructor fix..."
puts "=" * 50

# Test 1: Backward compatibility - no arguments
puts "\nTest 1: Creating UnificationEngine with no arguments (backward compatibility)"
begin
  engine1 = UnificationEngine.new
  puts "✓ SUCCESS: UnificationEngine.new() works"
  puts "  - @evaluator: #{engine1.instance_variable_get(:@evaluator).inspect}"
  puts "  - @event_handlers: #{engine1.instance_variable_get(:@event_handlers).inspect}"
  puts "  - @unification_count: #{engine1.instance_variable_get(:@unification_count)}"
rescue => e
  puts "✗ FAILED: #{e.class}: #{e.message}"
  exit 1
end

# Test 2: New functionality - with evaluator argument
puts "\nTest 2: Creating UnificationEngine with evaluator argument"
begin
  mock_evaluator = "mock_evaluator_object"
  engine2 = UnificationEngine.new(mock_evaluator)
  puts "✓ SUCCESS: UnificationEngine.new(evaluator) works"
  puts "  - @evaluator: #{engine2.instance_variable_get(:@evaluator).inspect}"
  puts "  - @event_handlers: #{engine2.instance_variable_get(:@event_handlers).inspect}"
  puts "  - @unification_count: #{engine2.instance_variable_get(:@unification_count)}"
rescue => e
  puts "✗ FAILED: #{e.class}: #{e.message}"
  exit 1
end

# Test 3: Verify evaluator is stored correctly
puts "\nTest 3: Verifying evaluator storage"
if engine2.instance_variable_get(:@evaluator) == mock_evaluator
  puts "✓ SUCCESS: Evaluator is stored correctly"
else
  puts "✗ FAILED: Evaluator not stored correctly"
  exit 1
end

# Test 4: Verify nil evaluator for backward compatibility
puts "\nTest 4: Verifying nil evaluator for backward compatibility"
if engine1.instance_variable_get(:@evaluator).nil?
  puts "✓ SUCCESS: No-argument constructor sets @evaluator to nil"
else
  puts "✗ FAILED: @evaluator should be nil when no argument provided"
  exit 1
end

puts "\n" + "=" * 50
puts "🎉 ALL TESTS PASSED! UnificationEngine constructor fix is working correctly."
puts "\nSummary:"
puts "- ✓ Backward compatibility maintained (no arguments)"
puts "- ✓ New functionality works (accepts evaluator argument)"
puts "- ✓ Evaluator is stored properly when provided"
puts "- ✓ @evaluator is nil when no argument provided"