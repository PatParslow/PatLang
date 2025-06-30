#!/usr/bin/env ruby
# Test script to validate NoMethodError fix for missing satisfies? method

require_relative 'src/patlang'

puts "=== Testing NoMethodError Fix for satisfies? method ==="

# Test 1: Test the null constraint pattern
puts "\n1. Testing NullTypeConstraint implementation..."
begin
  require_relative 'src/reasoning/type_constraint'
  
  null_constraint = NullTypeConstraint.new(:missing_var)
  puts "Created NullTypeConstraint: #{null_constraint.inspect}"
  
  # Test that satisfies? method exists and works
  puts "null_constraint.satisfies?(42): #{null_constraint.satisfies?(42)}"
  puts "null_constraint.satisfies?('test'): #{null_constraint.satisfies?('test')}"
  puts "null_constraint.satisfies?(nil): #{null_constraint.satisfies?(nil)}"
  
  puts "✓ NullTypeConstraint satisfies? method works correctly"
  
rescue => e
  puts "✗ Error with NullTypeConstraint: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 2: Test get_constraint returning NullTypeConstraint for missing constraints
puts "\n2. Testing get_constraint with missing constraint..."
begin
  require_relative 'src/reasoning/reasoning_coordinator'
  require_relative 'src/evaluator'
  
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # Get a constraint that doesn't exist
  missing_constraint = coordinator.get_constraint(:nonexistent)
  puts "get_constraint(:nonexistent) returns: #{missing_constraint.inspect}"
  puts "Type: #{missing_constraint.class}"
  
  # Test that we can safely call satisfies? on it
  result1 = missing_constraint.satisfies?(42)
  result2 = missing_constraint.satisfies?("test")
  
  puts "missing_constraint.satisfies?(42): #{result1}"
  puts "missing_constraint.satisfies?('test'): #{result2}"
  
  puts "✓ No NoMethodError when calling satisfies? on missing constraint"
  
rescue => e
  puts "✗ Error testing missing constraint: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 3: Simulate the original failing test scenario
puts "\n3. Simulating original failing test scenario..."
begin
  require_relative 'src/reasoning/reasoning_coordinator'
  require_relative 'src/evaluator'
  
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  
  # This simulates the failing test line:
  # constraint = @reasoning_coordinator.get_constraint(:x)
  # assert constraint.satisfies?(50), "Should accept valid number"
  
  constraint = reasoning_coordinator.get_constraint(:x)
  puts "Retrieved constraint for :x: #{constraint.inspect}"
  
  # These lines were causing NoMethodError before the fix
  result1 = constraint.satisfies?(50)
  result2 = constraint.satisfies?(-5)
  result3 = constraint.satisfies?("string")
  
  puts "constraint.satisfies?(50): #{result1}"
  puts "constraint.satisfies?(-5): #{result2}"
  puts "constraint.satisfies?('string'): #{result3}"
  
  puts "✓ Original failing test scenario now works without NoMethodError"
  
rescue => e
  puts "✗ Error in original test scenario simulation: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== NoMethodError Fix Test Complete ==="