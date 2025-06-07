#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/reasoning/type_constraint'

puts "=== DEBUGGING CONSTRAINT ISSUE ==="

# Create constraint directly
puts "1. Creating TypeConstraint directly..."
constraint = TypeConstraint.new(:test, :type, :Number)

puts "   variable: #{constraint.variable.inspect}"
puts "   constraint_type: #{constraint.constraint_type.inspect}"
puts "   constraint_data: #{constraint.constraint_data.inspect}"

puts "\n2. Testing satisfies? method..."
puts "   satisfies?(42): #{constraint.satisfies?(42)}"
puts "   satisfies?('string'): #{constraint.satisfies?('string')}"

puts "\n3. Examining initialization process..."
puts "   @constraint_type: #{constraint.instance_variable_get(:@constraint_type).inspect}"
puts "   @constraint_data: #{constraint.instance_variable_get(:@constraint_data).inspect}"

puts "\n4. Testing satisfies_type_constraint? directly..."
result_42 = constraint.send(:satisfies_type_constraint?, 42)
result_string = constraint.send(:satisfies_type_constraint?, "string")
puts "   satisfies_type_constraint?(42): #{result_42}"
puts "   satisfies_type_constraint?('string'): #{result_string}"

puts "\n5. Checking case statement path..."
case constraint.constraint_data
when :Number, :Numeric
  puts "   Path: :Number/:Numeric case"
when :String
  puts "   Path: :String case"
when :Boolean
  puts "   Path: :Boolean case"
else
  puts "   Path: default case (returns false)"
  puts "   constraint_data class: #{constraint.constraint_data.class}"
  puts "   constraint_data value: #{constraint.constraint_data.inspect}"
end