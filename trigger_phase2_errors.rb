#!/usr/bin/env ruby

puts "=== Triggering Phase 2 Reasoning System Errors ==="

# Load all reasoning files first
require_relative 'src/reasoning/unification_engine'
require_relative 'src/reasoning/type_constraint_system'
require_relative 'src/reasoning/type_constraint'
require_relative 'src/reasoning/reasoning_coordinator'

puts "\n1. Testing Unification Engine around line 95..."
begin
  ue = UnificationEngine.new
  
  # Try different scenarios that might trigger the boolean vs callable issue
  puts "  Testing basic unification..."
  result1 = ue.unify("X", "test", {})
  puts "  ✓ Basic unification: #{result1}"
  
  puts "  Testing statistics method (around line 95)..."
  stats = ue.statistics
  puts "  ✓ Statistics: #{stats}"
  
  # Try more complex unification that might trigger the error
  puts "  Testing complex unification..."
  result2 = ue.unify(["X", "Y"], ["a", "b"], {})
  puts "  ✓ Complex unification: #{result2}"
  
rescue => e
  puts "  ✗ Unification Engine error: #{e.message}"
  puts "  Location: #{e.backtrace.first}"
end

puts "\n2. Testing Type Constraint System around line 45..."
begin
  tcs = TypeConstraintSystem.new
  
  # Test adding constraints
  puts "  Testing constraint addition..."
  constraint = tcs.add_constraint("X", :type, String)
  puts "  ✓ Added constraint: #{constraint}"
  
  # Test constraint satisfaction (might trigger nil access)
  puts "  Testing constraint satisfaction..."
  satisfies = tcs.satisfies_all_constraints?("X", "test")
  puts "  ✓ Satisfies constraints: #{satisfies}"
  
  # Test with nil values that might cause the error
  puts "  Testing with potential nil access scenarios..."
  satisfies_nil = tcs.satisfies_all_constraints?("Y", nil)
  puts "  ✓ Nil value handling: #{satisfies_nil}"
  
rescue => e
  puts "  ✗ Type Constraint System error: #{e.message}"
  puts "  Location: #{e.backtrace.first}"
end

puts "\n3. Testing Reasoning Coordinator around line 153..."
begin
  rc = ReasoningCoordinator.new
  
  # Enable reasoning mode first
  rc.enable_reasoning_mode
  
  # Test goal definition and pursuit (might trigger "string_goal" error)
  puts "  Testing goal definition..."
  rc.define_goal("test_goal", strategy: -> { puts "Test goal executed" })
  puts "  ✓ Goal defined successfully"
  
  # Test pursuing a goal that exists
  puts "  Testing goal pursuit..."
  result = rc.pursue_goal("test_goal")
  puts "  ✓ Goal pursued: #{result}"
  
  # Test pursuing a goal that doesn't exist (should trigger the error)
  puts "  Testing undefined goal pursuit (should trigger error)..."
  begin
    result2 = rc.pursue_goal("string_goal")
    puts "  ✗ Undefined goal should have failed but didn't"
  rescue => goal_error
    puts "  ✓ Expected error for undefined goal: #{goal_error.message}"
  end
  
rescue => e
  puts "  ✗ Reasoning Coordinator error: #{e.message}"
  puts "  Location: #{e.backtrace.first}"
end

puts "\n4. Testing Type Constraint call scenarios..."
begin
  # Test TypeConstraint with different constraint types
  tc = TypeConstraint.new("X", :custom, -> (v) { v.is_a?(String) })
  puts "  Testing Proc constraint..."
  result = tc.satisfies?("test")
  puts "  ✓ Proc constraint: #{result}"
  
  # Test with boolean that might be incorrectly called
  tc_bool = TypeConstraint.new("Y", :custom, true)
  puts "  Testing boolean constraint (might trigger .call error)..."
  result_bool = tc_bool.satisfies?("test")
  puts "  ✓ Boolean constraint: #{result_bool}"
  
rescue => e
  puts "  ✗ Type Constraint error: #{e.message}"
  puts "  Location: #{e.backtrace.first}"
end

puts "\n=== Phase 2 Error Triggering Complete ==="