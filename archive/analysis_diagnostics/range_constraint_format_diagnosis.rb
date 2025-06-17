#!/usr/bin/env ruby

# Range Constraint Format Issue Diagnosis
# Verify the format mismatch between tests and system expectations

require_relative 'src/reasoning/type_constraint_system'

puts "=== RANGE CONSTRAINT FORMAT DIAGNOSIS ==="
puts

# Create a constraint system
system = TypeConstraintSystem.new

puts "1. Testing Range object format (what tests use):"
begin
  system.create_constraint(:age, :range, 0..150)
  puts "   ✅ SUCCESS: Range format accepted"
rescue => e
  puts "   ❌ ERROR: #{e.message}"
  puts "   ❌ ERROR TYPE: #{e.class}"
end

puts

puts "2. Testing Hash format (what system expects):"
begin
  system.create_constraint(:age, :range, {min: 0, max: 150})
  puts "   ✅ SUCCESS: Hash format accepted"
rescue => e
  puts "   ❌ ERROR: #{e.message}"
  puts "   ❌ ERROR TYPE: #{e.class}"
end

puts

puts "3. Analysis of system validation logic:"
puts "   - Line 247-249: validate_constraint_inputs expects Hash with :min, :max"
puts "   - Line 388-391: satisfies_range_constraint? expects constraint_data[:min]/:max"
puts "   - Tests on lines 33, 54, 77: Use Range syntax like 0..150"

puts

puts "4. Conclusion:"
puts "   - Tests expect Range objects to be accepted"
puts "   - System only accepts {min:, max:} hash format"
puts "   - Need to either:"
puts "     a) Update tests to use hash format, OR"
puts "     b) Update system to convert Range objects to hash format"

puts

puts "=== DIAGNOSIS COMPLETE ==="