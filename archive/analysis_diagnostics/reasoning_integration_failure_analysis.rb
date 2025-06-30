#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/parser'
require_relative 'src/lexer'

puts "=== REASONING INTEGRATION SYSTEM FAILURE ANALYSIS ==="
puts "Analyzing specific failure patterns in reasoning integration system"
puts

# Track different types of failures
failure_patterns = {
  event_system_failures: [],
  goal_execution_failures: [],
  constraint_validation_failures: [],
  nil_reference_failures: [],
  variable_scoping_failures: []
}

def analyze_test_failure(test_name, &test_block)
  puts "Testing: #{test_name}"
  
  begin
    test_block.call
    puts "  ✓ PASSED"
    return :passed
  rescue => e
    puts "  ✗ FAILED: #{e.class.name}: #{e.message}"
    puts "    Location: #{e.backtrace.first}" if e.backtrace
    return { error_type: e.class.name, message: e.message, backtrace: e.backtrace&.first }
  end
end

# Test 1: Event System Integration
puts "\n--- 1. EVENT SYSTEM INTEGRATION ANALYSIS ---"

failure_patterns[:event_system_failures] << analyze_test_failure("Goal Created Event Firing") do
  evaluator = Evaluator.new
  evaluator.enable_object_mode
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  evaluator.set_reasoning_coordinator(reasoning_coordinator)
  
  event_log = []
  reasoning_coordinator.on_event(:goal_created) { |e| event_log << e }
  
  reasoning_coordinator.enable_reasoning_mode
  goal = reasoning_coordinator.create_goal("test_goal", parameters: [:x])
  
  raise "Goal created event not fired" if event_log.empty?
  raise "Event data incomplete" unless event_log.first.key?(:name)
end

failure_patterns[:event_system_failures] << analyze_test_failure("Event Handler Registration") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  
  handler_called = false
  reasoning_coordinator.on_event(:test_event) { |e| handler_called = true }
  
  # Try to fire a test event
  reasoning_coordinator.send(:fire_event, :test_event, { test: true })
  
  raise "Event handler not called" unless handler_called
end

# Test 2: Goal System Integration
puts "\n--- 2. GOAL SYSTEM INTEGRATION ANALYSIS ---"

failure_patterns[:goal_execution_failures] << analyze_test_failure("Goal Creation and Execution") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  goal = reasoning_coordinator.create_goal("find_even", parameters: [:result])
  raise "Goal not created properly" unless goal.is_a?(Goal)
  
  result = reasoning_coordinator.pursue_goal("find_even")
  raise "Goal execution failed" unless result.is_a?(Numeric)
end

failure_patterns[:goal_execution_failures] << analyze_test_failure("Variable Scoping in Goal Context") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  # Test variable scoping issues
  goal = reasoning_coordinator.create_goal("test_scope", parameters: [:x, :y])
  context = { x: 10, y: 20 }
  
  result = reasoning_coordinator.pursue_goal("test_scope", **context)
  raise "Context variables not accessible" if result.nil?
end

# Test 3: Constraint Validation
puts "\n--- 3. CONSTRAINT VALIDATION ANALYSIS ---"

failure_patterns[:constraint_validation_failures] << analyze_test_failure("Type Constraint Violation Detection") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  
  begin
    reasoning_coordinator.validate_assignment(:x, "string_value")
    raise "TypeConstraintViolation should have been raised"
  rescue TypeConstraintViolation => e
    # This is expected - constraint violation should be raised
    raise "TypeConstraintViolation missing variable info" unless e.variable
    raise "TypeConstraintViolation missing value info" unless e.value
  end
end

failure_patterns[:constraint_validation_failures] << analyze_test_failure("Constraint System Integration") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  retrieved = reasoning_coordinator.get_constraint(:x)
  
  raise "Constraint retrieval failed" if retrieved.nil?
  raise "Constraint satisfies method missing" unless retrieved.respond_to?(:satisfies?)
  
  # Test satisfies method
  unless retrieved.satisfies?(42)
    raise "Constraint should accept valid number"
  end
  
  if retrieved.satisfies?("string")
    raise "Constraint should reject invalid type"
  end
