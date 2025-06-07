#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/reasoning/type_constraint'

puts "=== DEBUGGING SYSTEM CONSTRAINT CREATION ==="

# Test via TypeConstraintSystem
puts "1. Creating constraint via TypeConstraintSystem..."
system = TypeConstraintSystem.new
constraint = system.create_constraint(:x, :type, :Number)

puts "   variable: #{constraint.variable.inspect}"
puts "   constraint_type: #{constraint.constraint_type.inspect}"
puts "   constraint_data: #{constraint.constraint_data.inspect}"

puts "\n2. Testing satisfies? method..."
puts "   satisfies?(42): #{constraint.satisfies?(42)}"
puts "   satisfies?('string'): #{constraint.satisfies?('string')}"

puts "\n3. Checking constraint details..."
puts "   @constraint_type: #{constraint.instance_variable_get(:@constraint_type).inspect}"
puts "   @constraint_data: #{constraint.instance_variable_get(:@constraint_data).inspect}"

puts "\n4. Checking system constraints storage..."
constraints = system.get_constraints(:x)
puts "   Number of constraints: #{constraints.length}"
constraints.each_with_index do |c, i|
  puts "   Constraint #{i}: #{c.constraint_data.inspect}"
end