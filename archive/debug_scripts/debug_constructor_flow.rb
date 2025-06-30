#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/reasoning/type_constraint'

puts "=== DEBUGGING TYPECONSTRAINT CONSTRUCTOR ==="

# Override the initialize method to debug
class TypeConstraint
  alias_method :original_initialize, :initialize
  
  def initialize(variable, constraint_type, constraint_data, **options)
    puts "  TypeConstraint.initialize called with:"
    puts "    variable: #{variable.inspect}"
    puts "    constraint_type: #{constraint_type.inspect}"
    puts "    constraint_data: #{constraint_data.inspect}"
    puts "    options: #{options.inspect}"
    
    @variable = variable.to_sym
    @constraint_type = constraint_type.to_sym
    @constraint_data = constraint_data
    @conditions = options[:conditions] || []
    @metadata = options[:metadata] || {}
    
    puts "  After initialization:"
    puts "    @variable: #{@variable.inspect}"
    puts "    @constraint_type: #{@constraint_type.inspect}"
    puts "    @constraint_data: #{@constraint_data.inspect}"
    puts "    constraint_data method: #{constraint_data.inspect}"
    puts
  end
end

# Override TypeConstraintSystem.create_constraint to debug
class TypeConstraintSystem
  alias_method :original_create_constraint, :create_constraint
  
  def create_constraint(variable, constraint_type, constraint_data, **options)
    puts "TypeConstraintSystem.create_constraint called with:"
    puts "  variable: #{variable.inspect}"
    puts "  constraint_type: #{constraint_type.inspect}"
    puts "  constraint_data: #{constraint_data.inspect}"
    puts "  options: #{options.inspect}"
    puts
    
    result = original_create_constraint(variable, constraint_type, constraint_data, **options)
    
    puts "TypeConstraintSystem.create_constraint returning:"
    puts "  result.constraint_data: #{result.constraint_data.inspect}"
    puts
    
    result
  end
end

puts "1. Creating constraint via TypeConstraintSystem..."
system = TypeConstraintSystem.new
constraint = system.create_constraint(:x, :type, :Number)

puts "Final result:"
puts "  constraint_data: #{constraint.constraint_data.inspect}"