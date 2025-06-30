#!/usr/bin/env ruby

require_relative 'src/reasoning/cross_paradigm_coordinator'

# Test script to validate nil handling fixes
puts "Testing nil handling in CrossParadigmCoordinator..."

coordinator = CrossParadigmCoordinator.new

# Test 1: nil type_analysis in optimize_goals_with_type_information
puts "\n1. Testing nil type_analysis handling..."
begin
  goals = [{ name: "test_goal" }]
  type_context = { relevant_types: nil }
  result = coordinator.optimize_goals_with_type_information(goals, type_context)
  puts "✓ Handled nil type_analysis successfully"
rescue => e
  puts "✗ Error with nil type_analysis: #{e.message}"
end

# Test 2: nil logic_context in enhance_constraints_with_logic_rules
puts "\n2. Testing nil logic_context handling..."
begin
  constraints = [{ variable: "x", type: "Number" }]
  logic_context = nil
  result = coordinator.enhance_constraints_with_logic_rules(constraints, logic_context)
  puts "✓ Handled nil logic_context successfully"
rescue => e
  puts "✗ Error with nil logic_context: #{e.message}"
end

# Test 3: nil execution_history in detect_emergent_behaviors
puts "\n3. Testing nil execution_history handling..."
begin
  execution_history = nil
  result = coordinator.detect_emergent_behaviors(execution_history)
  puts "✓ Handled nil execution_history successfully"
rescue => e
  puts "✗ Error with nil execution_history: #{e.message}"
end

# Test 4: Test workflow execution with nil components
puts "\n4. Testing workflow with nil components..."
begin
  workflow = "workflow test() { }"
  result = coordinator.execute_workflow("test", workflow, {})
  puts "✓ Handled workflow with nil components successfully"
rescue => e
  puts "✗ Error with workflow nil components: #{e.message}"
end

puts "\nNil handling test completed."