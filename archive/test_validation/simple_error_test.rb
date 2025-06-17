#!/usr/bin/env ruby

# Simple test to identify the actual errors by running a minimal test
require 'minitest/autorun'

# Test the specific priority 1 errors mentioned in the task
class SimpleErrorTest < Minitest::Test
  def test_priority_1_errors
    # Test 1: Check if cross_paradigm_coordinator works
    begin
      require_relative 'src/reasoning/cross_paradigm_coordinator'
      coordinator = CrossParadigmCoordinator.new
      puts "✅ CrossParadigmCoordinator instantiated successfully"
    rescue => e
      puts "❌ CrossParadigmCoordinator error: #{e.class}: #{e.message}"
      puts "   Location: #{e.backtrace.first}"
    end
    
    # Test 2: Check if type_constraint_system works
    begin
      require_relative 'src/reasoning/type_constraint_system'
      system = TypeConstraintSystem.new
      puts "✅ TypeConstraintSystem instantiated successfully"
    rescue => e
      puts "❌ TypeConstraintSystem error: #{e.class}: #{e.message}"
      puts "   Location: #{e.backtrace.first}"
    end
    
    # Test 3: Check a simple constraint creation (where fire_event might fail)
    begin
      require_relative 'src/reasoning/type_constraint_system'
      system = TypeConstraintSystem.new
      constraint = system.create_constraint("test_var", :type, :string)
      puts "✅ Constraint creation successful"
    rescue => e
      puts "❌ Constraint creation error: #{e.class}: #{e.message}"
      puts "   Location: #{e.backtrace.first}"
    end
  end
  
  def test_priority_2_errors
    # Test symbol comparison issue
    begin
      require_relative 'src/reasoning/reasoning_integration' if File.exist?('src/reasoning/reasoning_integration.rb')
      puts "✅ reasoning_integration loaded"
    rescue => e
      puts "❌ reasoning_integration error: #{e.class}: #{e.message}"
      puts "   Location: #{e.backtrace.first}"
    end
    
    # Test unification engine
    begin
      require_relative 'src/reasoning/unification_engine'
      engine = UnificationEngine.new
      puts "✅ UnificationEngine instantiated successfully"
    rescue => e
      puts "❌ UnificationEngine error: #{e.class}: #{e.message}"
      puts "   Location: #{e.backtrace.first}"
    end
  end
end