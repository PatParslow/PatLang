#!/usr/bin/env ruby

# Debug Type Constraint Propagation Issues
# Testing exactly what the failing test is doing

require_relative 'src/reasoning/type_constraint'

puts "🔍 DEBUGGING TYPE CONSTRAINT PROPAGATION"
puts "=" * 50

# Recreate the exact test scenario
constraint_system = TypeConstraintSystem.new

puts "\n1. Creating 100 constraints with relationships..."
100.times do |i|
  var_name = "var#{i}".to_sym
  constraint_system.create_constraint(var_name, :type, :Number)
  puts "  Created constraint for #{var_name}" if i < 3 || i > 96
  
  if i > 0
    from_var = "var#{i-1}".to_sym
    to_var = var_name
    transform = ->(val) { val + 1 }
    constraint_system.add_relationship(from_var, to_var, transform)
    puts "  Added relationship: #{from_var} -> #{to_var} (+1)" if i < 3
  end
end

puts "\n2. Setting initial value..."
constraint_system.set_variable_value(:var0, 1)
puts "  Set var0 = 1"

puts "\n3. Checking propagation results..."
[0, 1, 2, 97, 98, 99].each do |i|
  var_name = "var#{i}".to_sym
  value = constraint_system.get_variable_value(var_name)
  expected = i + 1
  status = value == expected ? "✅" : "❌"
  puts "  #{var_name}: #{value} (expected #{expected}) #{status}"
end

puts "\n4. Final check..."
final_value = constraint_system.get_variable_value(:var99)
puts "var99 = #{final_value} (expected 100)"

if final_value == 100
  puts "✅ PROPAGATION WORKING CORRECTLY"
else
  puts "❌ PROPAGATION FAILED"
  puts "   This explains why the test is failing"
end