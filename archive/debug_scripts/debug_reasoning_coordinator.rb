#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== DEBUGGING REASONING COORDINATOR FLOW ==="

evaluator = Evaluator.new
evaluator.enable_object_mode
coordinator = ReasoningCoordinator.new(evaluator)
coordinator.enable_reasoning_mode

puts "1. Creating constraint via ReasoningCoordinator..."
constraint = coordinator.create_constraint(:x, :type, :Number)

puts "   variable: #{constraint.variable.inspect}"
puts "   constraint_type: #{constraint.constraint_type.inspect}"
puts "   constraint_data: #{constraint.constraint_data.inspect}"

puts "\n2. Testing satisfies? method..."
puts "   satisfies?(42): #{constraint.satisfies?(42)}"
puts "   satisfies?('string'): #{constraint.satisfies?('string')}"

puts "\n3. Debugging constraint object class..."
puts "   constraint.class: #{constraint.class.name}"
puts "   constraint.inspect: #{constraint.inspect}"

puts "\n4. Testing constraint system directly..."
system_constraints = coordinator.constraint_system.get_constraints(:x)
puts "   Number of constraints in system: #{system_constraints.length}"
system_constraints.each_with_index do |c, i|
  puts "   System Constraint #{i}:"
  puts "     class: #{c.class.name}"
  puts "     constraint_data: #{c.constraint_data.inspect}"
  puts "     satisfies?(42): #{c.satisfies?(42)}"
  puts "     satisfies?('string'): #{c.satisfies?('string')}"
end

puts "\n5. Testing variable_satisfies? method..."
puts "   system.variable_satisfies?(:x, 42): #{coordinator.constraint_system.variable_satisfies?(:x, 42)}"
puts "   system.variable_satisfies?(:x, 'string'): #{coordinator.constraint_system.variable_satisfies?(:x, "string")}"