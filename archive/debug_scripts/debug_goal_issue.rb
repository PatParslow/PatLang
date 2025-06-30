#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== Debug Goal Issue ==="

# Test Goal creation directly
puts "Creating Goal with parameters..."
goal = Goal.new("test_goal", parameters: [:x, :y], strategy: :default)

puts "Goal name: #{goal.name.inspect}"
puts "Goal parameters: #{goal.parameters.inspect}"
puts "Goal strategy: #{goal.strategy.inspect}"
puts "Goal preconditions: #{goal.preconditions.inspect}"
puts "Goal postconditions: #{goal.postconditions.inspect}"

puts "\n=== Testing ReasoningCoordinator Goal Creation ==="
evaluator = Evaluator.new
coordinator = ReasoningCoordinator.new(evaluator)
coordinator.enable_reasoning_mode

begin
  goal2 = coordinator.create_goal("test2", parameters: [:a, :b], strategy: :test)
  puts "Created goal: #{goal2.name}"
  puts "Goal parameters: #{goal2.parameters.inspect}"
  puts "Goal strategy: #{goal2.strategy.inspect}"
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end