#!/usr/bin/env ruby

require_relative 'test/helpers/test_helper'
require_relative 'src/reasoning/type_constraint_system'

puts "=== DEBUGGING TYPE CONSTRAINT SYSTEM ISSUES ==="
puts

# Test 1: Variable scope issue in constraint_message
puts "1. Testing variable scope issue in constraint_message"
begin
  constraint_system = TypeConstraintSystem.new
  constraint = constraint_system.create_constraint("x", :type, :Number)
  
  # This should trigger the NameError
  constraint.validate!("not_a_number")
rescue NameError => e
  puts "✅ CONFIRMED: NameError - #{e.message}"
  puts "   Location: #{e.backtrace.first}"
rescue => e
  puts "❌ Different error: #{e.class} - #{e.message}"
end
puts

# Test 2: Event system - constraint_created and constraint_validated events
puts "2. Testing event system"
event_log = []
constraint_system = TypeConstraintSystem.new

# Subscribe to events
constraint_system.on_event(:constraint_created) { |event| event_log << {type: :constraint_created, data: event[:data]} }
constraint_system.on_event(:constraint_validated) { |event| event_log << {type: :constraint_validated, data: event[:data]} }
constraint_system.on_event(:constraint_violated) { |event| event_log << {type: :constraint_violated, data: event[:data]} }

# Create constraint
puts "   Creating constraint..."
constraint = constraint_system.create_constraint("test_var", :type, :Number)

# Test constraint validation
puts "   Testing constraint validation..."
result1 = constraint_system.satisfies_all_constraints?("test_var", 42)
result2 = constraint_system.satisfies_all_constraints?("test_var", "not_a_number")

puts "   Events fired:"
event_log.each_with_index do |event, i|
  puts "     #{i+1}. #{event[:type]} - #{event[:data]}"
end

if event_log.any? { |e| e[:type] == :constraint_created }
  puts "✅ constraint_created event fired"
else
  puts "❌ constraint_created event NOT fired"
end

if event_log.any? { |e| e[:type] == :constraint_validated }
  puts "✅ constraint_validated event fired"
else
  puts "❌ constraint_validated event NOT fired"
end
puts

# Test 3: Hash/Float type coercion issue 
puts "3. Testing Hash/Float type coercion"
begin
  constraint_system = TypeConstraintSystem.new
  constraint_system.create_constraint("hash_var", :type, :Hash)
  constraint_system.create_constraint("float_var", :type, :Number)
  
  # Test hash constraint with float (should fail)
  hash_result = constraint_system.satisfies_all_constraints?("hash_var", 3.14)
  puts "   Hash constraint with float: #{hash_result ? 'PASS (unexpected)' : 'FAIL (expected)'}"
  
  # Test float constraint with hash (should fail)
  float_result = constraint_system.satisfies_all_constraints?("float_var", {key: "value"})
  puts "   Float constraint with hash: #{float_result ? 'PASS (unexpected)' : 'FAIL (expected)'}"
  
  # Test arithmetic operations (this might be where the Hash/Float coercion issue occurs)
  puts "   Testing arithmetic operations..."
  
rescue => e
  puts "❌ Hash/Float coercion error: #{e.class} - #{e.message}"
  puts "   #{e.backtrace.first}"
end
puts

puts "=== DIAGNOSIS COMPLETE ==="