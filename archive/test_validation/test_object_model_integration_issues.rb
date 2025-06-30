#!/usr/bin/env ruby

require_relative 'src/patlang'

# Test script to reproduce the Object model integration issues
# Focus on "Undefined variable: Object" and "Undefined variable: =" errors

puts "=== Object Model Integration Issues Test ==="
puts

# Test 1: Check if Object class is available in evaluator scope
puts "Test 1: Object class availability"
begin
  evaluator = Evaluator.new
  
  # Try to access Object directly from variables
  object_class = evaluator.get_variable('Object')
  puts "✓ Object class found in evaluator scope: #{object_class.class}"
  
  # Test Object.new functionality
  if object_class.respond_to?(:new)
    new_obj = object_class.new
    puts "✓ Object.new works: #{new_obj.class}"
  else
    puts "✗ Object.new not available"
  end
  
rescue => e
  puts "✗ Error accessing Object: #{e.message}"
  puts "   Class: #{e.class}"
end

puts

# Test 2: Test assignment parsing that might cause "=" undefined variable
puts "Test 2: Assignment parsing"
begin
  # Simple assignment that should work
  result = Patlang.evaluate("x = 5")
  puts "✓ Simple assignment works: x = 5 → #{result}"
  
  # Object creation assignment
  result = Patlang.evaluate("obj = Object.new")
  puts "✓ Object assignment works: obj = Object.new → #{result}"
  
rescue => e
  puts "✗ Assignment error: #{e.message}"
  puts "   Class: #{e.class}"
  
  # Let's check if the error mentions "=" as undefined variable
  if e.message.include?("Undefined variable: =")
    puts "   *** FOUND THE '=' UNDEFINED VARIABLE ERROR ***"
  end
end

puts

# Test 3: Test if Object is missing from PatlangObject require
puts "Test 3: PatlangObject integration"
begin
  evaluator = Evaluator.new
  
  # Check if PatlangObject is accessible
  if defined?(PatlangObject)
    puts "✓ PatlangObject is defined"
    
    # Test creating PatlangObject
    obj = PatlangObject.new("test")
    puts "✓ PatlangObject creation works: #{obj}"
  else
    puts "✗ PatlangObject not defined"
  end
  
rescue => e
  puts "✗ PatlangObject error: #{e.message}"
end

puts

# Test 4: Check for missing requires
puts "Test 4: Required dependencies check"
begin
  # Check if object model files are properly required
  required_classes = [
    'PatlangObject',
    'ObjectModelIntegration',
    'EventSystem'
  ]
  
  required_classes.each do |class_name|
    if Object.const_defined?(class_name)
      puts "✓ #{class_name} is loaded"
    else
      puts "✗ #{class_name} is NOT loaded"
    end
  end
  
rescue => e
  puts "✗ Dependency check error: #{e.message}"
end

puts

# Test 5: Detailed error reproduction
puts "Test 5: Reproduce specific parsing errors"
test_expressions = [
  "Object.new",
  "x = Object.new", 
  "make obj = Object.new",
  "obj = Object.new()",
  "Object"
]

test_expressions.each_with_index do |expr, i|
  puts "Test 5.#{i+1}: #{expr}"
  begin
    result = Patlang.evaluate(expr)
    puts "  ✓ Success: #{result}"
  rescue => e
    puts "  ✗ Error: #{e.message}"
    puts "    Class: #{e.class}"
    
    # Check for the specific errors we're looking for
    if e.message.include?("Undefined variable: Object")
      puts "    *** FOUND 'Undefined variable: Object' ERROR ***"
    elsif e.message.include?("Undefined variable: =")
      puts "    *** FOUND 'Undefined variable: =' ERROR ***"
    end
  end
  puts
end

puts "=== Test Complete ==="