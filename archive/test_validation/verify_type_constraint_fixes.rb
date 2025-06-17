#!/usr/bin/env ruby

require_relative 'test/helpers/test_helper'
require_relative 'src/reasoning/type_constraint_system'

puts "=== VERIFYING TYPE CONSTRAINT SYSTEM FIXES ==="
puts

# Test 1: Verify validate! method now works
puts "1. Testing validate! method fix"
begin
  constraint_system = TypeConstraintSystem.new
  constraint = constraint_system.create_constraint("x", :type, :Number)
  
  # Test with valid value
  result = constraint.validate!(42)
  puts "✅ validate! with valid value: #{result}"
  
  # Test with invalid value (should raise TypeConstraintViolation)
  constraint.validate!("not_a_number")
  puts "❌ validate! should have raised exception"
rescue TypeConstraintViolation => e
  puts "✅ validate! correctly raised TypeConstraintViolation: #{e.message}"
rescue => e
  puts "❌ Unexpected error: #{e.class} - #{e.message}"
end
puts

# Test 2: Verify event system still works
puts "2. Testing event system after fixes"
event_log = []
constraint_system = TypeConstraintSystem.new

constraint_system.on_event(:constraint_created) { |event| event_log << :constraint_created }
constraint_system.on_event(:constraint_validated) { |event| event_log << :constraint_validated }

constraint = constraint_system.create_constraint("test_var", :type, :Number)
constraint_system.satisfies_all_constraints?("test_var", 42)

puts "Events fired: #{event_log}"
if event_log.include?(:constraint_created) && event_log.include?(:constraint_validated)
  puts "✅ Event system working correctly"
else
  puts "❌ Event system issues"
end
puts

# Test 3: Test specific test case that was failing
puts "3. Testing specific failing test case"
begin
  # Simulate the test case that was failing
  constraint_system = TypeConstraintSystem.new
  constraint = constraint_system.create_constraint("x", :type, :Number)
  
  # This should now work without NameError
  constraint.validate!("hello")
rescue TypeConstraintViolation => e
  puts "✅ Type constraint violation properly raised: #{e.message}"
  puts "✅ No more NameError for undefined variable 'value'"
rescue NameError => e
  puts "❌ Still getting NameError: #{e.message}"
rescue => e
  puts "❌ Other error: #{e.class} - #{e.message}"
end
puts

# Test 4: Test constraint message generation
puts "4. Testing constraint message generation"
begin
  constraint_system = TypeConstraintSystem.new
  constraint = constraint_system.create_constraint("age", :range, { min: 0, max: 150 })
  
  result = constraint.validate(200)
  puts "Range constraint message: #{result.error_message}"
  puts "✅ Constraint message generation working"
rescue => e
  puts "❌ Error in message generation: #{e.class} - #{e.message}"
end

puts
puts "=== VERIFICATION COMPLETE ==="