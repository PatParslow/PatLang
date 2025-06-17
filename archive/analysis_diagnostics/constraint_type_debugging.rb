#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/reasoning/reasoning_coordinator'

puts "=== CONSTRAINT TYPE DEBUGGING ==="
puts "Investigating the constraint type checking logic"
puts

def debug_constraint_internals
  evaluator = Evaluator.new
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  reasoning_coordinator.enable_reasoning_mode
  
  puts "1. Creating constraint with detailed inspection..."
  constraint = reasoning_coordinator.create_constraint(:x, :type, :Number)
  
  puts "   constraint.variable: #{constraint.variable.inspect}"
  puts "   constraint.constraint_type: #{constraint.constraint_type.inspect}"
  puts "   constraint.constraint_data: #{constraint.constraint_data.inspect}"
  puts "   constraint.constraint_data.class: #{constraint.constraint_data.class}"
  
  puts "\n2. Testing constraint type resolution..."
  
  # Test the internal method directly
  case constraint.constraint_type
  when :type
    puts "   ✓ Constraint type is :type as expected"
    puts "   Calling satisfies_type_constraint? directly..."
    
    # Test with valid number
    result_42 = constraint.send(:satisfies_type_constraint?, 42)
    puts "   satisfies_type_constraint?(42): #{result_42}"
    
    # Test with invalid string
    result_string = constraint.send(:satisfies_type_constraint?, "string")
    puts "   satisfies_type_constraint?('string'): #{result_string}"
    
    # Check constraint_data match
    puts "\n   Checking constraint_data logic:"
    puts "   constraint_data == :Number: #{constraint.constraint_data == :Number}"
    puts "   constraint_data == :Numeric: #{constraint.constraint_data == :Numeric}"
    puts "   constraint_data.inspect: #{constraint.constraint_data.inspect}"
    
    # Manual type checking
    puts "\n   Manual type checking:"
    puts "   42.is_a?(Numeric): #{42.is_a?(Numeric)}"
    puts "   'string'.is_a?(Numeric): #{'string'.is_a?(Numeric)}"
    
  else
    puts "   ✗ Unexpected constraint type: #{constraint.constraint_type}"
  end
  
  puts "\n3. Step-by-step satisfies? method debugging..."
  
  # Override the satisfies? method temporarily to add debugging
  class << constraint
    alias_method :original_satisfies?, :satisfies?
    
    def satisfies?(value)
      puts "     satisfies?(#{value.inspect}) called"
      puts "     @constraint_type: #{@constraint_type.inspect}"
      
      case @constraint_type
      when :type
        puts "     Calling satisfies_type_constraint?..."
        result = satisfies_type_constraint?(value)
        puts "     satisfies_type_constraint? returned: #{result}"
        return result
      else
        puts "     Non-type constraint, returning false"
        return false
      end
    end
  end
  
  puts "\n   Testing with debugging enabled:"
  puts "   constraint.satisfies?(42):"
  result1 = constraint.satisfies?(42)
  puts "   Final result: #{result1}"
  
  puts "\n   constraint.satisfies?('string'):"
  result2 = constraint.satisfies?("string")
  puts "   Final result: #{result2}"
  
  # Check if there's a constraint_data issue
  puts "\n4. Investigating constraint_data issue..."
  
  # Create a constraint manually to compare
  manual_constraint = TypeConstraint.new(:y, :type, :Number)
  puts "   Manual constraint.constraint_data: #{manual_constraint.constraint_data.inspect}"
  puts "   Manual constraint.satisfies?(42): #{manual_constraint.satisfies?(42)}"
  puts "   Manual constraint.satisfies?('string'): #{manual_constraint.satisfies?('string')}"
end

debug_constraint_internals