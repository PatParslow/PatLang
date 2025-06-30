#!/usr/bin/env ruby
# Test script to simulate the exact failing test scenario

require 'minitest/autorun'
require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/parser'
require_relative 'src/lexer'

puts "=== Testing Exact Scenario from test_logic_enhanced_type_checking ==="

begin
  # Simulate the exact test setup
  evaluator = Evaluator.new
  evaluator.enable_object_mode
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  evaluator.set_reasoning_coordinator(reasoning_coordinator)
  
  puts "Setup complete. ReasoningCoordinator class: #{reasoning_coordinator.class}"
  puts "ReasoningCoordinator methods: #{reasoning_coordinator.methods.grep(/get_constraint/)}"
  
  # Test the get_constraint method directly
  puts "\nTesting get_constraint method directly:"
  constraint = reasoning_coordinator.get_constraint(:x)
  puts "get_constraint(:x) returned: #{constraint.inspect}"
  puts "Constraint class: #{constraint.class}"
  
  # Test the satisfies? method call that was failing
  puts "\nTesting satisfies? method calls:"
  result1 = constraint.satisfies?(50)
  result2 = constraint.satisfies?(-5)
  result3 = constraint.satisfies?("string")
  
  puts "constraint.satisfies?(50): #{result1}"
  puts "constraint.satisfies?(-5): #{result2}"
  puts "constraint.satisfies?('string'): #{result3}"
  
  puts "\n✓ No NoMethodError - fix is working!"
  
rescue => e
  puts "✗ Error occurred: #{e.message}"
  puts "Error class: #{e.class}"
  puts e.backtrace.first(5)
end

puts "\n=== Test Complete ==="