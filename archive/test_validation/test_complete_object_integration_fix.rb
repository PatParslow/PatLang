#!/usr/bin/env ruby

require_relative 'src/patlang'

# Test to verify the complete fix for Object model integration issues
puts "=== Complete Object Integration Fix Test ==="
puts

# Test 1: Complete property assignment workflow
puts "Test 1: Complete property assignment workflow"
begin
  # Create object first, then assign to property
  result1 = Patlang.evaluate("obj = Object.new")
  puts "✓ Object creation: #{result1}"
  
  result2 = Patlang.evaluate("obj.value = -5")
  puts "✓ Property assignment: #{result2}"
  
  # Verify the property was set
  evaluator = Evaluator.new
  evaluator.evaluate(FunctionCallNode.new(
    :print, 
    [StringNode.new("Object created and property assigned successfully")]
  ))
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "  Class: #{e.class}"
end

puts

# Test 2: Multi-line script with property assignment
puts "Test 2: Multi-line script with property assignment"
script = <<~SCRIPT
  obj = Object.new
  obj.value = -5
  obj.name = "test"
SCRIPT

begin
  result = Patlang.evaluate(script)
  puts "✓ Multi-line property assignment succeeded: #{result}"
rescue => e
  puts "✗ Error: #{e.message}"
  puts "  Class: #{e.class}"
  
  # Check if this is the specific error we were fixing
  if e.message.include?("Undefined variable: =")
    puts "  *** ERROR: Still getting '=' undefined variable error ***"
  end
end

puts

# Test 3: Test the original failing constraint scenario
puts "Test 3: Original failing constraint scenario"
constraint_script = <<~SCRIPT
  obj = Object.new
  constrain obj.value :: Number where value >= 0
  obj.value = -5
SCRIPT

begin
  result = Patlang.evaluate(constraint_script)
  puts "✓ Constraint scenario worked: #{result}"
rescue => e
  puts "✗ Expected constraint violation: #{e.message}"
  puts "  Class: #{e.class}"
  
  # This should NOT be the "Undefined variable: =" error anymore
  if e.message.include?("Undefined variable: =")
    puts "  *** PROBLEM: Still getting '=' undefined variable error ***"
  else
    puts "  ✓ Good: No longer getting '=' undefined variable error"
  end
end

puts

# Test 4: Object class availability
puts "Test 4: Object class availability in all contexts"
object_tests = [
  "Object",
  "Object.new",
  "make obj = Object.new"
]

object_tests.each_with_index do |test, i|
  puts "Test 4.#{i+1}: #{test}"
  begin
    result = Patlang.evaluate(test)
    puts "  ✓ Success: #{result}"
  rescue => e
    puts "  ✗ Error: #{e.message}"
    if e.message.include?("Undefined variable: Object")
      puts "    *** PROBLEM: Object class not available ***"
    end
  end
end

puts
puts "=== Fix Validation Complete ==="