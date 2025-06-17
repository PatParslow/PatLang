#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/reasoning/type_constraint'

puts "=== INVESTIGATING ASSIGNMENT BUG ==="
puts "Testing TypeConstraint initialization directly"
puts

# Test TypeConstraint initialization directly
puts "1. Testing TypeConstraint.new directly..."

constraint = TypeConstraint.new(:test, :type, :Number)
puts "   Created constraint:"
puts "   variable: #{constraint.instance_variable_get(:@variable)}"
puts "   constraint_type: #{constraint.instance_variable_get(:@constraint_type)}"
puts "   constraint_data: #{constraint.instance_variable_get(:@constraint_data)}"

puts "\n2. Testing line by line assignment..."

class TestConstraint
  def initialize(variable, constraint_type, constraint_data, **options)
    puts "   Input parameters:"
    puts "     variable: #{variable.inspect}"
    puts "     constraint_type: #{constraint_type.inspect}"
    puts "     constraint_data: #{constraint_data.inspect}"
    
    @variable = variable.to_sym
    puts "   After @variable assignment: #{@variable.inspect}"
    
    @constraint_type = constraint_type.to_sym  
    puts "   After @constraint_type assignment: #{@constraint_type.inspect}"
    
    @constraint_data = constraint_data
    puts "   After @constraint_data assignment: #{@constraint_data.inspect}"
    
    @conditions = options[:conditions] || []
    @metadata = options[:metadata] || {}
  end
  
  def variable; @variable; end
  def constraint_type; @constraint_type; end
  def constraint_data; @constraint_data; end
end

puts "\nCreating TestConstraint..."
test_constraint = TestConstraint.new(:x, :type, :Number)

puts "\nFinal values:"
puts "variable: #{test_constraint.variable}"
puts "constraint_type: #{test_constraint.constraint_type}"
puts "constraint_data: #{test_constraint.constraint_data}"

puts "\n3. Comparing with actual TypeConstraint..."
actual_constraint = TypeConstraint.new(:x, :type, :Number)
puts "TypeConstraint constraint_data: #{actual_constraint.constraint_data}"

# Check if there's some method override somewhere
puts "\n4. Checking TypeConstraint methods..."
puts "TypeConstraint has constraint_data method: #{TypeConstraint.instance_methods.include?(:constraint_data)}"
puts "TypeConstraint constraint_data method source:"

begin
  method = TypeConstraint.instance_method(:constraint_data)
  puts "Method defined in: #{method.source_location}"
rescue
  puts "Could not get method source location"
end