end

# Test 4: Nil Reference Issues
puts "\n--- 4. NIL REFERENCE ANALYSIS ---"

failure_patterns[:nil_reference_failures] << analyze_test_failure("Nil Safety in Reasoning Operations") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  # Test accessing undefined constraint
  constraint = reasoning_coordinator.get_constraint(:undefined_variable)
  
  # Should not raise NoMethodError
  result = constraint.satisfies?(42)
  raise "Nil constraint should return false, not crash" if result == true
end

failure_patterns[:nil_reference_failures] << analyze_test_failure("Array Access on Nil") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  
  # Test potential nil array access patterns
  facts = reasoning_coordinator.get_facts || []
  result = facts[0]  # Should not crash even if facts is nil
  
  goals = reasoning_coordinator.instance_variable_get(:@goals) || {}
  goal_list = goals.values  # Should not crash
end

# Test 5: Variable Scoping
puts "\n--- 5. VARIABLE SCOPING ANALYSIS ---"

failure_patterns[:variable_scoping_failures] << analyze_test_failure("Variable Context Management") do
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  # Test variable scoping in different contexts
  reasoning_coordinator.create_constraint(:x, :type, :Number)
  
  # Should work with symbol
  constraint1 = reasoning_coordinator.get_constraint(:x)
  raise "Symbol variable lookup failed" unless constraint1
  
  # Should work with string
  constraint2 = reasoning_coordinator.get_constraint("x")
  raise "String variable lookup failed" unless constraint2
end

# Report Analysis
puts "\n=== FAILURE PATTERN ANALYSIS SUMMARY ==="

failure_patterns.each do |category, failures|
  puts "\n#{category.to_s.upcase.gsub('_', ' ')}:"
  failures.each_with_index do |failure, index|
    if failure == :passed
      puts "  Test #{index + 1}: ✓ PASSED"
    else
      puts "  Test #{index + 1}: ✗ #{failure[:error_type]}"
      puts "    Message: #{failure[:message]}"
      puts "    Location: #{failure[:backtrace]}" if failure[:backtrace]
    end
  end
end

# Analysis of Root Causes
puts "\n=== ROOT CAUSE ANALYSIS ==="

root_causes = []

# Check for duplicate class definitions
if failure_patterns[:event_system_failures].any? { |f| f != :passed }
  root_causes << "DUPLICATE CLASS DEFINITIONS: Test file defines its own ReasoningCoordinator class that conflicts with src/ implementation"
end

# Check for missing dependencies
if failure_patterns[:goal_execution_failures].any? { |f| f != :passed && f[:error_type] =~ /NameError|NoMethodError/ }
  root_causes << "MISSING DEPENDENCIES: Required classes not properly loaded or integrated"
end

# Check for constraint validation issues
if failure_patterns[:constraint_validation_failures].any? { |f| f != :passed && f[:message] =~ /TypeConstraintViolation/ }
  root_causes << "CONSTRAINT VALIDATION FLOW: TypeConstraintViolation exceptions not properly raised in validation flow"
end

# Check for nil safety issues
if failure_patterns[:nil_reference_failures].any? { |f| f != :passed && f[:error_type] =~ /NoMethodError/ }
  root_causes << "NIL SAFETY: Missing null object patterns for undefined constraints and variables"
end

puts "\nIDENTIFIED ROOT CAUSES:"
root_causes.each_with_index do |cause, index|
  puts "  #{index + 1}. #{cause}"
end

puts "\n=== RECOMMENDED DIAGNOSTIC STEPS ==="
puts "1. Remove duplicate ReasoningCoordinator class from test file"
puts "2. Ensure proper require statements and class loading"
puts "3. Verify TypeConstraintViolation exception flow"
puts "4. Implement comprehensive nil safety patterns"
puts "5. Test variable scoping consistency across symbol/string formats"