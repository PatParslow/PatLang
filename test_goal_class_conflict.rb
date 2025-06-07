#!/usr/bin/env ruby
# frozen_string_literal: true

puts "=== Goal Class Conflict Test ==="

# Load reasoning_coordinator first
require_relative 'src/reasoning/reasoning_coordinator'
puts "After loading reasoning_coordinator:"
goal1 = Goal.new("test1", parameters: [:x, :y])
puts "Goal1 class: #{goal1.class}"
puts "Goal1 responds to has_subgoals?: #{goal1.respond_to?(:has_subgoals?)}"
puts "Goal1 parameters: #{goal1.parameters.inspect}"

# Now load goal_system - this might redefine Goal
require_relative 'src/reasoning/goal_system'
puts "\nAfter loading goal_system:"
goal2 = Goal.new("test2", parameters: [:a, :b])
puts "Goal2 class: #{goal2.class}"
puts "Goal2 responds to has_subgoals?: #{goal2.respond_to?(:has_subgoals?)}"
puts "Goal2 parameters: #{goal2.parameters.inspect}"

# Check if they're the same class
puts "\nSame class? #{goal1.class == goal2.class}"