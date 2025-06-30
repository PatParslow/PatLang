#!/usr/bin/env ruby
# Test script to validate the satisfies? method NoMethodError fix

require_relative 'src/patlang'

puts "=== Testing satisfies? method fix ==="

# Test 1: Check the specific failing test scenario
puts "\n1. Testing get_constraint method with missing constraints..."
begin
  require_relative 'src/reasoning/reasoning_coordinator'
  require_relative 'src/evaluator'
  
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # Test getting a constraint that doesn't exist
  result_symbol = coordinator.get_constraint(:nonexistent)
  result_string = coordinator.get_constraint("nonexistent")
  
  puts "get_constraint(:nonexistent) returns: #{result_symbol.inspect}"
  puts "get_constraint('nonexistent') returns: #{result_string.inspect}"
  
  if result_symbol.nil?
    puts "✓ Correctly returns nil for missing constraint (symbol)"
  else
    puts "✗ Unexpected result for missing constraint (symbol)"
  end
  
  if result_string.nil?
    puts "✓ Correctly returns nil for missing constraint (string)"
  else
    puts "✗ Unexpected result for missing constraint (string)"
  end
  
rescue => e
  puts "Error testing get_constraint: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 2: Test constraint creation and retrieval
puts "\n2. Testing constraint creation and retrieval..."
begin
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # Create a constraint
  constraint = coordinator.constraint_system.create_constraint(:test_var, :type, :Number)
  puts "Created constraint: #{constraint.inspect}"
  
  # Test retrieval with symbol
  retrieved_symbol = coordinator.get_constraint(:test_var)
  puts "Retrieved with symbol: #{retrieved_symbol.inspect}"
  
  # Test retrieval with string
  retrieved_string = coordinator.get_constraint("test_var")
  puts "Retrieved with string: #{retrieved_string.inspect}"
  
  # Test satisfies? method on the retrieved constraint
  if retrieved_symbol
    puts "Testing satisfies? on retrieved constraint:"
    puts "  satisfies?(42): #{retrieved_symbol.satisfies?(42)}"
    puts "  satisfies?('string'): #{retrieved_symbol.satisfies?('string')}"
  end
  
rescue => e
  puts "Error testing constraint creation: #{e.message}"
  puts e.backtrace.first(3)
end

# Test 3: Test with different variable name formats
puts "\n3. Testing cross-format variable lookup..."
begin
  evaluator = Evaluator.new
  coordinator = ReasoningCoordinator.new(evaluator)
  
  # Create constraint with string variable name
  constraint_str = coordinator.constraint_system.create_constraint("x", :type, :Number)
  puts "Created constraint with string 'x': #{constraint_str.inspect}"
  
  # Try to retrieve with symbol
  retrieved_with_sym = coordinator.get_constraint(:x)
  puts "Retrieved 'x' constraint with symbol :x: #{retrieved_with_sym.inspect}"
  
  # Create constraint with symbol variable name  
  constraint_sym = coordinator.constraint_system.create_constraint(:y, :type, :String)
  puts "Created constraint with symbol :y: #{constraint_sym.inspect}"
  
  # Try to retrieve with string
  retrieved_with_str = coordinator.get_constraint("y")
  puts "Retrieved :y constraint with string 'y': #{retrieved_with_str.inspect}"
  
rescue => e
  puts "Error testing cross-format lookup: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== Fix Validation Complete ==="