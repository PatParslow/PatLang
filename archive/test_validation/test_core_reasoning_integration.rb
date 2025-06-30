#!/usr/bin/env ruby

# Core test to validate Phase 1 evaluator integration

require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

puts "=== Core Phase 1 Reasoning Integration Test ==="

def assert_equal(expected, actual)
  unless expected == actual
    raise "Assertion failed: expected #{expected.inspect}, got #{actual.inspect}"
  end
end

def assert(condition)
  unless condition
    raise "Assertion failed: condition was false"
  end
end

evaluator = Evaluator.new

# Test 1: Reasoning mode control
puts "1. Testing reasoning mode control..."
assert_equal false, evaluator.reasoning_mode_enabled?
evaluator.enable_reasoning_mode
assert_equal true, evaluator.reasoning_mode_enabled?
puts "   ✓ Reasoning mode control works"

# Test 2: Constraint creation
puts "2. Testing constraint creation..."
constraint = evaluator.create_constraint('x', :type, :Number)
assert constraint.is_a?(TypeConstraint)
puts "   ✓ Constraint creation works"

# Test 3: Assignment validation 
puts "3. Testing assignment validation..."
assert_equal true, evaluator.validate_assignment('y', 42)
begin
  evaluator.validate_assignment('x', "string")
  raise "Should have failed"
rescue ConstraintViolationError
  puts "   ✓ Assignment validation catches violations"
end

# Test 4: Assignment node with constraints
puts "4. Testing assignment node evaluation..."
evaluator.create_constraint('score', :type, :Number)
number_node = NumberNode.new(85)
assignment_node = AssignmentNode.new('score', number_node)
result = evaluator.evaluate(assignment_node)
assert_equal 85, result
assert_equal 85, evaluator.get_variable('score')
puts "   ✓ Assignment node evaluation works"

# Test 5: Performance acceptable
puts "5. Testing performance..."
stats = evaluator.reasoning_statistics
performance_ok = evaluator.reasoning_evaluator.performance_acceptable?
assert_equal true, performance_ok
puts "   ✓ Performance is acceptable"

puts "\n🎯 CORE PHASE 1 INTEGRATION SUCCESSFUL!"
puts "✅ ReasoningEvaluator integrated with main Evaluator"
puts "✅ Constraint checking works during variable assignments"
puts "✅ Type constraint violations properly detected and reported"
puts "✅ Reasoning mode on/off functionality working"
puts "✅ Performance meets requirements"