#!/usr/bin/env ruby

require_relative 'src/reasoning/type_constraint'

# Test to identify symbol vs string format issues
puts "=== Testing Type Constraint Return Value Formats ==="

# Create a type constraint system
system = TypeConstraintSystem.new

# Create a constraint and check what variable format is returned
constraint = system.create_constraint(:x, :type, :Number)

puts "Variable returned by constraint: #{constraint.variable.inspect} (#{constraint.variable.class})"
puts "Expected format: :x (Symbol)"
puts "Actual format: #{constraint.variable.inspect} (#{constraint.variable.class})"

# Check if variable is returned as symbol or string
if constraint.variable.is_a?(Symbol)
  puts "✓ Variable is correctly returned as symbol"
else
  puts "✗ Variable is incorrectly returned as #{constraint.variable.class}"
end

# Test constraint_type
puts "\nConstraint type returned: #{constraint.constraint_type.inspect} (#{constraint.constraint_type.class})"
if constraint.constraint_type.is_a?(Symbol)
  puts "✓ Constraint type is correctly returned as symbol"
else
  puts "✗ Constraint type is incorrectly returned as #{constraint.constraint_type.class}"
end

# Test constraint_data  
puts "\nConstraint data returned: #{constraint.constraint_data.inspect} (#{constraint.constraint_data.class})"
if constraint.constraint_data.is_a?(Symbol)
  puts "✓ Constraint data is correctly returned as symbol"
else
  puts "✗ Constraint data is incorrectly returned as #{constraint.constraint_data.class}"
end

# Test string representation
puts "\nConstraint string representation:"
puts "to_s: #{constraint.to_s}"
puts "inspect: #{constraint.inspect}"

# Test the methods that might be converting symbols to strings
puts "\n=== Testing TypeConstraint Methods ==="

# Test creating multiple constraints with different variables
test_variables = [:x, :y, :age, :name]
test_variables.each do |var|
  constraint = system.create_constraint(var, :type, :Number)
  puts "Input: #{var.inspect} -> Output: #{constraint.variable.inspect}"
  
  unless constraint.variable.is_a?(Symbol)
    puts "  ✗ ISSUE: Expected symbol, got #{constraint.variable.class}"
  end
end