#!/usr/bin/env ruby

# Range Constraint Format Fix Validation
# Test the specific cases mentioned in Priority 2A to ensure they work correctly

require_relative 'src/reasoning/type_constraint_system'

puts "=== RANGE CONSTRAINT FORMAT FIX VALIDATION ==="
puts

# Create a constraint system
system = TypeConstraintSystem.new

# Test cases from test_type_constraints_clean.rb
test_cases = [
  {
    name: "test_create_range_constraint (line 33)",
    test: -> { system.create_constraint(:age, :range, 0..150) }
  },
  {
    name: "test_multiple_constraints_same_variable (line 54)",
    test: -> { 
      system.create_constraint(:x, :type, :Number)
      system.create_constraint(:x, :range, 0..100)
    }
  },
  {
    name: "test_range_constraint_validates_correct_values (line 77)",
    test: -> { 
      system.create_constraint(:age, :range, 0..150)
      # Test validation
      [
        system.variable_satisfies?(:age, 25),   # should be true
        system.variable_satisfies?(:age, 0),    # should be true  
        system.variable_satisfies?(:age, 150),  # should be true
        !system.variable_satisfies?(:age, -1),  # should be false (negated)
        !system.variable_satisfies?(:age, 151)  # should be false (negated)
      ].all?
    }
  },
  {
    name: "Range vs Hash format compatibility",
    test: -> {
      # Test that both formats work and produce equivalent results
      system1 = TypeConstraintSystem.new
      system2 = TypeConstraintSystem.new
      
      system1.create_constraint(:test1, :range, 1..10)
      system2.create_constraint(:test2, :range, {min: 1, max: 10})
      
      # Both should validate the same values identically
      test_values = [0, 1, 5, 10, 11]
      results1 = test_values.map { |v| system1.variable_satisfies?(:test1, v) }
      results2 = test_values.map { |v| system2.variable_satisfies?(:test2, v) }
      
      results1 == results2
    }
  },
  {
    name: "Exclusive range handling (1...10)",
    test: -> {
      system_exclusive = TypeConstraintSystem.new
      system_exclusive.create_constraint(:test, :range, 1...10)  # exclusive end
      
      # Should accept 1-9, reject 10
      system_exclusive.variable_satisfies?(:test, 9) && 
      !system_exclusive.variable_satisfies?(:test, 10)
    }
  }
]

passed = 0
failed = 0

test_cases.each_with_index do |test_case, index|
  print "#{index + 1}. #{test_case[:name]}... "
  
  begin
    result = test_case[:test].call
    if result
      puts "✅ PASS"
      passed += 1
    else
      puts "❌ FAIL (validation failed)"
      failed += 1
    end
  rescue => e
    puts "❌ FAIL (#{e.class}: #{e.message})"
    failed += 1
  end
end

puts
puts "=== VALIDATION SUMMARY ==="
puts "✅ Passed: #{passed}"
puts "❌ Failed: #{failed}"
puts "📊 Success Rate: #{((passed.to_f / (passed + failed)) * 100).round(1)}%"

if failed == 0
  puts
  puts "🎉 ALL TESTS PASSED! Range constraint format fix is working correctly."
  puts "   - Range objects (1..10) are now accepted and converted internally"
  puts "   - Hash format ({min: 1, max: 10}) continues to work"
  puts "   - Both inclusive (1..10) and exclusive (1...10) ranges are handled"
  puts "   - Validation logic works correctly with converted data"
else
  puts
  puts "⚠️  Some tests failed. Range constraint format fix needs refinement."
end

puts
puts "=== VALIDATION COMPLETE ==="