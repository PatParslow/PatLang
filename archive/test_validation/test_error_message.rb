#!/usr/bin/env ruby

# Test the exact error message for propagation conflicts

require_relative 'src/reasoning/type_constraint'

puts "🔍 TESTING ERROR MESSAGE CASE"
puts "=" * 40

# Create the exact test scenario
constraint_system = TypeConstraintSystem.new

# Set up the conflict scenario from the test
constraint_system.create_constraint(:x, :range, 1..10)
constraint_system.create_constraint(:y, :range, 1..5)
constraint_system.add_relationship(:x, :y, ->(x_val) { x_val * 2 })

begin
  # This should trigger the error
  constraint_system.set_variable_value(:x, 5) # Would make y = 10, violating y's range
  puts "❌ No error was raised!"
rescue => e
  puts "✅ Error was raised:"
  puts "   Error class: #{e.class}"
  puts "   Error message: '#{e.message}'"
  puts "   Includes 'propagation': #{e.message.include?('propagation')}"
  puts "   Includes 'Propagation': #{e.message.include?('Propagation')}"
  puts "   Includes 'conflict': #{e.message.include?('conflict')}"
end