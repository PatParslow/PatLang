#!/usr/bin/env ruby

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

# Set up like the test
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Test sequence that might reveal duplication issues
puts "Testing fact insertion step by step:"

puts "\n1. Adding number(0)"
result = facts_db.assert_fact("number(0)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\n2. Adding even(0)"
result = facts_db.assert_fact("even(0)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\n3. Adding number(1)"
result = facts_db.assert_fact("number(1)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\n4. Adding number(2)"
result = facts_db.assert_fact("number(2)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\n5. Adding even(2)"
result = facts_db.assert_fact("even(2)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\n6. Adding prime(2)"
result = facts_db.assert_fact("prime(2)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

puts "\nAll facts:"
facts_db.all_facts.each_with_index { |fact, i| puts "#{i+1}: #{fact}" }

# Test re-adding the same fact
puts "\n7. Re-adding even(0) (should not increase count)"
result = facts_db.assert_fact("even(0)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"

# Test similar but different fact
puts "\n8. Adding even(4)"
result = facts_db.assert_fact("even(4)")
puts "Result: #{result}, Count: #{facts_db.fact_count}"