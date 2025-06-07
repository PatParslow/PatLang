#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'
require_relative 'src/reasoning/goal_system'

puts "=== Critical Fixes Validation Test ==="
puts

# Test 1: ReasoningCoordinator @components nil reference fix
puts "Test 1: ReasoningCoordinator @components initialization"
begin
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # This should work without nil reference errors
  coordinator.register_component("test_component", evaluator)
  
  # Verify component was registered
  retrieved_component = coordinator.get_component("test_component")
  if retrieved_component == evaluator
    puts "✅ PASS: @components hash works correctly"
  else
    puts "❌ FAIL: Component registration failed"
  end
rescue => e
  puts "❌ FAIL: @components nil reference error: #{e.message}"
  puts "  #{e.backtrace.first}"
end
puts

# Test 2: Goal constructor signature compatibility
puts "Test 2: Goal constructor compatibility"
begin
  # Test Goal creation with **options syntax (from goal_system.rb style)
  goal1 = Goal.new("test_goal", parameters: [:x, :y], strategy: :default)
  puts "✅ PASS: Goal created with **options syntax"
  
  # Test accessing goal properties
  if goal1.name == "test_goal" && goal1.parameters == [:x, :y] && goal1.strategy == :default
    puts "✅ PASS: Goal properties set correctly"
  else
    puts "❌ FAIL: Goal properties not set correctly"
    puts "  Name: #{goal1.name}, Parameters: #{goal1.parameters}, Strategy: #{goal1.strategy}"
  end
rescue => e
  puts "❌ FAIL: Goal constructor error: #{e.message}"
  puts "  #{e.backtrace.first}"
end
puts

# Test 3: Integration test - ReasoningCoordinator creating goals
puts "Test 3: ReasoningCoordinator goal creation integration"
begin
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  coordinator.enable_reasoning_mode
  
  # This should work without constructor argument errors
  goal = coordinator.create_goal("integration_test", parameters: [:a, :b], strategy: :test)
  
  if goal.name == "integration_test" && goal.parameters == [:a, :b]
    puts "✅ PASS: ReasoningCoordinator goal creation works"
  else
    puts "❌ FAIL: Goal creation produced incorrect result"
  end
rescue => e
  puts "❌ FAIL: Integration test error: #{e.message}"
  puts "  #{e.backtrace.first}"
end
puts

# Test 4: GoalSystem integration
puts "Test 4: GoalSystem with Goal class compatibility"
begin
  evaluator = Evaluator.new
  goal_system = GoalSystem.new(evaluator)
  
  # Test goal declaration (this uses Goal.new internally)
  goal = goal_system.declare_goal("system_test", "goal system_test {\n  description: \"Test goal\"\n}")
  
  if goal.name == "system_test"
    puts "✅ PASS: GoalSystem goal declaration works"
  else
    puts "❌ FAIL: GoalSystem goal declaration failed"
  end
rescue => e
  puts "❌ FAIL: GoalSystem error: #{e.message}"
  puts "  #{e.backtrace.first}"
end
puts

puts "=== Critical Fixes Validation Complete ==="