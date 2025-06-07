#!/usr/bin/env ruby
# Debugging script to find missing satisfies? method implementations

require_relative 'src/patlang'

puts "=== Debugging satisfies? method NoMethodError issues ==="

# Test 1: Check if TypeConstraint has satisfies? method
puts "\n1. Testing TypeConstraint class..."
begin
  require_relative 'src/reasoning/type_constraint'
  constraint = TypeConstraint.new(:test, :type, :Number)
  puts "TypeConstraint#satisfies? exists: #{constraint.respond_to?(:satisfies?)}"
  result = constraint.satisfies?(42)
  puts "TypeConstraint#satisfies?(42) returns: #{result}"
rescue => e
  puts "Error with TypeConstraint: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 2: Check the test that's failing
puts "\n2. Testing reasoning integration test pattern..."
begin
  # Run a simple version of the test that's failing
  require_relative 'test/helpers/test_helper'
  require_relative 'test/patlang_language/test_reasoning_integration'
  
  test_instance = Test::Unit::TestCase.new
  test_instance.extend(TestEvaluatorExtensions) if defined?(TestEvaluatorExtensions)
  
  puts "Test file loaded successfully"
rescue => e
  puts "Error loading test file: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 3: Search for any nil objects that might be causing the issue
puts "\n3. Checking for nil constraint scenarios..."
begin
  constraint_system = TypeConstraintSystem.new
  puts "TypeConstraintSystem created successfully"
  
  # Check if getting constraints for non-existent variable returns nil
  constraints = constraint_system.get_constraints(:nonexistent)
  puts "get_constraints(:nonexistent) returns: #{constraints.inspect}"
  
  # This might be where the nil comes from - if a constraint is not found
  if constraints.empty?
    puts "Empty constraints array - this is correct behavior"
  end
  
rescue => e
  puts "Error with constraint system: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== Debug Analysis Complete ==="