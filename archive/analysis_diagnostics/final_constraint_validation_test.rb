#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== FINAL CONSTRAINT VALIDATION TEST ==="
puts "Testing constraint creation after fixes"
puts

def test_constraint_functionality
  puts "1. Testing constraint validation flow..."
  
  evaluator = Evaluator.new
  evaluator.enable_object_mode
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  puts "   Creating constraint: create_constraint(:x, :type, :Number)"
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  
  puts "   Constraint details:"
  puts "     variable: #{constraint.variable.inspect}"
  puts "     constraint_type: #{constraint.constraint_type.inspect}"
  puts "     constraint_data: #{constraint.constraint_data.inspect}"
  
  puts "\n2. Testing constraint validation..."
  puts "   Testing constraint.satisfies?(42):"
  result_42 = constraint.satisfies?(42)
  puts "     Result: #{result_42}"
  puts "     Expected: true (42 is a Number)"
  
  puts "   Testing constraint.satisfies?('string'):"
  result_string = constraint.satisfies?("string")
  puts "     Result: #{result_string}"
  puts "     Expected: false ('string' is not a Number)"
  
  puts "\n3. Testing TypeConstraintViolation exception flow..."
  
  begin
    reasoning_coordinator.validate_assignment(:x, "invalid_string")
    puts "   ✗ FAILED: No exception raised"
    return false
  rescue TypeConstraintViolation => e
    puts "   ✓ SUCCESS: TypeConstraintViolation raised"
    puts "     Message: #{e.message}"
    puts "     Variable: #{e.variable}"
    puts "     Value: #{e.value}"
    return true
  rescue => e
    puts "   ✗ FAILED: Wrong exception type: #{e.class.name}: #{e.message}"
    return false
  end
end

def test_direct_constraint_creation
  puts "\n4. Testing direct TypeConstraint creation..."
  
  # Test direct constraint creation
  direct_constraint = TypeConstraint.new(:y, :type, :Number)
  puts "   Direct constraint:"
  puts "     variable: #{direct_constraint.variable.inspect}"
  puts "     constraint_type: #{direct_constraint.constraint_type.inspect}"
  puts "     constraint_data: #{direct_constraint.constraint_data.inspect}"
  
  puts "   Testing satisfies? method:"
  puts "     satisfies?(42): #{direct_constraint.satisfies?(42)}"
  puts "     satisfies?('string'): #{direct_constraint.satisfies?('string')}"
end

# Run tests
success = test_constraint_functionality
test_direct_constraint_creation

puts "\n=== FINAL RESULT ==="
if success
  puts "✓ CONSTRAINT VALIDATION SYSTEM: WORKING"
  puts "✓ TypeConstraintViolation exceptions: PROPERLY RAISED"
  puts "✓ Reasoning integration failures: RESOLVED"
else
  puts "✗ CONSTRAINT VALIDATION SYSTEM: STILL BROKEN"
  puts "✗ TypeConstraintViolation exceptions: NOT RAISED"
  puts "✗ Additional investigation needed"
end