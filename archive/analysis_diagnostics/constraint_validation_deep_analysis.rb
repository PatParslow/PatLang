#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== CONSTRAINT VALIDATION DEEP ANALYSIS ==="
puts "Investigating why TypeConstraintViolation exceptions are not raised"
puts

def debug_constraint_validation
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  puts "1. Creating constraint..."
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  puts "   Constraint created: #{constraint.inspect}"
  puts "   Constraint class: #{constraint.class.name}"
  puts "   Constraint responds to satisfies?: #{constraint.respond_to?(:satisfies?)}"
  
  puts "\n2. Testing constraint directly..."
  puts "   constraint.satisfies?(42): #{constraint.satisfies?(42)}"
  puts "   constraint.satisfies?('string'): #{constraint.satisfies?('string')}"
  
  puts "\n3. Testing constraint system..."
  constraint_system = reasoning_coordinator.constraint_system
  puts "   Constraint system class: #{constraint_system.class.name}"
  
  constraints = constraint_system.get_constraints(:x)
  puts "   Retrieved constraints: #{constraints.inspect}"
  puts "   Number of constraints: #{constraints.length}"
  
  puts "\n4. Testing variable_satisfies?..."
  satisfies_valid = constraint_system.variable_satisfies?(:x, 42)
  puts "   variable_satisfies?(:x, 42): #{satisfies_valid}"
  
  satisfies_invalid = constraint_system.variable_satisfies?(:x, "string")
  puts "   variable_satisfies?(:x, 'string'): #{satisfies_invalid}"
  
  puts "\n5. Testing validate_assignment with valid value..."
  begin
    result = reasoning_coordinator.validate_assignment(:x, 42)
    puts "   validate_assignment(:x, 42) returned: #{result}"
  rescue => e
    puts "   validate_assignment(:x, 42) raised: #{e.class.name}: #{e.message}"
  end
  
  puts "\n6. Testing validate_assignment with invalid value..."
  begin
    result = reasoning_coordinator.validate_assignment(:x, "string")
    puts "   validate_assignment(:x, 'string') returned: #{result}"
    puts "   ERROR: Should have raised TypeConstraintViolation!"
  rescue TypeConstraintViolation => e
    puts "   ✓ TypeConstraintViolation correctly raised: #{e.message}"
  rescue => e
    puts "   ✗ Wrong exception type raised: #{e.class.name}: #{e.message}"
  end
  
  puts "\n7. Debugging the validation logic..."
  
  # Step through the validation logic manually
  variable = :x
  value = "string"
  
  puts "   reasoning_mode enabled?: #{reasoning_coordinator.reasoning_mode_enabled?}"
  
  satisfies_result = constraint_system.variable_satisfies?(variable, value)
  puts "   constraint_system.variable_satisfies?(#{variable}, #{value.inspect}): #{satisfies_result}"
  
  if !satisfies_result
    violated_constraints = constraint_system.get_constraints(variable).compact.reject { |c| c.satisfies?(value) }
    puts "   violated_constraints: #{violated_constraints.inspect}"
    puts "   violated_constraints.length: #{violated_constraints.length}"
    
    constraint = violated_constraints.first
    puts "   first violated constraint: #{constraint.inspect}"
    
    if constraint
      puts "   Should raise TypeConstraintViolation with:"
      puts "     variable: #{variable}"
      puts "     value: #{value}"
      puts "     message: Assignment violates constraint: #{constraint}"
    else
      puts "   ✗ No violated constraint found - this is the bug!"
    end
  else
    puts "   ✗ variable_satisfies? returned true when it should be false!"
  end
end

debug_constraint_validation