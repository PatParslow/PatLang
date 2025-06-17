#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== DEBUGGING CONSTRAINT PARAMETER ISSUE ==="
puts "Investigating the exact flow of parameter passing"
puts

def trace_parameter_flow
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  puts "1. Calling create_constraint(:x, :type, :Number)..."
  puts "   Parameters passed:"
  puts "   - variable: :x"
  puts "   - constraint_type: :type"  
  puts "   - constraint_data: :Number"
  
  # Let's trace exactly what happens
  puts "\n2. Tracing parameter flow through create_constraint..."
  
  # Override create_constraint to add debugging
  class << reasoning_coordinator
    alias_method :original_create_constraint, :create_constraint
    
    def create_constraint(variable, constraint_type, constraint_data, **options)
      puts "   ReasoningCoordinator.create_constraint called with:"
      puts "     variable: #{variable.inspect}"
      puts "     constraint_type: #{constraint_type.inspect}"
      puts "     constraint_data: #{constraint_data.inspect}"
      puts "     options: #{options.inspect}"
      
      # Call the constraint system
      puts "\n   Calling constraint_system.create_constraint..."
      constraint = @constraint_system.create_constraint(variable, constraint_type, constraint_data, **options)
      
      puts "   Returned constraint:"
      puts "     constraint.variable: #{constraint.variable.inspect}"
      puts "     constraint.constraint_type: #{constraint.constraint_type.inspect}"
      puts "     constraint.constraint_data: #{constraint.constraint_data.inspect}"
      
      constraint
    end
  end
  
  # Override TypeConstraintSystem.create_constraint to add debugging
  constraint_system = reasoning_coordinator.constraint_system
  class << constraint_system
    alias_method :original_create_constraint, :create_constraint
    
    def create_constraint(variable, constraint_type, constraint_data, **options)
      puts "   TypeConstraintSystem.create_constraint called with:"
      puts "     variable: #{variable.inspect}"
      puts "     constraint_type: #{constraint_type.inspect}" 
      puts "     constraint_data: #{constraint_data.inspect}"
      puts "     options: #{options.inspect}"
      
      # Call TypeConstraint.new
      puts "\n   Calling TypeConstraint.new..."
      constraint = TypeConstraint.new(variable, constraint_type, constraint_data, **options)
      
      puts "   TypeConstraint.new created:"
      puts "     @variable: #{constraint.instance_variable_get(:@variable).inspect}"
      puts "     @constraint_type: #{constraint.instance_variable_get(:@constraint_type).inspect}"
      puts "     @constraint_data: #{constraint.instance_variable_get(:@constraint_data).inspect}"
      
      # Add to constraints array
      @constraints[variable] ||= []
      @constraints[variable] << constraint
      
      constraint
    end
  end
  
  # Now create the constraint
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  
  puts "\n3. Final constraint state:"
  puts "   constraint.variable: #{constraint.variable.inspect}"
  puts "   constraint.constraint_type: #{constraint.constraint_type.inspect}"
  puts "   constraint.constraint_data: #{constraint.constraint_data.inspect}"
  
  puts "\n4. Testing satisfies? with correct parameters..."
  
  # Manual test to see what should happen
  manual_constraint = TypeConstraint.new(:test, :type, :Number)
  puts "   Manual constraint with correct parameters:"
  puts "     manual_constraint.constraint_data: #{manual_constraint.constraint_data.inspect}"
  puts "     manual_constraint.satisfies?(42): #{manual_constraint.satisfies?(42)}"
  puts "     manual_constraint.satisfies?('string'): #{manual_constraint.satisfies?('string')}"
end

trace_parameter_flow